# Protocol Analyzer Agent

**Role**: Deep protocol understanding from documentation and code.

**Input**:
- List of `.sol` files
- README.md (if exists)
- docs/ directory (if exists)

**Output**: Protocol context object (JSON format) containing invariants, value flows, integration claims, and protocol category.

---

## Execution Steps

### Step 1: Locate Documentation

**Priority Order**:
1. `README.md` in project root
2. `docs/README.md`
3. `docs/overview.md` or `docs/architecture.md`
4. Whitepaper (if referenced)
5. Docs/Technical docs if referenced.
6. Code comments and NatSpec

**Action**:
```
Read README.md
If not found: Ask user for protocol documentation
If user provides none: Extract from code comments only
```

### Step 2: Extract Protocol Name & Category

**From Documentation, identify**:
- Protocol name
- Protocol type/category

**Categories** (choose primary):
- `lending` - Collateralized lending, money markets (Aave, Compound style)
- `dex` - Decentralized exchange, AMM (Uniswap, Curve style)
- `yield` - Yield aggregator, farming (Yearn style)
- `staking` - Staking, validators
- `bridge` - Cross-chain bridges
- `nft` - NFT marketplace, collections
- `governance` - DAO, voting systems
- `options` - Options, derivatives
- `insurance` - DeFi insurance
- `other` - If none fit

**Output Format**:
```json
{
  "protocol_name": "ExampleProtocol",
  "category": "lending"
}
```

---

### Step 3: Extract System Invariants

**Definition**: An invariant is a property that MUST ALWAYS be true.

**Common Invariant Patterns by Category**:

**Lending/Vault Protocols**:
- `totalDeposits == sum(userDeposits)`
- `totalCollateralValue >= totalDebtValue`
- `userCollateral[user] * collateralRatio >= userDebt[user]`
- `availableLiquidity + totalBorrowed == totalDeposited`

**DEX/AMM Protocols**:
- `reserve0 * reserve1 >= K` (constant product)
- `totalLPTokens * price == totalReserveValue`
- `sum(userLPBalance) == totalLPSupply`

**Staking Protocols**:
- `totalStaked == sum(userStaked)`
- `rewardsDistributed <= rewardsAccumulated`
- `userStaked[user] + userRewards[user] <= totalStaked + totalRewards`

**ERC20/Token Protocols**:
- `totalSupply == sum(balanceOf(user))`
- `allowance[owner][spender] >= 0`

**Method**:
1. Search documentation for phrases like:
   - "invariant"
   - "must always"
   - "guaranteed"
   - "cannot exceed"
   - "should equal"

2. Examine code for `require()` statements that enforce rules
3. Look for comments explaining mathematical relationships
4. Identify state variables that move together

**Extract 3-7 core invariants**

**Output Format**:
```json
{
  "invariants": [
    {
      "description": "Total supply equals sum of all balances",
      "mathematical": "totalSupply == sum(balanceOf(user)) for all users",
      "importance": "critical",
      "source": "ERC20 standard"
    },
    {
      "description": "Collateral value must exceed debt value",
      "mathematical": "userCollateral * collateralPrice >= userDebt * debtPrice",
      "importance": "critical",
      "source": "README.md:45, enforced in liquidate()"
    }
  ]
}
```

---

### Step 4: Map Value Flows

**Identify**:
- Where does value ENTER the protocol?
- Where does value EXIT the protocol?
- Where is value STORED (custody)?

**Entry Points** (functions that bring value in):
- `deposit()`, `stake()`, `swap()`, `mint()`
- Functions marked `payable`
- Functions calling `transferFrom(user, address(this), ...)`

**Exit Points** (functions that send value out):
- `withdraw()`, `unstake()`, `claim()`
- Functions calling `transfer(user, ...)` or `call{value: ...}`

**Custody** (where value sits):
- `address(this)` balance
- Vault contracts
- External protocol integrations (Aave deposits, Uniswap LPs, etc.)

**Output Format**:
```json
{
  "value_flows": {
    "entry_points": [
      {"function": "deposit(uint256 amount)", "asset": "USDC", "destination": "address(this)"},
      {"function": "depositETH() payable", "asset": "ETH", "destination": "vault contract"}
    ],
    "exit_points": [
      {"function": "withdraw(uint256 amount)", "asset": "USDC", "source": "address(this)"},
      {"function": "claim()", "asset": "reward tokens", "source": "rewardVault"}
    ],
    "custody_locations": [
      "address(this) - holds user USDC deposits",
      "vault contract at 0x... - holds staked ETH",
      "Aave lending pool - earns yield on idle funds"
    ]
  }
}
```

---

### Step 5: Extract Integration Claims

**Definition**: Statements the protocol makes about external integrations.

**Look For Phrases Like**:
- "Supports all ERC20 tokens"
- "Compatible with Chainlink oracles"
- "Works with any Uniswap V2 pair"
- "Integrates with Aave V3"
- "Supports EIP-2612 permit"

**Critical**: These claims often hide assumptions that break with reality.

**For Each Claim, Extract**:
1. The exact claim
2. Source (which document, which line)
3. Implications (what this claim assumes about code)
4. Dependencies (which external contracts/standards)

**Example**:
```
Claim: "Supports all ERC20 tokens"
Source: README.md:45
Implications:
  - Must handle tokens without return values (USDT)
  - Must handle fee-on-transfer tokens (STA)
  - Must handle rebasing tokens (stETH)
  - Must handle non-standard permit (DAI)
  - Scan this https://github.com/d-xo/weird-erc20?tab=readme-ov-file#weird-erc20-tokens know issue with weird token and find any relavent breakpoint 

Dependencies: Any ERC20 token address
Risk Level: MEDIUM - many ERC20 variants exist
```

**Output Format**:
```json
{
  "integration_claims": [
    {
      "claim_id": "IC-1",
      "claim": "Supports all ERC20 tokens",
      "source": "README.md:45",
      "implications": [
        "Must handle USDT (no return value)",
        "Must handle fee-on-transfer tokens",
        "Must handle rebasing tokens",
        "Must handle non-standard permit (DAI)"
      ],
      "dependencies": ["ERC20 standard", "EIP-2612 (permit)"],
      "risk_level": "medium"
    },
    {
      "claim_id": "IC-2",
      "claim": "Uses Chainlink oracles for price feeds",
      "source": "docs/architecture.md:23",
      "implications": [
        "Must check price staleness",
        "Must handle decimal differences (8 vs 18)",
        "Must check sequencer uptime (if L2)"
      ],
      "dependencies": ["Chainlink AggregatorV3Interface"],
      "risk_level": "critical"
    }
  ]
}
```

---

### Step 6: Identify External Dependencies

**From Code & Docs, Find**:
- External protocols integrated (Uniswap, Aave, Chainlink, etc.)
- Library versions (OpenZeppelin version matters!)
- Solidity compiler version
- Network targets (Ethereum, Arbitrum, Optimism, etc.)

**Why This Matters**:
- OpenZeppelin 4.x vs 5.x have breaking changes
- L2 networks require sequencer checks for oracles
- Different Uniswap versions have different attack surfaces

**Output Format**:
```json
{
  "external_dependencies": {
    "protocols": [
      {"name": "Chainlink", "usage": "Price oracles", "version": "AggregatorV3"},
      {"name": "Uniswap V3", "usage": "Token swaps", "version": "0.8.x"}
    ],
    "libraries": [
      {"name": "OpenZeppelin", "version": "4.9.3"},
      {"name": "Solmate", "version": "6.2.0"}
    ],
    "compiler": "0.8.19",
    "networks": ["Ethereum Mainnet", "Arbitrum One"]
  }
}
```

---

### Step 7: Identify Trust Assumptions

**Question**: What does this protocol TRUST to behave correctly?

**Common Trust Assumptions**:
- **Admin/Owner**: Can upgrade contracts, pause, change parameters
- **Oracles**: Provide accurate prices
- **External Protocols**: Aave won't pause reserves, Uniswap pools have liquidity
- **Users**: Will act rationally (or irrationally - adversarial assumption)
- **Network**: Block times, gas prices, finality

**Output Format**:
```json
{
  "trust_assumptions": [
    {
      "entity": "Protocol Owner",
      "trust_level": "high",
      "powers": ["pause contracts", "upgrade implementation", "set fee rates"],
      "mitigation": "Timelock (48 hours)",
      "risk": "Owner key compromise = protocol control"
    },
    {
      "entity": "Chainlink Oracles",
      "trust_level": "high",
      "powers": ["provide asset prices"],
      "mitigation": "staleness checks, circuit breakers",
      "risk": "Stale price = incorrect liquidations"
    }
  ]
}
```

---

## Final Output (Complete JSON)

Combine all sections into final output:

```json
{
  "protocol_name": "ExampleProtocol",
  "category": "lending",
  "invariants": [
    {"description": "...", "mathematical": "...", "importance": "...", "source": "..."}
  ],
  "value_flows": {
    "entry_points": [...],
    "exit_points": [...],
    "custody_locations": [...]
  },
  "integration_claims": [
    {"claim_id": "...", "claim": "...", "source": "...", "implications": [...], "dependencies": [...], "risk_level": "..."}
  ],
  "external_dependencies": {
    "protocols": [...],
    "libraries": [...],
    "compiler": "...",
    "networks": [...]
  },
  "trust_assumptions": [
    {"entity": "...", "trust_level": "...", "powers": [...], "mitigation": "...", "risk": "..."}
  ]
}
```

---

## Validation Checklist

Before finishing, verify:
- [ ] Extracted at least 3 invariants
- [ ] Identified protocol category
- [ ] Mapped value entry and exit points
- [ ] Extracted ALL integration claims (critical for Stage 5)
- [ ] Listed external dependencies with versions
- [ ] Identified trust assumptions

**If README.md missing**: Explicitly note this in output and extract what you can from code.

---

## Special Notes

**Integration Claims are CRITICAL**:
- These will be used in Stage 5 to build the Claims-Assumptions-Reality (CAR) matrix
- This is how we catch bugs like "DAI permit" issues
- Be thorough - missing a claim means missing potential integration bugs

**Invariants are CRITICAL**:
- These will be used in Stage 7 to verify if bugs actually break system rules
- Clear invariants = better false positive filtering
- If unsure, err on side of including more invariants

---

**Output this complete JSON object and pass to next stage (Entry Mapper).**
