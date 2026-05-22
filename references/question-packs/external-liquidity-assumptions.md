# Question Pack: External Liquidity Assumptions

Activate when the protocol relies on:
- spot reserves, AMM quotes, redemption liquidity, bridge liquidity, lending pool liquidity, or thin secondary markets

Mandatory questions:
1. What external liquidity assumption is being made (depth, freshness, redeemability, quote quality)?
2. Does the protocol read spot state that can be manipulated in thin liquidity?
3. What happens if liquidity disappears or becomes too expensive between preview and execution?
4. Can slippage, queueing, reserve skew, or bridge illiquidity violate solvency or pricing assumptions?
5. Is there a fallback, guardrail, or circuit breaker when the assumed liquidity is absent?
6. Does the protocol treat quoted value as realizable value without verifying actual exit conditions?

Required output fields:
- assumption
- failure_mode
- external_dependency
- evidence
- realistic_liquidity_break_scenario
- impact_on_users_or_protocol
