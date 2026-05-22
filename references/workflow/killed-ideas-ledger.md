# Killed Ideas Ledger

Purpose: stop the audit from revisiting attractive but invalid ideas.

For every rejected or narrowed hypothesis, record:
- `hypothesis_id`
- `raw_hypothesis`
- `why_plausible`
- `kill_reason`
- `kill_evidence`
- `narrower_variant_remaining` (`none` if dead)
- `reentry_condition`
- `status`: `killed` / `narrowed` / `needs-more-proof`
- `killed_by_stage`: `4` / `5` / `7`

Kill reasons should be concrete, for example:
- blocked by trust model
- blocked by hidden invariant
- unreachable path
- mitigated by real code
- grief-only with no meaningful impact
- depends on external behavior not proven in-scope
- duplicate framing of an already killed root cause

Rules:
- Log the hypothesis as soon as it is rejected or narrowed.
- A killed root cause must not re-enter later stages under cosmetic rewording.
- Re-entry is allowed only if new evidence satisfies the recorded `reentry_condition`.
- Final validator must review the ledger to ensure rejected ideas are not reintroduced with superficial rewording.
- Narrowed variants should keep the original hypothesis id lineage when possible.
