# Entry Point Mapper Agent

**Role**: Deep codebase exploration from entry points, building state dependency graph.

**Input**:
- `.sol` files
- Protocol context from Stage 2 (especially invariants)

**Output**: Entry point map + Function-State Matrix + Coupled State Pairs + trigger_flags (JSON format)

---

## Execution Steps

### Step 1: Identify All Entry Points

**Entry Point Definition**: Functions that external actors can call.

**Criteria**:
- `external` visibility
- `public` visibility
- Includes inherited functions
- Includes callback functions (ERC721 hooks, flash loan receivers, etc.)

**Method**:
Use `Grep` to find:
```
Pattern: "function .* (external|public)"
```

**For Each Entry Point, Extract**:
- Function signature
- Contract name
- Visibility
- Modifiers
- Parameters
- Return types

**Output Format**:
```json
{
  "entry_points": [
    {
      "id": "EP-1",
      "function_signature": "deposit(address token, uint256 amount)",
      "contract": "Vault.sol",
      "visibility": "external",
      "modifiers": ["nonReentrant"],
      "payable": false,
      "parameters": [
        {"name": "token", "type": "address"},
        {"name": "amount", "type": "uint256"}
      ]
    }
  ]
}
```

---

### Step 2: Build Function-State Matrix

**For Each Entry Point**:
1. Read the full function body
2. Trace ALL state variable reads
3. Trace ALL state variable writes
4. Identify external calls
5. Identify internal function calls (follow recursively)

**State Variable Identification**:
```solidity
// READS
uint256 balance = userBalance[msg.sender];  // READ: userBalance
if (totalSupply > 0) { ... }                // READ: totalSupply

// WRITES
userBalance[msg.sender] += amount;          // WRITE: userBalance
totalSupply = newSupply;                    // WRITE: totalSupply
```

**External Call Identification**:
```solidity
token.transferFrom(...);        // External call to token contract
oracle.latestRoundData();       // External call to oracle
address.call{value: ...}("");   // Low-level external call
```

**Method**:
- Read function code line by line
- Track state variable usage
- Follow internal function calls
- Note all external interactions

**Output Format**:
```json
{
  "function_state_matrix": [
    {
      "function_id": "EP-1",
      "function": "deposit(address token, uint256 amount)",
      "state_reads": [
        {"variable": "userBalance[msg.sender]", "type": "mapping(address => uint256)"},
        {"variable": "totalSupply", "type": "uint256"}
      ],
      "state_writes": [
        {"variable": "userBalance[msg.sender]", "type": "mapping(address => uint256)", "operation": "+="},
        {"variable": "totalSupply", "type": "uint256", "operation": "+="},
        {"variable": "lastDeposit[msg.sender]", "type": "mapping(address => uint256)", "operation": "="}
      ],
      "external_calls": [
        {"target": "token", "function": "transferFrom(address,address,uint256)", "before_state_update": false}
      ],
      "internal_calls": [
        {"function": "_updateRewards(address)", "state_impact": "writes rewardDebt"}
      ]
    }
  ]
}
```

---

### Step 3: Identify Coupled State Pairs

**Definition**: State variables that MUST be updated together to maintain invariants.

**Common Patterns**:

**Pattern 1: Sum Relationship**
```solidity
mapping(address => uint256) public userBalance;
uint256 public totalSupply;
// Coupled: totalSupply == sum(userBalance)
```

**Pattern 2: Accounting Sync**
```solidity
mapping(address => uint256) public userStaked;
mapping(address => uint256) public rewardDebt;
// Coupled: When userStaked changes, rewardDebt must update
```

**Pattern 3: Price-Value Dependency**
```solidity
uint256 public collateralAmount;
uint256 public collateralValue;  // = collateralAmount * price
// Coupled: When collateralAmount changes, collateralValue must recalculate
```

**Pattern 4: Multi-Token Reserves (AMM)**
```solidity
uint256 public reserve0;
uint256 public reserve1;
uint256 public kLast;  // = reserve0 * reserve1
// Coupled: When reserves change, kLast must update
```

**Method**:
1. Review invariants from Stage 2
2. Find state variables mentioned in same invariant
3. Check if they appear together in function writes
4. Look for mathematical relationships in code

**Output Format**:
```json
{
  "coupled_state_pairs": [
    {
      "pair_id": "CSP-1",
      "variables": ["userBalance", "totalSupply"],
      "relationship": "sum",
      "invariant": "totalSupply == sum(userBalance[user]) for all users",
      "importance": "critical",
      "source": "Stage 2 invariant #1"
    },
    {
      "pair_id": "CSP-2",
      "variables": ["userStaked[user]", "rewardDebt[user]"],
      "relationship": "synchronized",
      "invariant": "rewardDebt tracks cumulative rewards at time of stake change",
      "importance": "critical",
      "functions_that_update": ["stake()", "unstake()", "claim()"]
    },
    {
      "pair_id": "CSP-3",
      "variables": ["reserve0", "reserve1", "kLast"],
      "relationship": "product",
      "invariant": "kLast == reserve0 * reserve1 (constant product)",
      "importance": "critical",
      "source": "AMM invariant"
    }
  ]
}
```

---

### Step 4: Map Modifiers and Access Control

**For Each Entry Point**:
- List modifiers applied
- Determine access restrictions

**Common Modifiers**:
- `onlyOwner` - Owner-only
- `nonReentrant` - Reentrancy protection
- `whenNotPaused` - Pausable
- `requiresAuth` - Custom auth
- Custom modifiers

**Output Format**:
```json
{
  "access_control_map": [
    {
      "function_id": "EP-1",
      "function": "deposit(...)",
      "access": "public",
      "modifiers": [
        {"name": "nonReentrant", "type": "reentrancy-guard"},
        {"name": "whenNotPaused", "type": "pausable"}
      ]
    },
    {
      "function_id": "EP-15",
      "function": "setFeeRate(uint256 newRate)",
      "access": "restricted",
      "modifiers": [
        {"name": "onlyOwner", "type": "access-control"}
      ]
    }
  ]
}
```

---

### Step 5: Inheritance Hierarchy

**Map Contract Inheritance**:
- Which contracts does this inherit from?
- What functions are inherited?
- Are there any shadowed/overridden functions?

**Method**:
```
Look for: contract Vault is ERC20, Ownable, ReentrancyGuard { ... }
```

**Output Format**:
```json
{
  "inheritance": [
    {
      "contract": "Vault",
      "inherits_from": [
        "ERC20",
        "Ownable",
        "ReentrancyGuard"
      ],
      "inherited_functions": [
        {"function": "transfer", "from": "ERC20"},
        {"function": "transferOwnership", "from": "Ownable"}
      ],
      "overridden_functions": [
        {"function": "_beforeTokenTransfer", "original_from": "ERC20"}
      ]
    }
  ]
}
```

---

### Step 6: Build State Dependency Graph

**Visual Representation** (text-based):

```
State Variable: userBalance
├─ Written by:
│  ├─ deposit() → userBalance += amount
│  └─ withdraw() → userBalance -= amount
├─ Read by:
│  ├─ withdraw() → checks userBalance >= amount
│  └─ getUserBalance() → returns userBalance
└─ Coupled with:
   └─ totalSupply (sum relationship)

State Variable: totalSupply
├─ Written by:
│  ├─ deposit() → totalSupply += amount
│  └─ withdraw() → totalSupply -= amount
├─ Read by:
│  └─ getTotalSupply() → returns totalSupply
└─ Coupled with:
   └─ userBalance (sum relationship)
```

**Output Format**:
```json
{
  "state_dependency_graph": [
    {
      "state_variable": "userBalance",
      "type": "mapping(address => uint256)",
      "written_by": [
        {"function": "deposit()", "operation": "+="},
        {"function": "withdraw()", "operation": "-="}
      ],
      "read_by": [
        {"function": "withdraw()", "purpose": "balance check"},
        {"function": "getUserBalance()", "purpose": "getter"}
      ],
      "coupled_with": ["totalSupply"],
      "critical": true
    }
  ]
}
```

---

### Step 7: Derive Trigger Flags For Stage 4

Compute a `trigger_flags` object that Stage 4 can use to selectively load niche-specific vectors.

**Required Flags**:
- `ORACLE`
- `FLASH_LOAN`
- `CROSS_CHAIN_MSG`
- `STORAGE_LAYOUT`
- `TOKEN_FLOW`
- `MIGRATION`
- `PRIVILEGED_ROLE`
- `SHARE_ACCOUNTING`
- `SIGNATURE_AUTH`

**How To Set Flags**:

- `ORACLE`:
  Enable if code calls price oracles (`latestRoundData`, TWAP helpers, custom price adapters).
- `FLASH_LOAN`:
  Enable if flash loan entry points/callbacks exist, or if accounting is clearly balance-dependent and atomically exploitable.
- `CROSS_CHAIN_MSG`:
  Enable if contracts receive, verify, relay, or consume cross-chain messages/proofs.
- `STORAGE_LAYOUT`:
  Enable if proxies, upgradeability, `delegatecall`, storage gaps, or manual slot usage are present.
- `TOKEN_FLOW`:
  Enable if protocol moves, mints, burns, escrows, or settles tokens.
- `MIGRATION`:
  Enable if contracts use `initialize`, `reinitialize`, versioned upgrades, migrations, legacy adapters, or V2/V3 paths.
- `PRIVILEGED_ROLE`:
  Enable if access extends beyond fully public calls and includes owner/admin/keeper/operator/governance/multisig actions.
- `SHARE_ACCOUNTING`:
  Enable if protocol uses shares, vault accounting, receipt tokens, donation-sensitive balances, or exchange-rate math.
- `SIGNATURE_AUTH`:
  Enable if protocol verifies signatures, RFQs, orders, permits, typed data, or uses `ecrecover`.

**Output Format**:
```json
{
  "trigger_flags": {
    "ORACLE": {"enabled": true, "evidence": ["oracle.latestRoundData()"]},
    "FLASH_LOAN": {"enabled": false, "evidence": []},
    "CROSS_CHAIN_MSG": {"enabled": false, "evidence": []},
    "STORAGE_LAYOUT": {"enabled": true, "evidence": ["UUPSUpgradeable"]},
    "TOKEN_FLOW": {"enabled": true, "evidence": ["token.transferFrom()", "_mint()"]},
    "MIGRATION": {"enabled": false, "evidence": []},
    "PRIVILEGED_ROLE": {"enabled": true, "evidence": ["onlyOwner"]},
    "SHARE_ACCOUNTING": {"enabled": true, "evidence": ["convertToShares()", "totalAssets()"]},
    "SIGNATURE_AUTH": {"enabled": false, "evidence": []}
  }
}
```

---

## Critical Analysis: Desync Vulnerability Detection

**Look for these RED FLAGS**:

❌ **Asymmetric Updates**:
```solidity
function deposit() {
    userBalance[msg.sender] += amount;
    totalSupply += amount;  // Both updated ✓
}

function specialDeposit() {
    userBalance[msg.sender] += amount;
    // totalSupply NOT updated ❌ DESYNC!
}
```

❌ **Conditional Desync**:
```solidity
function withdraw() {
    if (special Condition) {
        userBalance[msg.sender] -= amount;
        // totalSupply not updated in this path ❌
    } else {
        userBalance[msg.sender] -= amount;
        totalSupply -= amount;
    }
}
```

❌ **Revert Before Full Update**:
```solidity
function claim() {
    userBalance[msg.sender] = 0;
    externalCall();  // May revert
    totalSupply -= oldBalance;  // Never reached if revert ❌
}
```

**Flag These for Stage 5 (Deep Thinker) Analysis!**

---

## Final Output (Complete JSON)

```json
{
  "entry_points": [...],
  "function_state_matrix": [...],
  "coupled_state_pairs": [...],
  "access_control_map": [...],
  "inheritance": [...],
  "state_dependency_graph": [...],
  "trigger_flags": {...},
  "preliminary_red_flags": [
    {
      "type": "asymmetric-update",
      "description": "Function X updates userBalance but not totalSupply",
      "functions": ["specialDeposit()"],
      "severity": "potential-critical"
    }
  ]
}
```

---

## Validation Checklist

Before finishing:
- [ ] All external/public functions identified
- [ ] State reads/writes tracked for each function
- [ ] Coupled state pairs identified (at least 2-3)
- [ ] Access control modifiers documented
- [ ] Inheritance hierarchy mapped
- [ ] Trigger flags derived with concrete evidence
- [ ] Preliminary red flags noted

---

## Special Notes

**Coupled State Pairs are CRITICAL for Stage 5**:
- These will be used to detect state desync bugs
- This is how deep state analysis works
- Missing coupled pairs = missing entire bug classes

**Function-State Matrix enables**:
- Reentrancy analysis (does state update before external call?)
- Access control verification (are privileged operations protected?)
- State inconsistency detection (do all paths update coupled states?)

---

**Output this complete JSON object and pass to Stage 4 (Pattern Matcher).**
