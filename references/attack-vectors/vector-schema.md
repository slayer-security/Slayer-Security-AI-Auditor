# Attack Vector Schema

Canonical schema for non-core vector layers:
- `custom-attack-vectors.md`
- `live-hack-db/live-hack-vectors.md`
- `niche-specific/specialized-vectors.md`

The legacy `attack-vectors.md` file may continue using the older `D/FP` format.

---

## Canonical Fields

```markdown
### ID: Title

**Trigger**: `ALWAYS` or `FLAG_A | FLAG_B`
**Summary**: One-line vulnerability statement
**Mechanic**: How the bug actually happens
**Detection Clues**:
- code signal 1
- code signal 2
**False Positive Checks**:
- mitigation 1
- mitigation 2
**Examples / References**:
- historical incident or writeup
```

---

## Trigger Grammar

Supported expressions:
- `ALWAYS`
- `FLAG_A`
- `FLAG_A | FLAG_B`
- `FLAG_A & FLAG_B`

Supported flags:
- `ORACLE`
- `FLASH_LOAN`
- `CROSS_CHAIN_MSG`
- `STORAGE_LAYOUT`
- `TOKEN_FLOW`
- `MIGRATION`
- `PRIVILEGED_ROLE`
- `SHARE_ACCOUNTING`
- `SIGNATURE_AUTH`

No other operators should be used.

---

## Dedupe Policy

When multiple vectors describe the same mechanic at the same code location:
- keep one primary finding
- preserve merged references from duplicates
- choose the primary vector using this precedence:
  1. `custom`
  2. `niche-specific`
  3. `live-hack-db`
  4. `core`
