#![cfg(test)]

use super::*;
use soroban_sdk::{
    testutils::Address as _,
    token::{StellarAssetClient, TokenClient},
    Address, Env, Symbol,
};

fn setup_with_payment_token(env: &Env) -> (Address, Address, Address, RwaLaunchpadClient<'_>) {
    let contract_id = env.register(RwaLaunchpad, ());
    let client = RwaLaunchpadClient::new(env, &contract_id);

    let admin = Address::generate(env);
    let sac = env.register_stellar_asset_contract_v2(admin.clone());
    let payment_token = sac.address();

    let asset = AssetInfo {
        name: Symbol::new(env, "RWAToken"),
        total_supply: 1_000_000,
        price_per_unit: 100,
        payment_token: payment_token.clone(),
        paused: false,
    };

    env.mock_all_auths();
    client.initialize(&admin, &asset);

    (admin, payment_token, contract_id, client)
}

#[test]
fn test_invest() {
    let env = Env::default();
    let (admin, payment_token, _contract_id, client) = setup_with_payment_token(&env);
    let investor = Address::generate(&env);

    let token_admin = StellarAssetClient::new(&env, &payment_token);
    let token = TokenClient::new(&env, &payment_token);
    token_admin.mint(&investor, &1_000);

    env.mock_all_auths();
    client.set_whitelist(&admin, &investor, &true);

    let minted = client.invest(&investor, &500);
    assert_eq!(minted, 5);
    assert_eq!(client.balance(&investor), 5);
    assert_eq!(token.balance(&investor), 500);
}

#[test]
fn test_withdraw() {
    let env = Env::default();
    let (admin, payment_token, _contract_id, client) = setup_with_payment_token(&env);
    let investor = Address::generate(&env);
    let treasury = Address::generate(&env);

    let token_admin = StellarAssetClient::new(&env, &payment_token);
    let token = TokenClient::new(&env, &payment_token);
    token_admin.mint(&investor, &1_000);

    env.mock_all_auths();
    client.set_whitelist(&admin, &investor, &true);
    client.invest(&investor, &500);

    client.withdraw(&admin, &treasury, &500);

    assert_eq!(token.balance(&treasury), 500);
}

/// Variación: toda inversión debe ser de al menos 500 unidades del token de pago.
/// 100 queda por debajo del mínimo, así que `invest` aborta con `AmountTooLow` (#7).
#[test]
#[should_panic(expected = "Error(Contract, #7)")]
fn test_invest_below_minimum_fails() {
    let env = Env::default();
    let (admin, payment_token, _contract_id, client) = setup_with_payment_token(&env);
    let investor = Address::generate(&env);

    let token_admin = StellarAssetClient::new(&env, &payment_token);
    token_admin.mint(&investor, &1_000);

    env.mock_all_auths();
    client.set_whitelist(&admin, &investor, &true);

    client.invest(&investor, &100);
}

/// 500 es exactamente el mínimo, así que la inversión pasa el gate:
/// a 100 por unidad, 500 del token de pago compran 5 unidades del RWA.
#[test]
fn test_invest_at_minimum_succeeds() {
    let env = Env::default();
    let (admin, payment_token, _contract_id, client) = setup_with_payment_token(&env);
    let investor = Address::generate(&env);

    let token_admin = StellarAssetClient::new(&env, &payment_token);
    let token = TokenClient::new(&env, &payment_token);
    token_admin.mint(&investor, &1_000);

    env.mock_all_auths();
    client.set_whitelist(&admin, &investor, &true);

    let minted = client.invest(&investor, &500);

    assert_eq!(minted, 5);
    assert_eq!(client.balance(&investor), 5);
    assert_eq!(token.balance(&investor), 500);
}

#[test]
#[should_panic(expected = "Error(Contract, #5)")]
fn test_invest_not_whitelisted() {
    let env = Env::default();
    let (_admin, payment_token, _contract_id, client) = setup_with_payment_token(&env);
    let investor = Address::generate(&env);

    let token_admin = StellarAssetClient::new(&env, &payment_token);
    token_admin.mint(&investor, &1_000);

    env.mock_all_auths();
    client.invest(&investor, &500);
}

#[test]
fn test_authenticated_outsider_cannot_administer() {
    let env = Env::default();
    let (_admin, payment_token, contract, client) = setup_with_payment_token(&env);
    let outsider = Address::generate(&env);
    let investor = Address::generate(&env);
    // Even with all signatures accepted, the outsider must not have the stored role.
    assert!(client.try_mint(&outsider, &investor, &5).is_err());
    assert!(client.try_set_whitelist(&outsider, &investor, &true).is_err());
    assert!(client.try_pause(&outsider).is_err());
    assert!(client.try_unpause(&outsider).is_err());
    assert!(client.try_withdraw(&outsider, &investor, &1).is_err());
    assert_eq!(client.balance(&investor), 0);
    assert_eq!(TokenClient::new(&env, &payment_token).balance(&contract), 0);
    env.as_contract(&contract, || {
        let info: AssetInfo = env.storage().instance().get(&DataKey::AssetInfo).unwrap();
        assert!(!info.paused);
        let approved: bool = env.storage().persistent().get(&DataKey::Whitelisted(investor)).unwrap_or(false);
        assert!(!approved);
    });
}

#[test]
fn test_stored_admin_still_requires_authentication() {
    let env = Env::default();
    let (admin, _token, contract, client) = setup_with_payment_token(&env);
    env.mock_auths(&[]);
    assert!(client.try_pause(&admin).is_err());
    env.as_contract(&contract, || {
        let info: AssetInfo = env.storage().instance().get(&DataKey::AssetInfo).unwrap();
        assert!(!info.paused);
    });
}

#[test]
fn test_non_divisible_payment_has_no_effect() {
    let env = Env::default();
    let (admin, payment, contract, client) = setup_with_payment_token(&env);
    let investor = Address::generate(&env);
    StellarAssetClient::new(&env, &payment).mint(&investor, &1000);
    client.set_whitelist(&admin, &investor, &true);
    assert!(client.try_invest(&investor, &550).is_err());
    assert_eq!(client.balance(&investor), 0);
    let token = TokenClient::new(&env, &payment);
    assert_eq!(token.balance(&investor), 1000);
    assert_eq!(token.balance(&contract), 0);
}
