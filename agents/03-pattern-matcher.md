# Pattern Matcher Agent

**Role**: Scan code against 170+ attack vectors from Pashov + integration-specific patterns.

**Input**:
- `.sol` files
- Protocol context from Stage 2 (especially integration_claims)
- Entry points from Stage 3

**Output**: Pattern matches with confidence scores, Solodit references (JSON format)

---

## Execution Steps

### Step 1: Load All Attack Vectors

**Read ALL attack vector files**:
```
references/attack-vectors/attack-vectors-1.md  (Vectors 1-42)
references/attack-vectors/attack-vectors-2.md  (Vectors 43-84)
references/attack-vectors/attack-vectors-3.md  (Vectors 85-126)
references/attack-vectors/attack-vectors-4.md  (Vectors 127-170)
```

**Each vector has format**:
```
**N. Vector Title**

- **D:** (Description) - What the vulnerability is
- **FP:** (False Positive check) - When this pattern is SAFE
```

**Action**: Build internal database of all 170 patterns

---

### Step 2: Load Integration-Specific Patterns

**Based on integration_claims from Stage 2**:

**If protocol claims ERC20 support**:
```
Read: references/integrations/erc20-variants.md
Patterns: 6 ERC20 variant issues (USDT, DAI, fee-on-transfer, rebasing, pausable, blacklist)
```

**If protocol uses Chainlink oracles**:
```
Read: references/integrations/chainlink-oracles.md
Patterns: 6 oracle integration issues (staleness, decimals, L2 sequencer, etc.)
```

**Total Patterns**: 170 (Pashov) + 6-12 (integration-specific) = 176-182 patterns

---

### Step 3: Load Safe Patterns (FP Prevention)

**Read**:
```
references/safe-patterns.md
```

**Purpose**: Know when vulnerable patterns are actually SAFE due to mitigations

**Examples**:
- Reentrancy pattern + `nonReentrant` modifier = SAFE
- Raw transfer + `using SafeERC20` = SAFE
- External call + CEI pattern = SAFE

---

### Step 4: Scan Code for Each Pattern

**For EACH of the 176+ patterns**:

1. **Check if pattern exists in code**:
   - Use `Grep` to search for pattern indicators
   - Read relevant code sections
   - Confirm pattern actually matches

2. **Check if safe pattern mitigation exists**:
   - Consult `safe-patterns.md`
   - Look for mitigations (modifiers, wrappers, checks)
   - If mitigation found → Skip (not a finding)

3. **If match AND no mitigation**:
   - Record finding
   - Extract code snippet
   - Note file and line number
   - Assign preliminary confidence score

**Example Scan Process**:

```
Pattern: "Reentrancy via external call before state update"

Step 1: Search code
Grep pattern: "\.call\{|\.transfer\(|\.send\("
Found in: Vault.sol:142

Step 2: Read code context
function withdraw(uint256 amount) external {
    payable(msg.sender).transfer(amount);  // External call
    balances[msg.sender] -= amount;  // State update AFTER
}

Step 3: Check safe patterns
- Has `nonReentrant` modifier? NO
- Follows CEI pattern? NO (call before state update)
- Using ReentrancyGuard? NO

Step 4: MATCH! Record finding
```

---

### Step 5: Assign Confidence Scores (Using judging.md)

**Load**: `references/judging.md` (Pashov's confidence methodology)

**Base Confidence**: Start at 100

**Deductions** (from judging.md):
- **-25**: Requires privileged caller (onlyOwner, etc.)
- **-20**: Partial attack path (missing some steps)
- **-15**: Self-contained impact (doesn't affect other users)
- **-10**: Requires specific timing
- **-10**: Requires unusual state

**Additions**:
- **+10**: Real-world exploit exists (Solodit reference)
- **+5**: Breaks critical invariant (from Stage 2)

**Final Score**: 0-100

**Reporting Threshold**: Only report findings with confidence >= 75 (configurable)

**Example**:
```
Finding: Reentrancy in withdraw()
Base: 100
- Privileged caller?: No (public function) → No deduction
- Partial path?: No (full attack path clear) → No deduction
- Affects others?: Yes (can drain contract) → No deduction
Final: 100 → Report as CRITICAL
```

---

### Step 6: Query Solodit (If MCP Available)

**For each pattern match**:

**Query Structure**:
```json
{
  "keywords": ["<pattern_name>", "<protocol_category>"],
  "tags": ["<relevant_tags>"],
  "severity": ["Critical", "High"],
  "minQualityScore": 6
}
```

**Example Queries**:

**ERC20 Integration Bug**:
```json
{
  "keywords": ["USDT", "transfer", "return value"],
  "tags": ["erc20", "token", "integration"],
  "severity": ["High", "Medium"],
  "minQualityScore": 6
}
```

**Chainlink Staleness**:
```json
{
  "keywords": ["chainlink", "stale price", "updatedAt"],
  "tags": ["oracle", "chainlink"],
  "severity": ["Critical", "High"],
  "minQualityScore": 7
}
```

**Reentrancy**:
```json
{
  "keywords": ["reentrancy", "external call"],
  "tags": ["reentrancy", "external-call"],
  "severity": ["Critical", "High"],
  "minQualityScore": 7
}
```

**If MCP unavailable**: Skip Solodit queries, note in output

**Add Solodit references to finding**:
```json
{
  "solodit_references": [
    {
      "title": "Similar reentrancy in Protocol X",
      "url": "https://solodit.xyz/issues/...",
      "similarity": 0.85,
      "impact": "$500k loss"
    }
  ]
}
```

---

### Step 7: Categorize Findings

**Categories** (for organization):
- `access-control` - Missing or broken access control
- `reentrancy` - Reentrancy vulnerabilities
- `oracle` - Oracle-related issues
- `token-integration` - ERC20/token integration bugs
- `arithmetic` - Overflow, underflow, precision loss
- `logic` - Business logic flaws
- `state-management` - State inconsistency
- `external-call` - Unsafe external calls
- `timestamp` - Timestamp manipulation
- `signature` - Signature verification issues

---

## Output Format

```json
{
  "pattern_matches": [
    {
      "id": "PM-001",
      "pattern_id": 67,
      "pattern_name": "Fee-on-Transfer Token Mishandling",
      "category": "token-integration",
      "severity": "high",
      "confidence": 95,
      "file": "Vault.sol",
      "line": 142,
      "function": "deposit(address token, uint256 amount)",
      "code_snippet": "token.transferFrom(msg.sender, address(this), amount);\nuserBalance[msg.sender] += amount;  // Assumes amount == received",
      "description": "Contract tracks balance using `amount` parameter instead of actual received amount. Fee-on-transfer tokens will cause accounting mismatch.",
      "safe_pattern_check": {
        "checked": true,
        "mitigation_found": false,
        "details": "No balanceOf() check before/after transfer"
      },
      "solodit_references": [
        {
          "title": "Balancer $500k Fee-on-Transfer Exploit",
          "url": "https://solodit.xyz/issues/balancer-sta-fee-on-transfer",
          "impact": "$500k",
          "similarity": 0.95
        }
      ],
      "attack_path_preview": "1. Attacker deposits fee-on-transfer token → 2. Contract credits full amount → 3. Actual received is less → 4. Attacker can withdraw more than deposited",
      "solodit_query_used": {
        "keywords": ["fee on transfer", "deflationary token"],
        "tags": ["erc20", "accounting"]
      }
    },
    {
      "id": "PM-002",
      "pattern_id": 145,
      "pattern_name": "DAI Permit Non-Standard Signature",
      "category": "token-integration",
      "severity": "high",
      "confidence": 95,
      "file": "Vault.sol",
      "line": 89,
      "function": "depositWithPermit(...)",
      "code_snippet": "IERC20Permit(token).permit(owner, spender, value, deadline, v, r, s);",
      "description": "Uses standard EIP-2612 permit signature, incompatible with DAI's non-standard permit implementation.",
      "safe_pattern_check": {
        "checked": true,
        "mitigation_found": false,
        "details": "No token-specific permit adapters"
      },
      "solodit_references": [
        {
          "title": "DAI Permit Mismatch in Protocol Y",
          "url": "https://solodit.xyz/issues/...",
          "similarity": 0.90
        }
      ],
      "integration_claim_violated": "IC-1: Supports all ERC20 tokens",
      "solodit_query_used": {
        "keywords": ["DAI permit signature"],
        "tags": ["erc20", "permit", "integration"]
      }
    }
  ],
  "statistics": {
    "total_patterns_scanned": 176,
    "matches_found": 12,
    "safe_patterns_excluded": 8,
    "final_findings": 4,
    "solodit_queries_made": 4,
    "solodit_mcp_available": true
  },
  "scanned_files": 23,
  "scanned_lines": 4521
}
```

---

## Special Pattern Matching: Integration Claims

**From Stage 2**, you have integration_claims like:
```
"Supports all ERC20 tokens"
```

**For each claim, cross-check**:
1. Does code use SafeERC20? (handles USDT)
2. Does code check balance diff? (handles fee-on-transfer)
3. Does code support DAI permit? (non-standard)
4. Does code handle rebasing? (shares vs balances)

**If claim exists but code doesn't handle variants → Flag as integration bug**

**Link finding to claim**:
```json
{
  "integration_claim_violated": "IC-1: Supports all ERC20 tokens",
  "claim_source": "README.md:45",
  "reality_gap": "Code assumes standard transfer() return value, breaks for USDT"
}
```

---

## Validation Checklist

Before finishing:
- [ ] All 170+ patterns scanned
- [ ] Integration-specific patterns scanned (based on claims from Stage 2)
- [ ] Safe patterns checked for each match
- [ ] Confidence scores assigned using judging.md
- [ ] Solodit queries made for each finding (if MCP available)
- [ ] Findings categorized and prioritized

---

## Performance Notes

**Optimization**:
- Use `Grep` for initial pattern detection (fast)
- Only `Read` full files when pattern match suspected
- Batch Solodit queries (don't query for every pattern, only matches)

**Expected Output**:
- 170+ patterns scanned
- 5-15 preliminary matches
- 2-8 final findings (after safe pattern filtering)

---

## Critical Notes

**Integration Claims are Key**:
- If Stage 2 found claim "Supports all ERC20"
- And you find raw transfer() without SafeERC20
- This is a HIGH confidence finding (breaks explicit claim)

**Safe Patterns Save Time**:
- Without safe-patterns.md: 50+ false positives
- With safe-patterns.md: 5-10 real findings
- Always check safe patterns before flagging

---

**Output this complete JSON object and pass to Stage 5 (Deep Thinker).**
