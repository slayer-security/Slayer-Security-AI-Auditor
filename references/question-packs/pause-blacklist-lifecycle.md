# Question Pack: Pause / Blacklist / Lifecycle Restrictions

Activate when the protocol or integrated assets expose:
- `pause`, `unpause`, `whenNotPaused`, `blacklist`, `denylist`, `freeze`, `shutdown`, `rescue`, `emergencyWithdraw`

Mandatory questions:
1. Which user flows depend on transfer success from a pausible or blacklistable asset?
2. Can one blacklisted user block a shared loop, settlement queue, or reward distribution?
3. Do pause/unpause transitions leave stale accounting, stale queue state, or stranded value?
4. Does failure happen before accounting updates, after accounting updates, or mid-transition?
5. Is there an escape hatch for innocent users if one actor or one asset becomes restricted?
6. Can emergency-mode paths bypass normal accounting cleanup or cap enforcement?

Required output fields:
- assumption
- failure_mode
- affected_assets_or_roles
- evidence
- cleanup_or_escape_path
- impact_scope
