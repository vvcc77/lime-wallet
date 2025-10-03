# Seguridad — Lime Wallet

## Amenazas y mitigaciones
- Oráculo obsoleto → `MAX_PRICE_AGE`.
- Abuso por tx/usuario → `MAX_USD_PER_TX`, `MAX_USD_PER_USER_WINDOW`.
- Reentrancy → `ReentrancyGuard`, `SafeERC20`.
- Permit replay → validación `nonce` y `deadline`.
- Locks largos → `<= 50 años` y duraciones whitelisted.
- Privilegios → `onlyOwner` solo en pausa/duración/params.

## Prácticas
- Patrón CEI en transferencias.
- Sin `tx.origin`.
- Sin loops descontrolados.
- Pausable como kill-switch.
