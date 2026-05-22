# Protocol Truth Sheet

Purpose: calibrate the threat model from repository evidence before bug hunting escalates.

Required sections:
- Trusted actors
- Semi-trusted actors
- Untrusted actors
- Offchain dependencies
- Lifecycle states
- Shared liquidity domains
- Retry / asynchronous semantics
- Explicit invariants
- Implicit invariants
- Impossible states / forbidden assumptions
- Documented limitations
- Documented known issues or explicit non-goals

For each entry record:
- `statement`
- `source`
- `certainty`: `high` / `medium` / `low` / `uncertain`

Rules:
- Prefer repository docs, README, architecture notes, tests, NatSpec, and comments as sources.
- If trust assumptions are ambiguous, mark them `uncertain` and lower confidence until exploitability is proven without that ambiguity.
- Do not silently assume owner/admin/keeper trust. Record it.
- Historical or social context outside the repo is out of scope unless the repository itself documents it.
- If docs and code appear inconsistent, preserve the disagreement as an audit lead.
