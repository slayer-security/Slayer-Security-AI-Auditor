# Slayer Security Auditor - Auto Memory

Last Updated: [Will be updated after first audit]
Total Audits Completed: 0

---

## Purpose

This file stores learnings from each audit to improve future audits:
- Validated bug patterns that recur
- False positive patterns to suppress
- Protocol-specific quirks discovered
- Integration assumptions that commonly break

**This file grows smarter with each audit.**

---

## Patterns Learned

### Example Template (Remove after first audit):
```
### Pattern: dai-permit-mismatch
- **First Seen**: 2026-03-15 (ExampleProtocol audit)
- **Trigger**: Standard permit() call + claim "supports all ERC20"
- **Context**: Lending/vault protocols
- **Validated**: 1 time
- **False Positives**: 0
- **Solodit Reference**: https://solodit.xyz/issues/...
```

*No patterns learned yet. Patterns will be added after first audit.*

---

## Protocol-Specific Quirks

### Example Template (Remove after first audit):
```
### Uniswap V3
- `slot0` is manipulable within single block (use TWAP)
- Liquidity can be added/removed in same block (JIT attacks)
- Tick manipulation possible with concentrated liquidity

### USDC (Circle)
- Can be paused by Circle admin
- Can blacklist specific addresses
- Uses permit2, not standard EIP-2612
```

*No protocol quirks learned yet. Will be populated after audits.*

---

## Known False Positives

### Example Template (Remove after first audit):
```
### FP-001: Reentrancy in test mocks
- **Pattern**: Raw transfer() or call() in test files
- **Context**: Files in test/, mocks/, *.t.sol
- **Resolution**: Exclude test files from reentrancy checks
- **First Seen**: 2026-03-15
- **Occurrences**: 5 times suppressed

### FP-002: Intentional admin-only unsafe operations
- **Pattern**: Unsafe operation without access control check
- **Context**: Function has onlyOwner/onlyRole modifier
- **Resolution**: Access control IS present (modifier), not a vulnerability
- **Occurrences**: 3 times suppressed
```

*No false positives catalogued yet. Will be populated as encountered.*

---

## Validated Findings

### Example Template (Remove after first audit):
```
### VF-001: USDT SafeERC20 missing
- **Protocol**: LendingProtocol v1
- **Date**: 2026-03-15
- **Severity**: High
- **Issue**: Missing SafeERC20 wrapper for USDT transfers
- **Outcome**: Confirmed by protocol team, fixed in v1.1
- **Pattern**: raw_erc20_transfer
```

*No validated findings yet. First audit will populate this.*

---

## Audit Statistics

### By Integration Type
| Integration | Audits | Findings | False Positives | Precision |
|-------------|--------|----------|-----------------|-----------|
| ERC20       | 0      | 0        | 0               | N/A       |
| Chainlink   | 0      | 0        | 0               | N/A       |
| Uniswap     | 0      | 0        | 0               | N/A       |
| Aave        | 0      | 0        | 0               | N/A       |

*Will be updated after each audit.*

### By Severity
| Severity | Total | Validated | False Positives | Precision Rate |
|----------|-------|-----------|-----------------|----------------|
| Critical | 0     | 0         | 0               | N/A            |
| High     | 0     | 0         | 0               | N/A            |
| Medium   | 0     | 0         | 0               | N/A            |
| Low      | 0     | 0         | 0               | N/A            |

*Will be updated after each audit.*

### Solodit Query Performance
| Query Type           | Total Queries | Avg Results | Avg Relevant | Hit Rate |
|----------------------|---------------|-------------|--------------|----------|
| ERC20 integration    | 0             | 0           | 0            | N/A      |
| Oracle staleness     | 0             | 0           | 0            | N/A      |
| Flash loan attacks   | 0             | 0           | 0            | N/A      |

*Will be populated after audits with Solodit MCP.*

---

## Learning Trends

### Pattern Confidence Over Time
```
Audit 1: X findings, Y% precision
Audit 2: X findings, Y% precision (trend: improving/declining)
...
```

*Will show how precision improves with learning.*

### Common Mistake Categories
*Will identify which types of bugs the skill initially missed or over-reported.*

---

## Usage Notes

**For Future Audits**:
1. Before flagging a finding, check "Known False Positives" section
2. Check "Patterns Learned" to boost confidence for recurring patterns
3. Check "Protocol-Specific Quirks" for known integration issues

**READ this file at**:
- STAGE 6 (validation) - To check known FPs
- STAGE 7 (adversarial validation) - To reference validated patterns

---

## CRITICAL: User Confirmation Required

**⚠️ NEVER auto-update this memory file.**

**This file should ONLY be updated when the user explicitly confirms findings.**

### Update Workflow:

```
1. Skill generates audit report with findings
2. User reviews findings
3. User provides feedback:
   - "Finding X is valid" → Add to Validated Findings + Patterns Learned
   - "Finding Y is false positive" → Add to Known False Positives
   - "Finding Z - protocol confirmed and fixed" → Add to Validated Findings
4. ONLY THEN update MEMORY.md
```

### Commands for User Confirmation:

After an audit, the user can say:
- `/confirm <finding-id>` - Mark finding as validated (real bug)
- `/reject <finding-id>` - Mark finding as false positive
- `/confirm-all` - Mark all findings as validated
- `/save-learnings` - Save all confirmed/rejected to memory

### What Gets Saved:

**On `/confirm`**:
- Add pattern to "Patterns Learned"
- Increment "Validated" count in statistics
- Add to "Validated Findings" with context

**On `/reject`**:
- Add pattern to "Known False Positives"
- Include context about WHY it's a false positive
- Future audits will suppress this pattern

### Example User Flow:

```
User: /slayer-audit
[Skill runs full 8-stage audit]
[Outputs report with 5 findings]

User: "Finding PM-001 is valid, protocol team confirmed it"
Skill: ✅ Adding PM-001 (fee-on-transfer accounting) to memory as validated pattern.

User: "Finding PM-003 is a false positive - they use a custom SafeERC20"
Skill: ✅ Adding PM-003 to known false positives. Context: custom SafeERC20 wrapper.

User: /save-learnings
Skill: ✅ Memory updated:
- 1 pattern added to Patterns Learned
- 1 pattern added to Known False Positives
- Statistics updated

🌟 Want to help others? Submit a PR with your learnings!
→ https://github.com/pokhrelanmol/slayer-security-audit-skill
```

---

## Contributing Your Learnings

After saving learnings locally, consider sharing with the community:

```bash
cd ~/.claude/skills/slayer-security-audit-skill
git checkout -b add-learnings-[project-name]
git add MEMORY.md
git commit -m "Add validated patterns from [project] audit"
git push origin add-learnings-[project-name]
# Then open PR at GitHub
```

**Your contributions help:**
- Reduce false positives for everyone
- Add validated patterns to the knowledge base
- Make the skill smarter over time

---

*First audit will initialize this memory system. User confirmation makes it smarter, not auto-learning.*
