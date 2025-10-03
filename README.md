# Lime Wallet convierte el dolor de las comisiones en un diferencial invisible—tu usuario paga, sonríe y ni siquiera sabe que existía un segundo token. Eso vale oro (o, mejor dicho, USDC).
# Lime Wallet – Gas‑Abstracted Paymaster 🍋‍🟩

A minimal **ERC‑4337 Token Paymaster** that lets Lemon Mini‑App users pay **gas with USDC** (no ETH/MATIC/XLM friction).

## Quick start

```bash
# Requirements
forge --version            # Foundry
git clone https://github.com/vvcc77/lime-wallet.git
cd lime-wallet
forge install openzeppelin/account-abstraction
forge build
```

### Deploy

```bash
source .env                # set ENTRYPOINT, USDC, ORACLE, RPCURL, PK
forge create --rpc-url $RPCURL --private-key $PK \
  src/LimePaymaster.sol:LimePaymaster \
  --constructor-args $ENTRYPOINT $USDC $ORACLE
cast send PAYMASTER_ADDRESS --value 0.1ether   # preload gas
```

## How it works

* **_validatePaymasterUserOp** converts `maxCost (wei)` → **USDC** using a price oracle, pre‑charges the user via `transferFrom`, then sponsors the gas.
* Integrate in front‑end: set `userOp.paymasterAndData` to the paymaster address. Ask for `permit()` instead of `approve()`.
* Stellar side: wrap USDC transfers with **Fee‑Bump** tx so the Mini‑App never prompts the user for XLM.

## Security checklist

* Follows **Checks‑Effects‑Interactions** pattern.
* No `tx.origin`, no unbounded loops, no external callbacks in critical section.
* Complies with **OWASP Smart Contract Top 10** guidelines.

---

© 2025 Lime Wallet contributors @vvcc77 ft @PhoenixZeroph Auditor – MIT License
