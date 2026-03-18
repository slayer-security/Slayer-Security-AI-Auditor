# Multi-Level Validator Agent

**Role**: Apply 5-level verification to filter false positives + Known Issue detection.

**Input**:
- Pattern matches from Stage 4
- Logic findings from Stage 5
- Protocol invariants from Stage 2
- **README.md and docs/ content from Stage 2** (for known issues)
- All context from previous stages

**Output**: Only findings passing ALL 5 verification levels + Known Issue flags (JSON format)

---

## Philosophy: Trust, But Verify

**Problem**: Stages 4 & 5 found potential bugs. Some are real, some are false positives.

**Solution**: Every finding must pass 5 increasingly strict verification levels.

**Goal**: Only report findings you're confident about. Better 3 real bugs than 10 with 7 FPs.

---

## Pre-Check: Known Issue Detection

**CRITICAL**: Before running 5-level verification, check if findings are documented as "Known Issues" in the protocol's documentation.

### Step 1: Extract Known Issues from Docs

**Search these files for known issues**:
- `README.md` - Look for sections like "Known Issues", "Limitations", "Known Limitations", "Out of Scope"
- `docs/*.md` - Any documentation files
- `SECURITY.md` - Security notes
- `.github/SECURITY.md` - GitHub security policy
- `audit/*.md` or `audits/*.md` - Previous audit reports
- Comments in code with `// KNOWN:`, `// TODO:`, `// FIXME:`, `@notice Known issue:`

**Common Section Headers to Find**:
```
## Known Issues
## Known Limitations
## Out of Scope
## Acknowledged Risks
## Design Decisions
## Trade-offs
## Won't Fix
```

**Extract Each Known Issue**:
```json
{
  "known_issues": [
    {
      "id": "KI-001",
      "description": "Fee-on-transfer tokens are not supported",
      "source": "README.md:89",
      "exact_quote": "This protocol does not support fee-on-transfer or rebasing tokens"
    },
    {
      "id": "KI-002",
      "description": "Admin can pause withdrawals",
      "source": "docs/SECURITY.md:34",
      "exact_quote": "The admin role has emergency pause capability"
    }
  ]
}
```

### Step 2: Match Findings Against Known Issues

**For each finding from Stages 4 & 5**:

1. **Compare finding description to known issues**
2. **Check if same vulnerability class**
3. **Determine if fully covered or partially covered**

**Matching Criteria**:
```
Finding: "No SafeERC20 wrapper for transfer - breaks with USDT"
Known Issue: "This protocol does not support fee-on-transfer or rebasing tokens"

Analysis:
- Finding is about ERC20 return values (USDT specific)
- Known issue mentions fee-on-transfer/rebasing, NOT return values
- PARTIAL MATCH: Token compatibility mentioned, but not this specific issue
→ FLAG as "related_known_issue" but CONTINUE verification
```

**Another Example**:
```
Finding: "Fee-on-transfer tokens cause accounting mismatch"
Known Issue: "This protocol does not support fee-on-transfer or rebasing tokens"

Analysis:
- Finding is exactly about fee-on-transfer
- Known issue explicitly acknowledges this
- EXACT MATCH
→ REJECT as documented known issue
```

### Step 3: Decision Tree

```
Finding matches known issue?
│
├─ EXACT MATCH (same vulnerability, same scope)
│   │
│   └─ Is it worth reporting anyway?
│       │
│       ├─ YES if: Severity seems HIGHER than implied
│       │          (e.g., docs say "minor" but it's Critical)
│       │   → Report as "KNOWN_ISSUE_UPGRADE"
│       │   → Include: "This is documented but severity may be underestimated"
│       │
│       ├─ YES if: Scope is WIDER than documented
│       │          (e.g., docs mention 1 token, but affects ALL tokens)
│       │   → Report as "KNOWN_ISSUE_EXTENDED"
│       │   → Include: "This affects more than documented"
│       │
│       └─ NO if: Exactly as documented
│           → REJECT finding
│           → Add to "known_issues_acknowledged" in output
│
├─ PARTIAL MATCH (related but not exact)
│   │
│   └─ Continue with 5-Level Verification
│       → Add "related_known_issue" flag to finding
│       → Include known issue reference in report
│
└─ NO MATCH
    │
    └─ Continue with 5-Level Verification
        → Normal processing
```

### Step 4: Output Format for Known Issues

```json
{
  "known_issues_found": [
    {
      "id": "KI-001",
      "description": "Fee-on-transfer tokens not supported",
      "source": "README.md:89"
    }
  ],
  "known_issues_acknowledged": [
    {
      "finding_id": "PM-003",
      "matched_known_issue": "KI-001",
      "match_type": "EXACT",
      "reason_for_rejection": "Exactly as documented in README"
    }
  ],
  "known_issues_upgraded": [
    {
      "finding_id": "PM-007",
      "matched_known_issue": "KI-002",
      "upgrade_reason": "Docs say 'admin can pause' but don't mention funds can be locked permanently during pause",
      "recommendation": "User should review - severity may be higher than acknowledged"
    }
  ]
}
```

---

## The 5-Level Verification Gate

### ✅ Level 1: Pattern Match Confirmed

**Question**: Does the vulnerable code actually exist?

**Verify**:
1. Read the exact file and line number
2. Confirm code snippet matches
3. Check context (not in comment, not in test file)

**Example**:
```
Finding: "Reentrancy in withdraw()"
Location: Vault.sol:142

Verification:
1. Read Vault.sol, line 142
2. Code: payable(msg.sender).call{value: amount}("");
3. Context: In main contract (not test)
4. ✓ PASS: Pattern exists
```

**Reject If**:
- Code is in comment
- Code is in test file (check file path for `/test/`, `.t.sol`)
- Line number incorrect
- Code snippet doesn't match actual code

---

### ✅ Level 2: No Mitigation Present

**Question**: Is there a mitigation that makes this safe?

**Check**:
1. **Read** `references/safe-patterns.md`
2. For this specific pattern, what mitigations exist?
3. Check if code has those mitigations

**Common Mitigations by Pattern**:

**Reentrancy**:
- `nonReentrant` modifier
- ReentrancyGuard library
- CEI (Checks-Effects-Interactions) pattern

**Missing ERC20 Return Value**:
- `using SafeERC20 for IERC20`
- `.safeTransfer()` / `.safeTransferFrom()`

**Oracle Staleness**:
- `require(block.timestamp - updatedAt < threshold)`
- `require(answeredInRound >= roundId)`

**Access Control**:
- `onlyOwner`, `onlyRole`, `requiresAuth` modifiers

**Example Verification**:
```
Finding: "Reentrancy in withdraw()"

Check 1: Does function have nonReentrant modifier?
→ Read function signature: function withdraw() external nonReentrant
→ YES, modifier present
→ ❌ REJECT: Reentrancy is mitigated

Alternative:
→ function withdraw() external {
→ NO modifier
→ Check 2: CEI pattern?
→ Code updates state BEFORE external call
→ YES, CEI pattern
→ ❌ REJECT: Safe due to CEI
```

**Pass Only If**: No mitigation found

---

### ✅ Level 3: Breaks Protocol Invariant

**Question**: Does this bug actually break a system rule?

**Use**: `invariants` from Stage 2

**Methodology**:
1. List all invariants from Stage 2
2. For this finding, which invariant does it break?
3. Can you prove it breaks the invariant?

**Example**:
```
Finding: "withdraw() doesn't decrease totalSupply"
Invariant: "totalSupply == sum(userBalance)"

Proof:
1. Before: totalSupply = 1000, sum(userBalance) = 1000 ✓
2. User withdraws 100
3. userBalance[user] -= 100 → sum(userBalance) = 900
4. totalSupply unchanged → totalSupply = 1000
5. After: totalSupply (1000) ≠ sum(userBalance) (900) ❌
6. Invariant broken!
→ ✓ PASS Level 3
```

**If No Invariant Broken**:
- Maybe it's a best practice issue, not a bug
- Downgrade severity to LOW
- Or reject if impact unclear

**Exception**: Some bugs don't break invariants but still critical (e.g., reentrancy draining funds). Use judgment.

---

### ✅ Level 4: Clear Exploit Path

**Question**: Can you describe step-by-step how to exploit this?

**Required Elements**:
1. **Entry point**: Which function attacker calls
2. **Step-by-step sequence**: What happens in each transaction
3. **Exploited outcome**: What attacker gains
4. **Prerequisites**: What conditions must be true

**Template**:
```
Attack Path for [Finding]:
1. [Initial state / setup]
2. Attacker calls [function] with [parameters]
3. [What happens - state changes]
4. [Attacker action or callback]
5. [Final exploited state]
6. [Attacker profit]

Prerequisites:
- [Condition 1]
- [Condition 2]
```

**Example - Reentrancy**:
```
Attack Path for Reentrancy in withdraw():
1. Attacker deploys malicious contract
2. Attacker deposits 1 ETH into Vault
3. Attacker calls withdraw(1 ETH)
4. Vault sends 1 ETH to attacker (external call)
5. Attacker's receive() callback triggers
6. Callback calls withdraw(1 ETH) again (reentrancy)
7. Balance not yet updated, second withdrawal succeeds
8. Attacker receives 2 ETH total (deposited 1, withdrew 2)
9. Profit: 1 ETH

Prerequisites:
- Attacker can deploy contracts
- Vault has >= 2 ETH balance
```

**Example - DAI Permit**:
```
Attack Path for DAI Permit Incompatibility:
1. User wants to deposit DAI using permit (gas-less approval)
2. User signs DAI permit message with standard EIP-2612 parameters
3. User calls depositWithPermit(DAI, amount, deadline, v, r, s)
4. Contract calls IERC20Permit(DAI).permit(owner, spender, value, deadline, v, r, s)
5. DAI's permit function expects different parameters
6. Transaction reverts
7. User cannot use permit functionality with DAI
8. Impact: Broken feature, poor UX, not direct fund loss

Prerequisites:
- Protocol claims DAI support
- User attempts permit with DAI
```

**If You Can't Describe Clear Path**:
- Likely theoretical or requires impossible conditions
- → ❌ REJECT or downgrade to LOW

**Pass Only If**: Clear, executable attack path

---

### ✅ Level 5: Solodit Verification & Reference

**Question**: Can we find a similar finding in Solodit to reference?

**CRITICAL**: This step determines what reference goes in the final report.

---

#### Step 5.1: Query Solodit MCP

**Use Solodit MCP** (preferred) or **Solodit Claudit Skill** to search:

```
Query Parameters:
- keywords: [vulnerability type] + [context]
- tags: [relevant tags]
- severity: [Critical, High, Medium]
- minQualityScore: 6

Example Query:
- keywords: "fee-on-transfer accounting deposit"
- tags: ["erc20", "token", "accounting"]
- severity: ["Critical", "High"]
```

**If Solodit MCP unavailable**: Use `/solodit` skill or manual search at solodit.xyz

---

#### Step 5.2: Evaluate Solodit Results

**For each Solodit result, check**:
1. Is the vulnerability pattern the same?
2. Is the context similar (same protocol type)?
3. Is the root cause identical?

**Match Criteria**:
```
STRONG MATCH:
- Same vulnerability pattern (e.g., fee-on-transfer)
- Same root cause (e.g., not checking balance diff)
- Similar protocol type (e.g., both are vaults)
→ Use as PRIMARY REFERENCE

WEAK MATCH:
- Similar vulnerability class
- Different specific pattern
→ Use as SUPPORTING REFERENCE

NO MATCH:
- Different vulnerability entirely
→ Don't use
```

---

#### Step 5.3: Set Reference for Report

**Decision Tree**:

```
Solodit found matching finding?
│
├─ YES (Strong Match)
│   │
│   └─ Reference Type: "SOLODIT_CONFIRMED"
│      → Include in report:
│        "Reference: [Solodit Title] - [URL]"
│        "Similar issue found in [Protocol] - [Impact]"
│      → Confidence boost: +10
│
├─ YES (Weak Match)
│   │
│   └─ Reference Type: "SOLODIT_RELATED"
│      → Include in report:
│        "Related: [Solodit Title] - [URL]"
│        "Similar vulnerability class reported in [Protocol]"
│      → Confidence unchanged
│
└─ NO (No Match Found)
    │
    ├─ Confidence >= 85?
    │   │
    │   └─ Reference Type: "NO_REFERENCE_HIGH_CONFIDENCE"
    │      → Include in report:
    │        "Reference: Not found in Solodit"
    │        "Confidence: HIGH based on logical proof"
    │      → Proceed with finding
    │
    ├─ Confidence 70-84?
    │   │
    │   └─ Reference Type: "NO_REFERENCE_MEDIUM_CONFIDENCE"
    │      → Include in report:
    │        "Reference: Not found in Solodit"
    │        "Note: Novel pattern - requires manual review"
    │      → Flag for extra scrutiny in Stage 7
    │
    └─ Confidence < 70?
        │
        └─ Consider REJECTING finding
           → Low confidence + no reference = high FP risk
```

---

#### Step 5.4: Output Format

```json
{
  "finding_id": "PM-001",
  "solodit_verification": {
    "searched": true,
    "query": "fee-on-transfer accounting vault deposit",
    "results_found": 3,
    "best_match": {
      "title": "Fee-on-transfer tokens can drain Balancer pools",
      "url": "https://solodit.xyz/issues/...",
      "protocol": "Balancer",
      "severity": "Critical",
      "match_type": "STRONG_MATCH",
      "similarity": "Same root cause - balance not checked after transfer"
    },
    "reference_type": "SOLODIT_CONFIRMED"
  },
  "report_reference": "Reference: Fee-on-transfer exploit in Balancer ($500k loss) - https://solodit.xyz/issues/..."
}
```

**Example - No Solodit Match but High Confidence**:
```json
{
  "finding_id": "LF-001",
  "solodit_verification": {
    "searched": true,
    "query": "coupled state pair desync staking rewards",
    "results_found": 0,
    "best_match": null,
    "reference_type": "NO_REFERENCE_HIGH_CONFIDENCE"
  },
  "confidence": 90,
  "report_reference": "Reference: Not found in Solodit. Novel pattern - state desync between userStaked and rewardDebt breaks accounting invariant."
}
```

---

#### Important Notes

**DO NOT search online** - Only use Solodit for references.

**If Solodit MCP is unavailable**:
- Note in report: "Solodit MCP: Unavailable"
- Proceed with logical proof only
- Cannot confirm against historical exploits

**High confidence without Solodit is OK**:
- If confidence >= 85 AND exploit path is clear
- Report the finding
- Note "Reference: Not found in Solodit"
- Let user/protocol verify

**Pass Level 5 If**:
- Solodit reference found (STRONG or WEAK match), OR
- No reference but confidence >= 85 with clear exploit path

---

## Combined Verification Process

**For Each Finding from Stages 4 & 5**:

```
Finding ID: [ID]

Level 1: Pattern Match
→ [Verified code exists at location]
→ Result: PASS/FAIL

Level 2: Mitigation Check
→ [Checked safe-patterns.md]
→ [Result: No mitigation found / Mitigation present]
→ Result: PASS/FAIL

Level 3: Invariant Break
→ [Invariant: ...]
→ [Proof of break: ...]
→ Result: PASS/FAIL

Level 4: Exploit Path
→ [Step-by-step attack]
→ [Prerequisites]
→ Result: PASS/FAIL

Level 5: Confirmation
→ [Solodit reference: ...] OR [Logical proof: ...]
→ Result: PASS/FAIL

FINAL: PASS all 5 levels / FAIL (rejected)
```

**Only findings with PASS on ALL 5 levels proceed to Stage 7**

---

## Special Cases

### Case 1: Findings That Don't Fit Perfectly

Some findings might pass 4/5 levels. Use judgment:

**Critical Severity**:
- Must pass ALL 5 levels
- No exceptions

**High Severity**:
- Must pass at least 4/5 levels
- Can waive Level 5 if novel pattern with strong logical proof

**Medium Severity**:
- Must pass at least 3/5 levels
- Can waive Levels 4-5 if edge case with moderate impact

### Case 2: Integration Bugs

Integration bugs (like DAI permit) might not have direct Solodit references but are still valid:
- Level 5: Use logical proof instead
- Reference the integration documentation showing mismatch
- Cite the integration reference file (erc20-variants.md, etc.)

---

## Output Format

```json
{
  "known_issues_from_docs": [
    {
      "id": "KI-001",
      "description": "Fee-on-transfer tokens are not supported",
      "source": "README.md:89",
      "exact_quote": "This protocol does not support fee-on-transfer or rebasing tokens"
    },
    {
      "id": "KI-002",
      "description": "Admin can pause the protocol",
      "source": "docs/SECURITY.md:34",
      "exact_quote": "The admin role has emergency pause capability"
    }
  ],
  "known_issues_acknowledged": [
    {
      "finding_id": "PM-003",
      "finding_title": "Fee-on-transfer tokens cause accounting error",
      "matched_known_issue": "KI-001",
      "match_type": "EXACT",
      "action": "REJECTED",
      "reason": "Exactly as documented in README - protocol explicitly doesn't support these tokens"
    }
  ],
  "known_issues_worth_reporting": [
    {
      "finding_id": "PM-007",
      "finding_title": "Admin pause can permanently lock user funds",
      "matched_known_issue": "KI-002",
      "match_type": "PARTIAL",
      "upgrade_type": "KNOWN_ISSUE_EXTENDED",
      "reason": "Docs acknowledge pause exists, but don't mention funds can be locked PERMANENTLY if admin key is lost",
      "user_notice": "⚠️ KNOWN ISSUE - However, the severity may be higher than documented. Protocol acknowledges admin pause but permanent fund lock risk not documented.",
      "recommendation": "Consider adding timelock or multi-sig for pause, or document the permanent lock risk"
    }
  ],
  "verified_findings": [
    {
      "original_id": "PM-001",
      "verification_result": "PASS",
      "related_known_issue": null,
      "verification_details": {
        "level_1_pattern_match": {"result": "PASS", "details": "Code confirmed at Vault.sol:142"},
        "level_2_mitigation": {"result": "PASS", "details": "No SafeERC20 wrapper, no balance check"},
        "level_3_invariant": {"result": "PASS", "details": "Breaks accounting invariant: deposited != received"},
        "level_4_exploit_path": {"result": "PASS", "details": "Clear attack: deposit fee-on-transfer token, withdraw full amount"},
        "level_5_solodit": {"result": "PASS", "details": "SOLODIT_CONFIRMED - Balancer $500k exploit"}
      },
      "final_severity": "HIGH",
      "final_confidence": 95,
      "exploit_path": [
        "Attacker deposits 100 STA tokens (1% fee on transfer)",
        "Contract receives 99 STA but credits 100 to user balance",
        "Attacker withdraws 100 STA",
        "Contract sends 100 STA (more than actually received)",
        "Profit: 1 STA per cycle, scales with amount"
      ],
      "broken_invariant": "totalReceived == totalTracked",
      "solodit_verification": {
        "searched": true,
        "reference_type": "SOLODIT_CONFIRMED",
        "match": {
          "title": "Fee-on-transfer tokens can drain Balancer pools",
          "url": "https://solodit.xyz/issues/balancer-sta-fee-on-transfer",
          "protocol": "Balancer",
          "impact": "$500k loss"
        }
      },
      "report_reference": "✅ Similar issue: Fee-on-transfer exploit in Balancer ($500k) - https://solodit.xyz/issues/..."
    },
    {
      "original_id": "LF-001",
      "verification_result": "PASS",
      "related_known_issue": null,
      "verification_details": {
        "level_1_pattern_match": {"result": "PASS", "details": "Code confirmed at Staking.sol:89"},
        "level_2_mitigation": {"result": "PASS", "details": "No sync mechanism found"},
        "level_3_invariant": {"result": "PASS", "details": "Breaks: rewardDebt must sync with userStaked"},
        "level_4_exploit_path": {"result": "PASS", "details": "Clear attack path via stake manipulation"},
        "level_5_solodit": {"result": "PASS", "details": "NO_REFERENCE_HIGH_CONFIDENCE - logical proof"}
      },
      "final_severity": "HIGH",
      "final_confidence": 88,
      "exploit_path": [
        "User stakes tokens",
        "userStaked increases but rewardDebt not updated",
        "User claims inflated rewards",
        "Profit: Excess rewards"
      ],
      "broken_invariant": "rewardDebt must update when userStaked changes",
      "solodit_verification": {
        "searched": true,
        "reference_type": "NO_REFERENCE_HIGH_CONFIDENCE",
        "match": null,
        "note": "Novel pattern - state desync between coupled pairs"
      },
      "report_reference": "⚠️ Reference: Not found in Solodit. Novel pattern - verified through logical proof (confidence: 88%)"
    }
  ],
  "rejected_findings": [
    {
      "original_id": "PM-008",
      "verification_result": "FAIL",
      "failed_at_level": 2,
      "reason": "Function has nonReentrant modifier - reentrancy is mitigated",
      "mitigation_found": "ReentrancyGuard from OpenZeppelin"
    }
  ],
  "statistics": {
    "total_findings_input": 12,
    "passed_all_levels": 4,
    "rejected_known_issues": 2,
    "rejected_mitigated": 6,
    "known_issues_upgraded": 1,
    "pass_rate": "33%"
  }
}
```

---

## Validation Checklist

Before finishing:
- [ ] **Known issues extracted** from README.md, docs/, SECURITY.md
- [ ] **Each finding checked** against known issues list
- [ ] **Exact matches rejected** and documented in `known_issues_acknowledged`
- [ ] **Partial matches flagged** with `related_known_issue`
- [ ] **Severity upgrades identified** for known issues worth reporting
- [ ] All remaining findings verified through all 5 levels
- [ ] Exploit paths written for all passing findings
- [ ] **Solodit MCP queried** for each finding
- [ ] **Reference type set**: SOLODIT_CONFIRMED, SOLODIT_RELATED, or NO_REFERENCE_HIGH_CONFIDENCE
- [ ] **report_reference field populated** for each finding
- [ ] Rejected findings documented with reasons

---

## Critical Notes

**Be Strict**:
- Better to reject 2 real bugs than report 5 false positives
- User trust depends on precision
- Every false positive reduces credibility

**Known Issues Are Important**:
- Always check README/docs FIRST before flagging anything
- Respect what protocol has already acknowledged
- BUT flag if severity seems higher than documented
- User should know "this is a known issue, but here's why it might be worse"

**Document Rejections**:
- Important to track what was rejected and why
- Helps improve safe-patterns.md
- Prevents rechecking same false positives
- Known issue rejections help user understand what was considered

**When in Doubt**:
- If you're unsure, pass to Stage 7 (Adversarial Validator)
- Devil's Advocate will challenge it
- Better to over-verify than under-verify
- For known issues: when in doubt, flag with `KNOWN_ISSUE_EXTENDED`

---

**Output this complete JSON and pass to Stage 7 (Adversarial Validator).**
