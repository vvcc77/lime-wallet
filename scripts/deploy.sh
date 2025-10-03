#!/usr/bin/env bash
set -euo pipefail
source .env
forge create --rpc-url "$RPCURL" --private-key "$PK" \
  src/LimePaymaster.sol:LimePaymaster \
  --constructor-args "$ENTRYPOINT" "$USDC" "$ORACLE"

