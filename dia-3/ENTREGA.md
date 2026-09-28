# Notas de la entrega (dia-3)

Red: Stellar testnet.

## Variacion

Toda inversion debe ser de al menos 500 unidades del token de pago. Por debajo de ese
minimo, `invest()` corta con el error `AmountTooLow` (`#7`).

La regla esta en `check_variation_gate`, en `src/lib.rs`:

```rust
const MIN_INVESTMENT: i128 = 500;

fn check_variation_gate(
    env: &Env,
    investor: &Address,
    payment_amount: i128,
) -> Result<(), Error> {
    let _ = (env, investor);
    if payment_amount < MIN_INVESTMENT {
        return Err(Error::AmountTooLow);
    }
    Ok(())
}
```

La firma que venia en el starter era `check_variation_gate(env, investor)`. Sin el monto
el gate no puede saber cuanto se esta invirtiendo, asi que le agregue el parametro
`payment_amount` y actualice la llamada dentro de `invest()`.

## Direcciones

| Que | Valor |
|---|---|
| Contract ID del launchpad | `CDGTOIZ2R2PC364N3DCQL7PPO3LIKPOX63XD6DOUKN2KI6NZANNL4BE5` |
| Token de pago (SAC de `RWAPAY`) | `CA7B5D7KVCABJPKQMAE6NYXMCBGFCVZTPYTXVEUVF6JKRQKVVLEGUOCH` |
| Admin / issuer (`alice`) | `GCJ7N5FTVAPRKG6H6MYWAG2IJ6ZM5YGJ5CHI2J2J7PMJSB4NSLYDPRP5` |
| Inversionista (`bob`) | `GB3VUWEE5PRHW3WCPBG7XY6A2L5JRC4N4HYEQCNANICRAVJP57DIBUNY` |
| Tesoreria | `GBL36SWZDJOTB76FGEA3EPTSEJXKJEY4CN3SBD5DTT5GQJBOXQ7FWECB` |

El token de pago es un Stellar Asset Contract propio (`RWAPAY:alice`) que despliegue para
esta entrega, en lugar del token del instructor. `price_per_unit` es 100, asi que 500
unidades del token de pago compran 5 unidades del RWA.

## Inversion exitosa

https://stellar.expert/explorer/testnet/tx/c5cdf146a54d280a4059a1f9cc1c68ef400bcb4a5e221eed8a0919a2b4318989

Ledger 4921831, `successful: true`. Eventos: un `transfer` de 500 RWAPAY del inversionista
al contrato, y un `invest` con `(investor, 500, 5)`. La invocacion devuelve `5`.

## Por que el intento fallido no tiene link

Soroban rechaza `invest 100` durante la simulacion, antes de firmar y enviar, asi que la
transaccion nunca llega al ledger. Lo probe tambien con `--send=yes` y el resultado es el
mismo. La evidencia del rechazo es el output de terminal (en las capturas) y el test
`test_invest_below_minimum_fails`.

## Flujo ejecutado en testnet

Admin:

1. `./scripts/admin-tool.sh initialize`
   tx `eb809d585349597ec4583449bb428e42bf40e0ab9ce6b7484a7dbb2fbcf3d81f`
2. `./scripts/admin-tool.sh whitelist`
   tx `03c000f85fa411651b83480af19c432c367c4b24d1e58aead2c14654dad80840`

Inversionista:

3. `./scripts/user-tool.sh invest 100` corta con `Error(Contract, #7)`, no se mintea nada
4. `./scripts/user-tool.sh invest 500` devuelve `5`
   tx `c5cdf146a54d280a4059a1f9cc1c68ef400bcb4a5e221eed8a0919a2b4318989`
5. `./scripts/user-tool.sh balance` devuelve `5`, y el balance del token de pago baja de
   10000 a 9500

Admin, retiro de lo recaudado:

6. `./scripts/admin-tool.sh withdraw 500`
   tx `4d59d142e89df6e3de801d9b6699f6877c7333deb3d258a4d643d8cd667dd9c8`

## Tests

`cargo test` corre 5 tests y pasan todos. Los dos de la variacion estan en `src/test.rs`:

- `test_invest_below_minimum_fails`: invierte 100 y espera `Error(Contract, #7)`
- `test_invest_at_minimum_succeeds`: invierte 500, verifica que se mintean 5 unidades de
  RWA y que el balance del token de pago baja a 500

El segundo cubre el borde exacto del minimo. Si la comparacion fuera `<=` en lugar de `<`,
o si el minimo quedara por encima de 500, ese test falla.

## Cambios a los scripts del repo

Dos ajustes sobre `scripts/admin-tool.sh` y `scripts/user-tool.sh`:

1. Selector de subcomando. Los scripts originales eran un bloque unico con
   `set -euo pipefail`, asi que corrian todas las invocaciones de corrido. Eso no
   funciona: `withdraw` se ejecutaba antes de cualquier `invest`, fallaba por falta de
   fondos en el contrato y abortaba el resto. Ahora cada paso se invoca por separado, que
   ademas es lo que hace falta para mostrar el intento fallido y el exitoso aparte.
2. `AssetInfo` en `initialize`. El JSON del starter pasaba `total_supply` y
   `price_per_unit` como numeros. Con Stellar CLI 28 los campos `i128` van como strings, si
   no el parseo falla con `invalid type: number, expected string or map`.

## Reproducir

```bash
cd dia-3
cargo test
stellar contract build
./scripts/admin-tool.sh initialize
./scripts/admin-tool.sh whitelist
./scripts/user-tool.sh invest 100
./scripts/user-tool.sh invest 500
./scripts/user-tool.sh balance
```

Con el contrato ya inicializado, `./scripts/demo.sh` corre el intento fallido y el exitoso
de corrido e imprime el link de stellar.expert. Cada corrida genera una transaccion nueva.

Entorno: Rust 1.98.1 con target `wasm32v1-none`, Stellar CLI 28.0.0, `soroban-sdk` 26.
