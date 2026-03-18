# Slayer Security Auditor

Elite Solidity security auditor combining **Pashov's 170 attack vectors**, **Nemesis deep state analysis**, **Solodit real-world intelligence**, and **adversarial validation** for maximum bug detection with minimal false positives.

---

## What This Skill Does

Slayer Security Auditor performs an **8-stage automated security audit** on Solidity smart contracts:

| Stage | Agent | Purpose |
|-------|-------|---------|
| 1 | Setup | Filter test files, identify scope |
| 2 | Protocol Analyzer | Extract invariants from docs |
| 3 | Entry Mapper | Map state dependencies from entry points |
| 4 | Pattern Matcher | Scan 170+ attack vectors |
| 5 | Deep Thinker | Nemesis-style logic analysis |
| 6 | Validator | 5-level verification gate |
| 7 | Adversarial Validator | Devil's advocate FP filter |
| 8 | Report | Generate findings + update memory |

### Key Features

- **170+ Attack Vectors**: Pashov's comprehensive vulnerability patterns
- **24 ERC20 Variants**: Catches USDT, DAI permit, fee-on-transfer, rebasing issues
- **Solodit Integration**: Verifies findings against real-world exploits
- **Known Issue Detection**: Filters documented issues from reports
- **Learning System**: MEMORY.md improves with user confirmation
- **Zero False Positive Goal**: Multi-level validation with adversarial challenge

---

## Installation

### Claude Code

**Option 1: Direct Install from GitHub**
```bash
# In Claude Code, run:
/plugin install https://github.com/pokhrelanmol/slayer-security-audit-skill
```

**Option 2: Manual Installation**
```bash
# Clone to your skills directory
git clone https://github.com/pokhrelanmol/slayer-security-audit-skill ~/.claude/skills/slayer-security-audit-skill
```

**Option 3: Project-Level Installation**
```bash
# Clone into your project's .claude/skills directory
mkdir -p .claude/skills
git clone https://github.com/pokhrelanmol/slayer-security-audit-skill .claude/skills/slayer-security-audit-skill
```

### OpenAI Codex CLI

```bash
# Install via skill-installer
codex skill install https://github.com/pokhrelanmol/slayer-security-audit-skill

# Or manually clone to Codex skills directory
git clone https://github.com/pokhrelanmol/slayer-security-audit-skill ~/.codex/skills/slayer-security-audit-skill
```

For project-level:
```bash
mkdir -p .codex/skills
git clone https://github.com/pokhrelanmol/slayer-security-audit-skill .codex/skills/slayer-security-audit-skill
```

### Cursor

```bash
# Clone to Cursor skills directory (user-level)
git clone https://github.com/pokhrelanmol/slayer-security-audit-skill ~/.cursor/skills/slayer-security-audit-skill

# Or project-level
mkdir -p .cursor/skills
git clone https://github.com/pokhrelanmol/slayer-security-audit-skill .cursor/skills/slayer-security-audit-skill
```

### Windsurf

Windsurf uses `.windsurfrules` and rulebooks. To install:

```bash
# Clone the skill
git clone https://github.com/pokhrelanmol/slayer-security-audit-skill

# Copy SKILL.md content to your .windsurfrules or create a rulebook
# In Windsurf, create a new rulebook named "slayer-audit" with the SKILL.md content
```

Or add to your `.windsurfrules`:
```
# Include Slayer Security Auditor
@import slayer-security-audit-skill/SKILL.md
```

---

## Quick Start

After installation, simply ask your AI assistant:

```
/slayer-audit
```

Or use natural language:
```
"Run slayer security audit on this codebase"
"Audit the contracts in src/"
"Run slayer-audit on Vault.sol"
```

---

## Commands

### Main Audit Command

| Command | Description |
|---------|-------------|
| `/slayer-audit` | Run full 8-stage security audit |
| `/slayer-audit src/Vault.sol` | Audit specific file(s) |

### Finding Confirmation Commands

After receiving an audit report, confirm or reject findings to improve the learning system:

| Command | Description |
|---------|-------------|
| `/confirm <finding-id>` | Mark finding as validated (real bug) |
| `/reject <finding-id>` | Mark finding as false positive |
| `/confirm-all` | Mark all findings as validated |
| `/save-learnings` | Save all confirmed/rejected to MEMORY.md |

### Example Workflow

```
User: /slayer-audit

[Skill runs full 8-stage audit]
[Outputs report with findings: PM-001, PM-002, LF-001]

User: Finding PM-001 is valid, protocol team confirmed it
AI: Adding PM-001 (fee-on-transfer accounting) to memory as validated pattern.

User: Finding PM-002 is a false positive - they use a custom SafeERC20
AI: Adding PM-002 to known false positives. Context: custom SafeERC20 wrapper.

User: /save-learnings
AI: Memory updated:
    - 1 pattern added to Patterns Learned
    - 1 pattern added to Known False Positives
    - Statistics updated
```

---

## Memory System

The skill includes a learning system via `MEMORY.md` that:

1. **Stores validated patterns** - Bugs confirmed by users boost future confidence
2. **Tracks false positives** - Suppresses known FPs in future audits
3. **Records protocol quirks** - Integration-specific issues discovered
4. **Updates statistics** - Precision tracking over time

**Important**: MEMORY.md is NEVER auto-updated. It only updates when you explicitly confirm or reject findings using the commands above.

### Memory Location

- **Skill-level**: `~/.claude/skills/slayer-security-audit-skill/MEMORY.md`
- **Persists across projects** - Learnings apply to all audits

### Contributing Learnings (Optional)

Found a validated bug pattern or false positive? Share it with the community!

**Step 1: Confirm findings locally**
```
/confirm PM-001
/reject PM-003
/save-learnings
```

**Step 2: Submit PR with your learnings**
```bash
cd ~/.claude/skills/slayer-security-audit-skill

# Create a branch for your contribution
git checkout -b add-learnings-projectname

# Stage your updated MEMORY.md
git add MEMORY.md

# Commit with context
git commit -m "Add validated patterns from ProjectX audit

- PM-001: fee-on-transfer accounting (confirmed)
- PM-003: false positive - custom SafeERC20 wrapper"

# Push and create PR
git push origin add-learnings-projectname
```

**Step 3: Open PR at** [github.com/pokhrelanmol/slayer-security-audit-skill](https://github.com/pokhrelanmol/slayer-security-audit-skill)

**What to include in your PR:**
- Pattern name and description
- Context (protocol type, why it's valid/FP)
- Solodit reference if available

Your contribution helps everyone get fewer false positives and catch more real bugs!

---

## What Gets Detected

**170+ Attack Vectors** covering:
- Token standards (ERC20/721/1155/4626/777)
- Proxy patterns (UUPS, transparent, beacon, diamond)
- DeFi logic (liquidation, oracle, flash loans, TWAP)
- Reentrancy, access control, signature issues
- Cross-chain and L2 vulnerabilities

**Deep Logic Analysis** (Nemesis-style):
- State desync between coupled variables
- Multi-transaction attack sequences
- Hidden assumptions in code
- Economic incentive analysis

**Integration Bugs**:
- 24 ERC20 variants (USDT, DAI permit, fee-on-transfer, rebasing)
- Chainlink oracle staleness and decimals
- Uniswap/Aave/Compound quirks

---

## Report Format

Findings include:

```markdown
### H-1: Fee-on-Transfer Tokens Break Accounting

**Severity**: High
**Contract**: Vault.sol:142
**Confidence**: 95%

**Description**:
Protocol claims "supports all ERC20" but doesn't check balance
difference after transfer, breaking with fee-on-transfer tokens.

**Broken Invariant**: totalReceived == totalTracked

**Exploit Path**:
1. Attacker deposits 100 STA tokens (1% fee)
2. Contract receives 99 but credits 100
3. Attacker withdraws 100
4. Profit: 1 token per cycle

**Reference**: Similar issue: Balancer $500k exploit
https://solodit.xyz/issues/balancer-sta-fee-on-transfer

**Fix**:
Use balance diff verification for deposits.
```

---

## Configuration

### Solodit MCP (Optional)

For real-world exploit verification, configure Solodit MCP:

```json
// .claude/mcp.json
{
  "mcpServers": {
    "solodit": {
      "command": "npx",
      "args": ["-y", "@lyuboslavlyubenov/search-solodit-mcp"]
    }
  }
}
```

If unavailable, the skill continues with local reference files and notes "Solodit MCP: Unavailable" in reports.

### Custom Attack Patterns

Add your own patterns to `references/attack-vectors/custom-patterns.md`:

```markdown
### CP-001: Sandwich Attack on Swap

**Summary**: DEX swaps without slippage protection

**Description**:
Attacker front-runs swap with buy, back-runs with sell...

**Reference**: https://solodit.xyz/issues/...
```

---

## File Structure

```
slayer-security-audit-skill/
├── SKILL.md                 # Main orchestrator
├── MEMORY.md                # Learning system (user-confirmed)
├── README.md                # This file
├── agents/
│   ├── 01-protocol-analyzer.md
│   ├── 02-entry-mapper.md
│   ├── 03-pattern-matcher.md
│   ├── 04-deep-thinker.md
│   ├── 05-validator.md
│   └── 06-adversarial-validator.md
└── references/
    ├── attack-vectors/
    │   ├── attack-vectors-1.md (42 vectors)
    │   ├── attack-vectors-2.md (42 vectors)
    │   ├── attack-vectors-3.md (42 vectors)
    │   ├── attack-vectors-4.md (44 vectors)
    │   └── custom-patterns.md (user-defined)
    ├── integrations/
    │   ├── erc20-variants.md (24 patterns)
    │   ├── chainlink-oracles.md
    │   └── protocol-integration-patterns.md
    ├── safe-patterns.md
    ├── judging.md
    └── report-formatting.md
```

---

## Updating

To update to the latest version:

```bash
# Claude Code
/plugin update slayer-security-audit-skill

# Or manually
cd ~/.claude/skills/slayer-security-audit-skill && git pull
```

Or ask your AI:
```
"Update slayer-security-audit-skill to latest version"
```

---

## Credits & References

- **Pashov's Solidity Auditor**: 170 attack vectors foundation
- **Nemesis**: Deep thinking methodology
- **Weird ERC20**: 24 token variant patterns from [d-xo/weird-erc20](https://github.com/d-xo/weird-erc20)
- **Solodit**: Real-world vulnerability database

---

## License

MIT License - See LICENSE file for details.

---

## Contributing

1. Fork the repository
2. Add patterns to `references/attack-vectors/custom-patterns.md`
3. Submit PR with validation test cases

---

## Support

- Issues: [GitHub Issues](https://github.com/pokhrelanmol/slayer-security-audit-skill/issues)
- Discussions: [GitHub Discussions](https://github.com/pokhrelanmol/slayer-security-audit-skill/discussions)
