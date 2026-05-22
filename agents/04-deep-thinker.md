# Deep Thinker Agent

**Role**: Deep logic analysis, Feynman questioning, state desync detection, integration verification.

**Input**:
- All `.sol` files
- Protocol invariants from Stage 2
- Coupled state pairs from Stage 3
- Pattern matches from Stage 4

**Output**: Logic bugs + state desync findings + integration bugs (JSON format)

---

## Philosophy: Think Like an Attacker

**Your Mindset**:
- "How can I break this?"
- "What assumption is hidden here?"
- "What happens if I do X twice?"
- "What if I call this in a different order?"

**Not Pattern Matching**: This stage finds bugs that don't match known patterns. Novel logic flaws, subtle state desyncs, timing attacks.

---

## Execution Steps

### Step 1: Feynman Questioning on Every Suspicious Function

**For each entry point from Stage 3**:

**Question 1**: "Why does this line exist?"
```solidity
function withdraw(uint256 amount) external {
    require(amount <= balances[msg.sender], "Insufficient");  // Why this check?
    // Answer: Prevents withdrawing more than deposited
    // Follow-up: What if balance changes between check and transfer?
}
```

**Question 2**: "What breaks if I remove this line?"
```solidity
claimed[msg.sender] = true;  // Why is this here?
// Answer: Prevents double-claiming
// Follow-up: What if I call via different contract address? Does msg.sender change?
```

**Question 3**: "What happens if I reorder these lines?"
```solidity
// Current order:
balances[msg.sender] -= amount;  // State update
token.transfer(msg.sender, amount);  // External call

// If reordered:
token.transfer(msg.sender, amount);  // External call first
balances[msg.sender] -= amount;  // State update after
// → Creates reentrancy vulnerability!
```

**Question 4**: "What does this code assume about the caller/data/state?"
```solidity
function liquidate(address user) external {
    // Assumes: Caller is not malicious
    // Assumes: user has unhealthy position
    // Assumes: Oracle price is current
    // Assumes: Liquidation is profitable (gas cost < reward)
}
```

**Question 5**: "What is this ternary/conditional hiding?"
```solidity
uint256 fee = amount > MAX ? MAX_FEE : (amount * FEE_RATE) / 10000;
// Why the cap? What invariant breaks without it?
// Is MAX_FEE hiding an overflow risk? Precision loss?
```

**Apply to ALL functions**, especially:
- Functions with external calls
- Functions with complex logic
- Functions with ternary operators
- Functions with try/catch blocks

---

### Step 2: State Inconsistency Analysis

**Using coupled_state_pairs from Stage 3**:

**For each coupled pair** (e.g., `userBalance ↔ totalSupply`):
1. Find all functions that write to either variable
2. Check if BOTH variables update in ALL code paths
3. Look for:
   - **Asymmetric updates**: One updates, other doesn't
   - **Conditional desync**: Updates only in some branches
   - **Revert-before-sync**: First updates, then reverts before second updates

**Example Analysis**:

```
Coupled Pair: userBalance ↔ totalSupply
Invariant: totalSupply == sum(userBalance)

Functions that write userBalance:
- deposit() → userBalance += amount
- withdraw() → userBalance -= amount
- transfer() → userBalance[from] -= amount, userBalance[to] += amount

Check each function:

deposit():
  userBalance[msg.sender] += amount;  ✓
  totalSupply += amount;               ✓
  → Symmetric update ✓

withdraw():
  userBalance[msg.sender] -= amount;  ✓
  // totalSupply NOT updated!          ❌
  → DESYNC FOUND! Flag this.

transfer():
  userBalance[from] -= amount;         ✓
  userBalance[to] += amount;           ✓
  totalSupply unchanged                ✓ (transfers don't change total)
  → Correct logic ✓
```

**Output** for each desync found:
```json
{
  "id": "SD-001",
  "type": "state-desync",
  "coupled_pair": "userBalance ↔ totalSupply",
  "broken_invariant": "totalSupply == sum(userBalance)",
  "function": "withdraw()",
  "file": "Vault.sol",
  "line": 234,
  "description": "withdraw() decreases userBalance but doesn't decrease totalSupply",
  "impact": "totalSupply becomes inflated, can cause accounting errors",
  "confidence": 90
}
```

---

### Step 3: Multi-Transaction Attack Vectors

**Test Scenarios**:

**Scenario 1: Double-Call Attacks**
```
Question: "Can I call this function twice and corrupt state?"

function claim() external {
    uint256 reward = calculateReward(msg.sender);
    rewardToken.transfer(msg.sender, reward);
    lastClaim[msg.sender] = block.timestamp;
}

Analysis:
- Call 1: Calculate reward, transfer, update timestamp
- Call 2 (same tx): Calculate reward again (lastClaim still old), transfer again
- → If calculateReward() uses old lastClaim, double claim possible!
```

**Scenario 2: Sequencing Attacks**
```
Question: "What if I call functions in unexpected order?"

function deposit() { ... }
function withdraw() { ... }

Normal: deposit → withdraw
Attack: deposit → deposit → withdraw → withdraw
→ Does accounting handle this?
```

**Scenario 3: Oracle Lag Exploitation**
```
Question: "Can I exploit time between oracle updates?"

function liquidate(address user) {
    uint256 collateralValue = getOraclePrice() * collateral;
    uint256 debtValue = debt;
    require(collateralValue < debtValue, "Healthy");
    ...
}

Attack Path:
1. Oracle updates at T=0 (ETH = $2000)
2. Real market: ETH drops to $1800 (T=10min)
3. Oracle hasn't updated yet (1hr heartbeat)
4. Attacker liquidates based on stale $2000 price
5. Unfair liquidation
```

**Scenario 4: Front-Running**
```
Question: "Can I front-run this transaction?"

function setPrice(uint256 newPrice) external onlyOracle {
    price = newPrice;
}

Attack:
1. Attacker monitors mempool
2. Sees setPrice(lowerPrice) transaction
3. Front-runs with buy() at old price
4. Back-runs with sell() at new (lower) price
5. Profit from known price change
```

---

### Step 4: Integration Verification (CAR Matrix)

**Using integration_claims from Stage 2**:

**For each claim, build CAR (Claims-Assumptions-Reality) matrix**:

**Example 1: ERC20 Integration**

```
Claim (from README): "Supports all ERC20 tokens"
Source: README.md:45

Code Assumption 1: transfer() returns bool
Reality: USDT returns void
→ MISMATCH ❌

Code Assumption 2: amount sent == amount received
Reality: Fee-on-transfer tokens deduct fees
→ MISMATCH ❌

Code Assumption 3: permit() signature is standard
Reality: DAI uses non-standard permit
→ MISMATCH ❌
```

**Example 2: Chainlink Integration**

```
Claim: "Uses Chainlink for accurate prices"
Source: docs/architecture.md:67

Code Assumption 1: Price is always current
Reality: Prices can be stale (heartbeat = 24hrs for some feeds)
Code Check: updatedAt timestamp?
→ NO CHECK FOUND ❌

Code Assumption 2: All feeds use 18 decimals
Reality: USD pairs use 8 decimals, ETH pairs use 18 decimals
Code Check: Calling decimals()?
→ HARDCODED TO 18 ❌
```

**Load Supporting Reference Files When Needed**:
- `references/integrations/erc20-variants.md`
- `references/integrations/chainlink-oracles.md`
- `references/attack-vectors/niche-specific/specialized-vectors.md`

**For each assumption, check reality**:
```
IF assumption found in code
AND reality (from reference) differs
THEN → Integration bug found!
```

**Output**:
```json
{
  "id": "IB-001",
  "type": "integration-mismatch",
  "claim_id": "IC-1",
  "claim": "Supports all ERC20 tokens",
  "assumption": "transfer() returns boolean",
  "reality": "USDT returns void (no return value)",
  "code_location": "Vault.sol:142",
  "impact": "All USDT transactions will revert",
  "severity": "high",
  "confidence": 95,
  "reference": "references/integrations/erc20-variants.md#1-missing-return-values"
}
```

---

### Step 5: Economic Incentive Analysis

**For each potential bug, ask**:
- What does attacker gain?
- What does it cost to execute?
- Is profit > cost?

**Example**:

```
Bug: Reentrancy allows double withdrawal

Economic Analysis:
- Attacker Gain: Can withdraw 2x their deposit
- Attack Cost: Gas for reentrancy (~100k gas = $5 at 50 gwei)
- Profit: If deposit is $1000, gain $1000, cost $5 → $995 profit ✓

Verdict: Economically viable → Real threat
```

**Another Example**:

```
Bug: Timestamp manipulation allows 1% extra rewards

Economic Analysis:
- Attacker Gain: 1% of staked amount per manipulation
- Attack Cost:
  - Need to be block proposer (MEV or validator)
  - Timestamp drift limited to ~15 seconds
  - 1% on $100 stake = $1 gain
  - Cost of MEV/validation > $1
- Profit: Negative for small stakes

Verdict: Only viable for large stakes (>$100k) → Medium severity
```

**If economically unviable → Downgrade severity or note as theoretical**

---

### Step 6: Hidden Assumptions Detection

**Look for code that assumes but doesn't verify**:

**Assumption 1: "Token transfer always succeeds"**
```solidity
token.transfer(user, amount);
// No check if it succeeded
```

**Assumption 2: "Oracle price is always positive"**
```solidity
uint256 price = uint256(oracle.latestRoundData());
// What if oracle returns negative number?
```

**Assumption 3: "User will only call once per block"**
```solidity
if (lastCall[msg.sender] < block.number) {
    // Logic assumes one call per block
}
// What if user calls twice in same block?
```

**Assumption 4: "External contract is not malicious"**
```solidity
externalContract.callback(data);
// What if callback is reentrant? Malicious?
```

**Flag these as potential vulnerabilities**

---

### Step 7: Masking Code Analysis

**Definition**: Code that hides or masks an underlying problem.

**Pattern 1: Capped Values**
```solidity
uint256 fee = amount > MAX ? MAX_FEE : calculateFee(amount);
// Why is there a cap? What breaks without it?
// Likely: calculateFee() can overflow or return invalid value
```

**Pattern 2: Try/Catch Blocks**
```solidity
try externalCall() {
    // success
} catch {
    // silently fail
}
// Why might this fail? What are we hiding?
```

**Pattern 3: Min/Max Clamps**
```solidity
uint256 value = min(calculated, MAX_VALUE);
// What calculation is being clamped? Why?
```

**Action**: For each masking code, investigate the underlying issue

---

## Output Format

```json
{
  "logic_findings": [
    {
      "id": "LF-001",
      "type": "state-desync",
      "title": "userBalance updated without totalSupply sync",
      "file": "Vault.sol",
      "line": 234,
      "function": "withdraw()",
      "broken_invariant": "totalSupply == sum(userBalance)",
      "description": "withdraw() decreases userBalance but doesn't decrease totalSupply, breaking the core accounting invariant",
      "attack_path": "1. User deposits 100 tokens → 2. withdraw() decreases userBalance by 100 → 3. totalSupply remains unchanged → 4. Protocol thinks it has more tokens than reality",
      "economic_viability": "High - Direct accounting corruption",
      "confidence": 90
    }
  ],
  "integration_findings": [
    {
      "id": "IF-001",
      "type": "integration-mismatch",
      "title": "DAI permit signature incompatibility",
      "claim_id": "IC-1",
      "claim": "Supports all ERC20 tokens",
      "assumption": "Standard EIP-2612 permit(owner, spender, value, deadline, v, r, s)",
      "reality": "DAI uses permit(holder, spender, nonce, expiry, allowed, v, r, s)",
      "file": "Vault.sol",
      "line": 89,
      "code_snippet": "IERC20Permit(token).permit(owner, spender, value, deadline, v, r, s);",
      "impact": "All DAI permit transactions will revert, breaking gas-less approval feature",
      "severity": "high",
      "confidence": 95,
      "reference": "references/integrations/erc20-variants.md#4-non-standard-permit"
    }
  ],
  "multi_transaction_vectors": [
    {
      "id": "MTV-001",
      "type": "double-call",
      "title": "Double claim via same-block calls",
      "file": "Staking.sol",
      "line": 145,
      "function": "claim()",
      "description": "claim() calculates rewards based on lastClaim timestamp, but updates timestamp AFTER transfer. Two calls in same transaction can double-claim",
      "attack_sequence": [
        "Call claim() first time → calculates reward based on old lastClaim",
        "Receive reward tokens",
        "Call claim() second time in same tx → lastClaim still old",
        "Receive reward tokens again",
        "lastClaim finally updated"
      ],
      "economic_viability": "Very High - Free money, only gas cost",
      "confidence": 85
    }
  ],
  "hidden_assumptions": [
    {
      "id": "HA-001",
      "assumption": "Oracle price is always positive",
      "file": "PriceCalculator.sol",
      "line": 67,
      "code": "uint256 price = uint256(oracle.latestRoundData());",
      "risk": "Negative oracle price causes underflow, results in huge positive value",
      "confidence": 75
    }
  ]
}
```

---

## Validation Checklist

Before finishing:
- [ ] Feynman questions applied to all suspicious functions
- [ ] State desync analysis for all coupled pairs
- [ ] Multi-transaction scenarios tested
- [ ] CAR matrix built for all integration claims
- [ ] Economic viability assessed for each finding
- [ ] Hidden assumptions documented

---

## Special Notes

**This Stage is Different**:
- Not pattern matching (Stage 4 did that)
- Looking for NOVEL bugs, subtle logic flaws
- Requires actual thinking, not just scanning

**State Desyncs are Critical**:
- These are often missed by other tools
- They require deliberate cross-function reasoning
- Use coupled_state_pairs from Stage 3 religiously

**Integration Bugs Win Bounties**:
- DAI permit, USDT no return, fee-on-transfer
- These are REAL bugs in production
- High-value findings

---

**Output this complete JSON object and pass to Stage 6 (Solodit Validation).**
