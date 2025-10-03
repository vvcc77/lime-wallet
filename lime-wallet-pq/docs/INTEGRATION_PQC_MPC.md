# Lime Wallet 🍋‍🟩 – MPC‑TSS + Post‑Quantum Upgrade ♾

_Last updated: 2025-10-03_

## 1. Objective
Provide **post‑quantum, distributed key management** inside Lemon Mini Apps using:
* **Falcon‑1024** signatures in a 2‑of‑3 **MPC‑TSS** scheme (FROST‑style).
* **Kyber‑768** KEM for session keys.
* **SPHINCS+** as stateless long‑term backup signature.
* **USB Quantum RNG** for verifiable entropy at each node.

This eliminates single‑point key compromise and future‑proofs against quantum adversaries.

## 2. Repository Layout

```
lime-wallet/
├── src/                 # Solidity contracts (Paymaster etc.)
├── crypto-core/         # Rust → WASM PQ cryptography
│   ├── Cargo.toml
│   └── src/lib.rs
├── node-wrapper/        # TypeScript glue ‑ partial signatures, gRPC transport
│   ├── package.json
│   └── src/
│       ├── index.ts
│       └── qrng.ts
├── docs/
│   └── INTEGRATION_PQC_MPC.md  (this file)
└── scripts/
    └── deploy.sh
```

## 3. Prerequisites

| Tool | Version |
|------|---------|
| Rust | ≥ 1.75 |
| wasm‑pack | latest |
| Node | ≥ 20.11 |
| Foundry | ≥ 0.2.0 |
| USB‑QRNG | ID Quantique Quantis (4 Mbps) or similar |

## 4. Setup Steps

```bash
# 1. clone & install
git clone https://github.com/vvcc77/lime-wallet
cd lime-wallet
cargo build -p crypto-core
wasm-pack build crypto-core --target web
cd node-wrapper && pnpm i && pnpm build

# 2. generate MPC key shares
pnpm ts-node src/index.ts --keygen   # produces shareA.json, etc.

# 3. deploy Paymaster
scripts/deploy.sh
```

## 5. Key Generation & Signing Flow

1. **KeyGen**  
   Each node pulls 48 bytes from its local QRNG and runs `frost_falcon_keygen()`.  
2. **Partial Sign**  
   On each tx, two nodes run `frost_falcon_sign()` producing partial sigs.  
3. **Aggregate**  
   The Guard server aggregates partials → final Falcon signature.  
4. **On‑chain Audit**  
   `LimePaymaster` emits `PQSignature` event (Falcon + SPHINCS+) for off‑chain archival.

## 6. Front‑End Integration

```js
import initCrypto, { falconSign } from "@lime/crypto-core/pkg";

export async function signAndSend(userOp) {
  await initCrypto();
  const sigPart = await falconSign(userOp);
  await broadcast(sigPart); // gRPC to other nodes
}
```

## 7. Smart‑Contract Changes

```solidity
event PQSignature(bytes falconSig, bytes sphincsSig);
```

See `src/LimePaymaster.sol` for full implementation.

## 8. Security Checklist

* OWASP SC‑Top‑10 aligned (reentrancy‑safe, CEI pattern)
* Entropy health‑check (`H_min > 0.997`) logged every 10 min.
* Chainlink ETH/USD oracle sanity drift ±5 %.

## 9. Roadmap

| Sprint | Deliverable |
|--------|-------------|
| +2 w   | PoC on Testnet with Falcon partial sigs |
| +4 w   | Audit & fuzzing (Foundry) |
| +6 w   | Launch on Lemon staging |
| Q2‑26  | Production + marketing “Quantum‑Ready Dollars” |

---

© 2025 Lime Wallet contributors @vvcc77 ft @PhoenixZeroph Auditor – MIT

