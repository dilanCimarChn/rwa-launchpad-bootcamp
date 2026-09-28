#!/usr/bin/env bash
# Demo de la variación, pensada para capturas de pantalla.
# Corre el intento fallido (100) y el exitoso (500) uno tras otro,
# con separadores claros y el link de stellar.expert al final.
#
# Uso:  ./demo.sh

set -uo pipefail

cd "$(dirname "$0")/.."

NETWORK="${NETWORK:-testnet}"
USER_KEY="${USER_KEY:-bob}"
CONTRACT_ID="${CONTRACT_ID:-CDGTOIZ2R2PC364N3DCQL7PPO3LIKPOX63XD6DOUKN2KI6NZANNL4BE5}"
USER_ADDRESS="$(stellar keys address "$USER_KEY")"

rule() { printf '\n%s\n' "------------------------------------------------------------"; }

echo "VARIACION: toda inversion debe ser de al menos 500 unidades del token de pago."
echo "Contrato:     $CONTRACT_ID"
echo "Inversionista: $USER_ADDRESS"

rule
echo ">> 1. Intento de invertir 100: debe FALLAR con AmountTooLow (#7)"
rule
if ./scripts/user-tool.sh invest 100 2>&1 | grep -E "invest 100|error:|failing with contract error"; then
  echo
  echo "   ^ Error(Contract, #7) = AmountTooLow. Rechazado, no se minteo nada."
fi

rule
echo ">> 2. Inversion de 500: debe FUNCIONAR"
rule
INVEST_OUT="$(./scripts/user-tool.sh invest 500 2>&1)"
echo "$INVEST_OUT" | grep -E "invest 500|Transaction submitted|stellar.expert|Event: \[\{\"symbol\":\"invest"
MINTED="$(echo "$INVEST_OUT" | tail -1)"
echo
echo "   Unidades de RWA minteadas: $MINTED"

rule
echo ">> 3. Balance del inversionista"
rule
echo "   RWA:   $(./scripts/user-tool.sh balance 2>&1 | tail -1)"
echo "   RWAPAY: $(./scripts/user-tool.sh pay-balance 2>&1 | tail -1)"

rule
echo "COMPROBANTE de la inversion exitosa:"
echo "$INVEST_OUT" | grep -o "https://stellar.expert/explorer/testnet/tx/[a-f0-9]*" | head -1
rule
