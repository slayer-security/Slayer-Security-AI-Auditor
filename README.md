# Slayer Security Auditor

Elite Solidity security auditor combining **broad attack-vector coverage**, **deep state analysis**, **Solodit real-world intelligence**, and **adversarial validation** for maximum bug detection with minimal false positives.

---

## What This Skill Does

Slayer Security Auditor performs an **8-stage automated security audit** on Solidity smart contracts:

| Stage | Agent | Purpose |
|-------|-------|---------|
| 1 | Setup | Filter test files, identify scope |
| 2 | Protocol Analyzer | Extract invariants from docs |
| 3 | Entry Mapper | Map state dependencies from entry points |
| 4 | Pattern Matcher | Scan 170+ attack vectors |
| 5 | Deep Thinker | Deep protocol logic analysis |
| 6 | Solodit Validation | Historical exploit enrichment via Solodit MCP |
| 7 | Final Validator | Known-issue screening, verification, and adversarial review |
| 8 | Report | Generate findings and audit artifacts |

### Key Features

- **170+ Attack Vectors**: Broad vulnerability coverage across common smart contract failure modes
- **24 ERC20 Variants**: Catches USDT, DAI permit, fee-on-transfer, rebasing issues
- **Solodit Integration**: Verifies findings against real-world exploits
- **Known Issue Detection**: Filters documented issues from reports
- **Zero False Positive Goal**: Dedicated historical enrichment plus unified final validation

---

## Installation

### Claude Code

**Option 1: Direct Install from GitHub**
```bash
# In Claude Code, run:
/plugin install https://github.com/slayer-security/Slayer-Security-AI-Auditor
```

**Option 2: Manual Installation**
```bash
# Clone to your skills directory
git clone https://github.com/slayer-security/Slayer-Security-AI-Auditor ~/.claude/skills/slayer-security-ai-auditor
```

**Option 3: Project-Level Installation**
```bash
# Clone into your project's .claude/skills directory
mkdir -p .claude/skills
git clone https://github.com/slayer-security/Slayer-Security-AI-Auditor .claude/skills/slayer-security-ai-auditor
```

### OpenAI Codex CLI

```bash
# Install via skill-installer
codex skill install https://github.com/slayer-security/Slayer-Security-AI-Auditor

# Or manually clone to Codex skills directory
git clone https://github.com/slayer-security/Slayer-Security-AI-Auditor ~/.codex/skills/slayer-security-ai-auditor
```

For project-level:
```bash
mkdir -p .codex/skills
git clone https://github.com/slayer-security/Slayer-Security-AI-Auditor .codex/skills/slayer-security-ai-auditor
```

### Cursor

```bash
# Clone to Cursor skills directory (user-level)
git clone https://github.com/slayer-security/Slayer-Security-AI-Auditor ~/.cursor/skills/slayer-security-ai-auditor

# Or project-level
mkdir -p .cursor/skills
git clone https://github.com/slayer-security/Slayer-Security-AI-Auditor .cursor/skills/slayer-security-ai-auditor
```

### Windsurf

Windsurf uses `.windsurfrules` and rulebooks. To install:

```bash
# Clone the skill
git clone https://github.com/slayer-security/Slayer-Security-AI-Auditor

# Copy SKILL.md content to your .windsurfrules or create a rulebook
# In Windsurf, create a new rulebook named "slayer-audit" with the SKILL.md content
```

Or add to your `.windsurfrules`:
```
# Include Slayer Security Auditor
@import slayer-security-ai-auditor/SKILL.md
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

---

## What Gets Detected

**170+ Attack Vectors** covering:
- Token standards (ERC20/721/1155/4626/777)
- Proxy patterns (UUPS, transparent, beacon, diamond)
- DeFi logic (liquidation, oracle, flash loans, TWAP)
- Reentrancy, access control, signature issues
- Cross-chain and L2 vulnerabilities

**Deep Logic Analysis**:
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

The workflow assumes `SOLODIT_API_KEY` may be present in the environment. If the MCP is unavailable, auth is missing, or rate limits are hit, the audit silently skips Solodit enrichment and continues.

### Attack Vector Layers

Stage 4 now uses four layers:
- `references/attack-vectors/attack-vectors.md` for core stable vectors
- `references/attack-vectors/custom-attack-vectors.md` for team/user-defined vectors
- `references/attack-vectors/live-hack-db/live-hack-vectors.md` for mechanics distilled from real hacks in `references/hacks.csv`
- `references/attack-vectors/niche-specific/specialized-vectors.md` for trigger-gated deep checks

The pattern matcher always loads core, custom, and live-hack-db vectors. It only loads niche-specific vectors when Stage 3 trigger flags indicate the protocol surface is relevant.

The `references/integrations/` files remain as supporting research references. Stage 4 does not treat them as primary scan layers anymore.

To add custom vectors, follow:
- `references/attack-vectors/how-to-add-custom-pattern.md`

Then append your new entry to `references/attack-vectors/custom-attack-vectors.md`:

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
slayer-security-ai-auditor/
├── SKILL.md                 # Main orchestrator
├── README.md                # This file
├── agents/
│   ├── 01-protocol-analyzer.md
│   ├── 02-entry-mapper.md
│   ├── 03-pattern-matcher.md
│   ├── 04-deep-thinker.md
│   ├── 05-solodit-validator.md
│   └── 06-validator.md
└── references/
    ├── attack-vectors/
    │   ├── attack-vectors.md (core vectors)
    │   ├── custom-attack-vectors.md (team/user-defined)
    │   ├── how-to-add-custom-pattern.md (authoring guide)
    │   ├── vector-schema.md (canonical non-core vector schema)
    │   ├── live-hack-db/
    │   │   ├── live-hack-vectors.md (mechanics from real hacks)
    │   │   └── how-to-refresh-live-hack-db.md
    │   └── niche-specific/
    │       └── specialized-vectors.md (trigger-gated deep checks)
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
/plugin install https://github.com/slayer-security/Slayer-Security-AI-Auditor

# Or manually
cd ~/.claude/skills/slayer-security-ai-auditor && git pull
```

Or ask your AI:
```
"Update Slayer Security Auditor to the latest version"
```

---

## Credits & References

- **Weird ERC20**: 24 token variant patterns from [d-xo/weird-erc20](https://github.com/d-xo/weird-erc20)
- **Solodit**: Real-world vulnerability database

---

## License

MIT License - See LICENSE file for details.

---

## Contributing

1. Fork the repository
2. Follow `references/attack-vectors/how-to-add-custom-pattern.md`
3. Add patterns to `references/attack-vectors/custom-attack-vectors.md`
4. Submit PR with validation test cases

---

## Support

- Issues: [GitHub Issues](https://github.com/slayer-security/Slayer-Security-AI-Auditor/issues)
- Discussions: [GitHub Discussions](https://github.com/slayer-security/Slayer-Security-AI-Auditor/discussions)
