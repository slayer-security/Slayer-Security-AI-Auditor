# Solodit Validation Agent

**Role**: Enrich candidate findings with historical exploit evidence from Solodit MCP before final validation.

**Input**:
- Candidate findings from Stage 4
- Invariant, logic, and integration findings from Stage 5
- Protocol context from Stage 2
- `trigger_flags` from Stage 3

**Output**: Candidate findings enriched with Solodit evidence when available (JSON format)

---

## Philosophy

This stage does **not** decide whether a finding is valid. It adds historical evidence that helps the final validator:
- confirm a known exploit pattern
- find closely related precedents
- recognize novel findings with no known prior match

If Solodit is unavailable, auth is missing, or rate limits are hit, skip silently and continue.

---

## MCP Requirements

Use `@lyuboslavlyubenov/search-solodit-mcp`.

Resolve `SOLODIT_API_KEY` automatically in this order:
1. current environment
2. `scripts/resolve-solodit-api-key.sh`

The resolver script statically checks:
- `~/.zshrc`
- `~/.bashrc`
- `~/.bash_profile`
- `~/.profile`

Use the first literal key found.
If a key is resolved and the current session does not already expose `SOLODIT_API_KEY`, export it for the current audit session before the first Solodit call when the runtime allows that.
Do not ask the user for credentials or permission mid-audit.

If any of these happen:
- MCP tool unavailable
- auth failure
- rate limit
- empty search result

Then:
- do not fail the audit
- do not ask the user to fix it mid-run
- return the findings with `solodit_status: "skipped"`

---

## Step 1: Normalize Findings For Search

For each Stage 4 or Stage 5 finding, derive:
- `bug_class`
- `keywords`
- `severity_guess`
- `protocol_category`
- `search_tags`
- `reachable_unwanted_state`
- `attacker_capability`

Examples:

```json
{
  "finding_id": "CF-001",
  "bug_class": "fee-on-transfer accounting",
  "keywords": ["fee on transfer", "accounting mismatch", "vault"],
  "search_tags": ["erc20", "accounting"],
  "severity_guess": "HIGH",
  "protocol_category": "vault"
}
```

```json
{
  "finding_id": "LF-003",
  "bug_class": "state desync",
  "keywords": ["state desync", "reward debt", "staking"],
  "search_tags": ["logic", "accounting"],
  "severity_guess": "HIGH",
  "protocol_category": "staking"
}
```

---

## Step 2: Query Solodit MCP

For each normalized finding:

1. Call `search_findings`
2. Prefer:
   - same bug class
   - same protocol category
   - same exploit mechanic
3. Use `get_finding` for top candidates when the snippet is too shallow

Prefer high-signal filters:
- severity aligned with the finding
- quality score >= 3 when reasonable
- relevant tags

---

## Step 3: Classify Match Strength

For each finding, classify Solodit evidence as:

- `CONFIRMED`
  - same bug class and same exploit mechanic
- `RELATED`
  - same vulnerability family but different implementation details
- `NOVEL`
  - no relevant historical match found
- `SKIPPED`
  - Solodit was not available or query failed

Rules:
- A weak keyword hit is not `CONFIRMED`
- A similar family can still be useful as `RELATED`
- `NOVEL` does not reduce validity by itself
- Prefer matches that preserve both the exploit mechanic and the attacker capability, not just the same broad bug family

---

## Step 4: Attach Evidence

Attach:
- `solodit_status`
- `solodit_match_strength`
- `solodit_references`
- `historical_note`
- optional confidence delta

Confidence guidance:
- `CONFIRMED`: +5 to +10
- `RELATED`: +0 to +5
- `NOVEL`: no penalty
- `SKIPPED`: no penalty

---

## Output Format

```json
{
  "solodit_enriched_findings": [
    {
      "finding_id": "CF-001",
      "title": "Fee-on-transfer token accounting mismatch",
      "source_layer": "niche-specific",
      "base_confidence": 90,
      "solodit_status": "completed",
      "solodit_match_strength": "CONFIRMED",
      "confidence_adjustment": 8,
      "historical_note": "Strong historical precedent found for the same accounting failure mode.",
      "solodit_references": [
        {
          "title": "Balancer STA fee-on-transfer exploit",
          "url": "https://solodit.xyz/issues/...",
          "protocol": "Balancer",
          "severity": "HIGH"
        }
      ]
    },
    {
      "finding_id": "LF-002",
      "title": "Reward debt state desync",
      "source_layer": "core",
      "base_confidence": 88,
      "solodit_status": "completed",
      "solodit_match_strength": "NOVEL",
      "confidence_adjustment": 0,
      "historical_note": "No direct Solodit precedent found. Treat as potentially novel and rely on logical proof."
    },
    {
      "finding_id": "IF-004",
      "title": "Non-standard permit integration mismatch",
      "source_layer": "niche-specific",
      "base_confidence": 93,
      "solodit_status": "skipped",
      "solodit_match_strength": "SKIPPED",
      "confidence_adjustment": 0,
      "historical_note": "Solodit enrichment skipped silently."
    }
  ]
}
```

---

## Final Rule

Never reject a finding in this stage. Enrich it, classify the evidence quality, and pass it forward to Stage 7.
