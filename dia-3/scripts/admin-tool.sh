#!/usr/bin/env bash
# Admin tool: invocaciones que requieren la firma del admin/issuer.
#
# Uso:  ./admin-tool.sh <comando>
# Comandos: initialize | whitelist | unwhitelist | mint | withdraw | pause | unpause
#
# Los valores se pueden sobreescribir por variable de entorno, por ejemplo:
#   INVESTOR=G... ./admin-tool.sh whitelist

set -euo pipefail

NETWORK="${NETWORK:-testnet}"
ADMIN_KEY="${ADMIN_KEY:-alice}"
CONTRACT_ID="${CONTRACT_ID:-CDGTOIZ2R2PC364N3DCQL7PPO3LIKPOX63XD6DOUKN2KI6NZANNL4BE5}"
PAYMENT_TOKEN="${PAYMENT_TOKEN:-CA7B5D7KVCABJPKQMAE6NYXMCBGFCVZTPYTXVEUVF6JKRQKVVLEGUOCH}"
INVESTOR="${INVESTOR:-GB3VUWEE5PRHW3WCPBG7XY6A2L5JRC4N4HYEQCNANICRAVJP57DIBUNY}"
TREASURY="${TREASURY:-GBL36SWZDJOTB76FGEA3EPTSEJXKJEY4CN3SBD5DTT5GQJBOXQ7FWECB}"

ADMIN_ADDRESS="$(stellar keys address "$ADMIN_KEY")"

invoke() {
  stellar contract invoke \
    --id "$CONTRACT_ID" \
    --source "$ADMIN_KEY" \
    --network "$NETWORK" \
    -- "$@"
}

case "${1:-}" in
  initialize)
    echo "=== initialize (una sola vez despues del deploy) ==="
    invoke initialize \
      --admin "$ADMIN_ADDRESS" \
      --asset '{"name":"RWAToken","total_supply":"1000000","price_per_unit":"100","payment_token":"'"$PAYMENT_TOKEN"'","paused":false}'
    ;;
  whitelist)
    echo "=== set_whitelist: aprobar $INVESTOR ==="
    invoke set_whitelist \
      --admin "$ADMIN_ADDRESS" \
      --investor "$INVESTOR" \
      --approved true
    ;;
  unwhitelist)
    echo "=== set_whitelist: revocar $INVESTOR ==="
    invoke set_whitelist \
      --admin "$ADMIN_ADDRESS" \
      --investor "$INVESTOR" \
      --approved false
    ;;
  mint)
    echo "=== mint (solo admin; opcional si se usa invest) ==="
    invoke mint \
      --admin "$ADMIN_ADDRESS" \
      --to "$INVESTOR" \
      --amount "${2:-100}"
    ;;
  withdraw)
    echo "=== withdraw: mover tokens de pago recaudados a la tesoreria ==="
    invoke withdraw \
      --admin "$ADMIN_ADDRESS" \
      --to "$TREASURY" \
      --amount "${2:-500}"
    ;;
  pause)
    echo "=== pause ==="
    invoke pause --admin "$ADMIN_ADDRESS"
    ;;
  unpause)
    echo "=== unpause ==="
    invoke unpause --admin "$ADMIN_ADDRESS"
    ;;
  *)
    echo "Uso: $0 {initialize|whitelist|unwhitelist|mint [monto]|withdraw [monto]|pause|unpause}" >&2
    exit 1
    ;;
esac
