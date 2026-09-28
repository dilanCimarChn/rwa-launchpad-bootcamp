#!/usr/bin/env bash
# User tool: invocaciones firmadas por el inversionista / holder del token.
#
# Uso:  ./user-tool.sh <comando>
# Comandos:
#   invest <monto>   invertir <monto> unidades del token de pago
#                    (la variacion exige un minimo de 500; menos falla con AmountTooLow)
#   balance          consultar el balance de RWA del inversionista
#   pay-balance      consultar el balance del token de pago del inversionista
#   transfer <monto> transferir RWA a RECIPIENT

set -euo pipefail

NETWORK="${NETWORK:-testnet}"
USER_KEY="${USER_KEY:-bob}"
CONTRACT_ID="${CONTRACT_ID:-CDGTOIZ2R2PC364N3DCQL7PPO3LIKPOX63XD6DOUKN2KI6NZANNL4BE5}"
PAYMENT_TOKEN="${PAYMENT_TOKEN:-CA7B5D7KVCABJPKQMAE6NYXMCBGFCVZTPYTXVEUVF6JKRQKVVLEGUOCH}"
RECIPIENT="${RECIPIENT:-GBL36SWZDJOTB76FGEA3EPTSEJXKJEY4CN3SBD5DTT5GQJBOXQ7FWECB}"

USER_ADDRESS="$(stellar keys address "$USER_KEY")"

invoke() {
  stellar contract invoke \
    --id "$CONTRACT_ID" \
    --source "$USER_KEY" \
    --network "$NETWORK" \
    -- "$@"
}

case "${1:-}" in
  invest)
    AMOUNT="${2:?falta el monto: ./user-tool.sh invest <monto>}"
    echo "=== invest $AMOUNT ==="
    invoke invest \
      --investor "$USER_ADDRESS" \
      --payment_amount "$AMOUNT"
    ;;
  balance)
    echo "=== balance de RWA ==="
    invoke balance --id "$USER_ADDRESS"
    ;;
  pay-balance)
    echo "=== balance del token de pago ==="
    stellar contract invoke \
      --id "$PAYMENT_TOKEN" \
      --source "$USER_KEY" \
      --network "$NETWORK" \
      -- balance --id "$USER_ADDRESS"
    ;;
  transfer)
    echo "=== transfer de RWA a $RECIPIENT ==="
    invoke transfer \
      --from "$USER_ADDRESS" \
      --to "$RECIPIENT" \
      --amount "${2:-10}"
    ;;
  *)
    echo "Uso: $0 {invest <monto>|balance|pay-balance|transfer [monto]}" >&2
    exit 1
    ;;
esac
