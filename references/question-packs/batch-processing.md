# Question Pack: Batch Processing

Activate when the protocol:
- loops over recipients, positions, orders, validators, markets, or arbitrary arrays
- supports batched settlement, claims, liquidations, sweeps, or multicall aggregation

Mandatory questions:
1. Can one reverting item roll back the entire batch?
2. Can one blacklisted, paused, frozen, or malformed address poison all other items?
3. Is progress tracked per-item or only after the whole batch succeeds?
4. Can duplicate entries, zero-value items, or out-of-range items distort aggregate accounting?
5. Can attacker-controlled batch size or contents create gas griefing / unexecutable batches?
6. If partial execution exists, can it leave totals, indexes, or aggregate accounting desynced?

Required output fields:
- assumption
- failure_mode
- affected_function
- evidence
- mitigation_or_absence
- user_or_protocol_impact
