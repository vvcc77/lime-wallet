# SECOPS — Respuesta a Incidentes by @PhoenixZeroph Auditor

## Detección
- Monitoreo de:
  - Oráculos (desfasaje > MAX_PRICE_AGE)
  - Aumentos anómalos en penalizaciones o retiros anticipados
  - Errores de creación de posición por debajo del mínimo

## Mitigación
- Pausar contrato (`pause()`) si:
  - El oráculo falla o está comprometido
  - Se detectan transferencias no autorizadas o abuso de early withdraw
- Ajustar listas de `allowedDurations` y `allowToken/removeToken`

## Comunicación
- Interna: canal on-call (alertas automáticas)
- Externa: banner en README + release notes con hash de commit

## Forensics
- Auditar eventos:
  - `PositionCreated`, `PositionClaimed`, `TokenAllowed/Removed`, `DurationAllowed/Removed`
- Revisar balances de tesorería y snapshot de posiciones

## Remediación
- Hotfix + tests reproducibles (unit + fuzz)
- Redeploy sólo si el bug impacta inmutables o storage crítico
- Post-mortem público con timeline y medidas preventivas
