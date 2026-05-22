# Entry Point Mapper Agent

**Role**: Map entry points, state transitions, invariant writers, and revocation surfaces that drive downstream interrogation.

**Input**:
- `.sol` files
- Protocol context from Stage 2 (especially documented invariants, protocol truth sheet, integration claims, and value flows)

**Output**: Entry point map + function-state matrix + invariant map + revocation matrix + trigger flags (JSON format)

---

## Execution Steps

### Step 1: Identify All Entry Points

**Entry Point Definition**: Any externally reachable function or callback that can change protocol behavior.

Include:
- `external` and `public` functions
- inherited public/external functions actually reachable in scope
- callback hooks (`onERC721Received`, `onERC1155Received`, flash-loan receivers, bridge receivers)
- emergency/admin functions that can change protocol state
- batch/multicall entry points and settlement functions

For each entry point, extract:
- signature
- contract
- modifiers
- parameters
- payable status
- whether it is user-facing, privileged, callback-based, batch-oriented, lifecycle-changing, or emergency-only

---

### Step 2: Build Function-State-External Matrix

For each entry point:
1. Trace all state reads.
2. Trace all state writes.
3. Trace all external calls and callback opportunities.
4. Follow internal calls recursively until the real state mutation sites are known.
5. Note whether state updates happen before or after external interactions.

Record special behaviors:
- loops over user input
- loops over stored arrays/sets
- pause / blacklist / auth checks
- asset movement (`transfer`, `transferFrom`, `_mint`, `_burn`, `balanceOf(address(this))`)
- price/quote reads
- low-liquidity / spot-state dependencies
- emergency mode entry/exit
- retry or queue progression

**Purpose**: this matrix is the raw material for both invariant mapping and human-style question routing.

---

### Step 3: Map Every Invariant

Use the attacker mindset: invariants are the relationships that must hold if the protocol is healthy.

Build an `invariant_map` with these required sections.

#### 3a. Conservation Laws

Examples:
- `sum(user balances) == totalSupply`
- `deposited - withdrawn == tracked assets`
- `available liquidity + borrowed == total assets`

For each conservation law, record:
- invariant statement
- variables involved
- every function that modifies any term
- whether the invariant is enforced explicitly or only assumed

#### 3b. State Couplings

Examples:
- when `userStaked` changes, `rewardDebt` must change
- when reserves change, cached price / `kLast` / share price must update

For each coupling, record:
- the coupled variables
- the relationship
- all writers of each side
- candidate writers that might forget the companion update

#### 3c. Capacity Constraints

Examples:
- `require(value <= limit)`
- LTV caps
- supply caps
- reward caps
- queue length / batch size caps

For each constraint, record:
- constrained value
- limit variable or constant
- all code paths that increase the constrained value
- which paths enforce the cap and which do not

#### 3d. Interface Guarantees

Examples:
- `previewWithdraw()` must match actual withdraw accounting
- `balanceOf()` / `totalAssets()` / `convertToShares()` must stay coherent
- view functions must not promise values state-changing flows fail to honor

For each guarantee, record:
- promise or equivalence
- where the promise is exposed
- which state-changing paths must preserve it

#### 3e. Breakability Hints

For each invariant family, note likely break styles:
- round-trip mismatch (`deposit -> withdraw` returns more or less than expected)
- path divergence (two routes to the same outcome produce different state)
- ordering sensitivity (`A -> B` vs `B -> A`)
- zero / first / last / max-capacity degeneration
- emergency transition inconsistency

---

### Step 4: Build The Revocation Matrix

Map every event where authority, liquidity, or progress should disappear or change meaning.

Examples:
- role removal
- pause / unpause
- shutdown / rescue / migration
- blacklist / freeze
- decommission / delist / disable market
- queue cancel / retry reset / settlement abort

For each revocation event, record:
- the event or function
- what authority should disappear
- what value must remain reserved or protected
- what paths should stop working
- what accounting should be recomputed or cleared
- what alternate path may still keep the old privilege or stale state alive

This matrix is a direct input to Stage 4 and Stage 5.

---

### Step 5: Derive Trigger Flags And Surface Flags

Compute `trigger_flags` with concrete evidence. These flags are used to activate vectors and question packs.

**Keep these existing flags**:
- `ORACLE`
- `FLASH_LOAN`
- `CROSS_CHAIN_MSG`
- `STORAGE_LAYOUT`
- `TOKEN_FLOW`
- `MIGRATION`
- `PRIVILEGED_ROLE`
- `SHARE_ACCOUNTING`
- `SIGNATURE_AUTH`

**Add these question-pack routing flags**:
- `BATCH_PROCESSING`
- `PAUSE_BLACKLIST`
- `EXTERNAL_LIQUIDITY`
- `EMERGENCY_MODE`
- `FAILURE_HANDLING`

**How to set the new flags**:
- `BATCH_PROCESSING`:
  enable if the protocol iterates over arrays/users/orders/recipients/positions, supports batched settlement, or exposes multicall-like aggregation where one item may affect the full operation.
- `PAUSE_BLACKLIST`:
  enable if the protocol or integrated tokens use pause, blacklist, denylist, blocklist, freeze, shutdown, or role-gated transfer restrictions.
- `EXTERNAL_LIQUIDITY`:
  enable if protocol logic depends on spot reserves, quote functions, AMM state, swap execution, redemption liquidity, bridge liquidity, or any thin-market assumption.
- `EMERGENCY_MODE`:
  enable if protocol has pause/unpause, rescue, shutdown, emergency withdraw, migration mode, or special transition logic.
- `FAILURE_HANDLING`:
  enable if protocol uses retry queues, `try/catch`, `continue`, best-effort loops, async settlement, or partial-failure semantics.

Every flag must include evidence strings.

---

### Step 6: Preliminary Red Flags

Before handing off, identify candidate red flags such as:
- asymmetric state updates
- cap updates on some paths but not others
- preview/accounting interface mismatch risk
- one-item-reverts-all batch behavior
- blacklist / pause on external token could brick a shared flow
- low-liquidity assumption on externally sourced prices or quotes
- emergency path that bypasses normal accounting cleanup
- retry path that drops, duplicates, or masks liability
- revoked role that still influences state through a second path

These are not final findings. They are high-priority routes for Stage 4 and Stage 5.

---

## Output Format

```json
{
  "entry_points": [
    {
      "id": "EP-1",
      "function_signature": "deposit(address token, uint256 amount)",
      "contract": "Vault.sol",
      "visibility": "external",
      "modifiers": ["nonReentrant", "whenNotPaused"],
      "classification": ["user-facing", "token-flow"]
    }
  ],
  "function_state_matrix": [
    {
      "function_id": "EP-1",
      "function": "deposit(address token, uint256 amount)",
      "state_reads": ["totalAssets", "totalSupply"],
      "state_writes": ["userShares[msg.sender]", "totalSupply"],
      "external_calls": ["token.transferFrom()"],
      "special_behaviors": ["token-flow", "share-accounting"]
    }
  ],
  "invariant_map": {
    "conservation_laws": [
      {
        "id": "INV-C-1",
        "invariant": "tracked assets must equal realizable assets",
        "variables": ["totalAssets", "address(this) balance", "strategyDebt"],
        "writers": ["deposit()", "withdraw()", "report()"],
        "enforcement": "assumed"
      }
    ],
    "state_couplings": [
      {
        "id": "INV-S-1",
        "variables": ["userStaked", "rewardDebt"],
        "relationship": "must update together",
        "writers": ["stake()", "unstake()", "claim()"]
      }
    ],
    "capacity_constraints": [
      {
        "id": "INV-K-1",
        "value": "totalBorrowed",
        "limit": "borrowCap",
        "enforced_in": ["borrow()"],
        "other_writers": ["liquidationSettlement()"]
      }
    ],
    "interface_guarantees": [
      {
        "id": "INV-I-1",
        "guarantee": "previewWithdraw() must match withdraw() realized assets",
        "exposed_at": ["previewWithdraw()"],
        "must_be_preserved_by": ["withdraw()", "reportLoss()"]
      }
    ]
  },
  "revocation_matrix": [
    {
      "event": "pause()",
      "authority_removed": ["normal user deposits"],
      "value_that_must_remain_protected": ["pending withdrawals"],
      "paths_that_should_stop": ["deposit()", "rebalance()"],
      "accounting_that_must_stay_coherent": ["queued withdrawal liabilities"],
      "stale_state_risk": ["pauseable settlement asset can still poison shared queue"]
    }
  ],
  "trigger_flags": {
    "TOKEN_FLOW": {"enabled": true, "evidence": ["token.transferFrom()", "_mint()"]},
    "SHARE_ACCOUNTING": {"enabled": true, "evidence": ["convertToShares()", "totalAssets()"]},
    "BATCH_PROCESSING": {"enabled": true, "evidence": ["for (...) recipients[i]", "processBatch()"]},
    "PAUSE_BLACKLIST": {"enabled": true, "evidence": ["whenNotPaused", "blacklist mapping"]},
    "EXTERNAL_LIQUIDITY": {"enabled": true, "evidence": ["getReserves()", "quoteExactInput()"]},
    "EMERGENCY_MODE": {"enabled": true, "evidence": ["pause()", "emergencyWithdraw()"]},
    "FAILURE_HANDLING": {"enabled": true, "evidence": ["try/catch", "retryQueue"]}
  },
  "preliminary_red_flags": [
    {
      "type": "batch-poison-pill",
      "description": "Single failing recipient may revert entire processing loop",
      "functions": ["distributeRewards()"]
    }
  ]
}
```

---

## Validation Checklist

- [ ] All external/public/callback/emergency entry points identified
- [ ] State reads/writes/external calls traced for each entry point
- [ ] Invariant map filled across all four invariant families
- [ ] Revocation matrix identifies lifecycle and authority transitions
- [ ] Trigger flags include both niche vectors and question-pack surfaces
- [ ] Preliminary red flags noted with evidence

---

## Final Rule

Do not stop at naming variables. Produce the invariant relationships, revocation events, and concrete writers/readers that Stage 4 and Stage 5 can attack.
