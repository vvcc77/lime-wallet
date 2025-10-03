# Integración Front — Lime Wallet

## Ahorro disciplinado
1. `approve(vault, amount)` o `permit()`.
2. `callSmartContract("createPosition(uint256,uint256)", [amount, 30*24*60*60])`.

## Claim
- `callSmartContract("claim(uint256)", [id])` al madurar.

## Gas abstraction
1. Estimar gas → `maxCostWei`.
2. Backend `quote(maxCostWei)` devuelve `{ usdcAmount, priceAge }`.
3. Usuario firma `permit()` (spender = Paymaster).
4. Construir `userOp`:
   - `callData`: operación del usuario.
   - `paymasterAndData = abi.encode(paymaster, usdcAmount, priceAge, deadline, permitSig)`.
5. Enviar `userOp` al bundler/EntryPoint.
