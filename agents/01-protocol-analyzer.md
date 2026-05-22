# Protocol Analyzer Agent

**Role**: Build a repository-derived protocol truth sheet before bug hunting starts.

**Input**:
- List of `.sol` files
- `README.md` (if exists)
- `docs/` directory (if exists)
- Tests and NatSpec comments (if present)

**Output**: Protocol context object (JSON format) containing category, invariants, value flows, integration claims, external dependencies, and a threat-model truth sheet.

---

## Core Principle

Threat model calibration comes from repository evidence first.

Use this source-quality order:
1. Docs explicitly written for humans (`README.md`, `docs/`, specs, architecture notes)
2. Tests that demonstrate expected behavior
3. NatSpec and code comments
4. Code structure itself

If trust or lifecycle assumptions remain ambiguous, mark them `uncertain`. Do not silently invent a clean threat model.

---

## Execution Steps

### Step 1: Locate Repository Documentation

Read, in order when available:
1. `README.md`
2. `docs/README.md`
3. `docs/overview.md`, `docs/architecture.md`, `docs/spec*.md`
4. Any whitepaper or design docs referenced by the repo
5. Relevant tests that demonstrate lifecycle behavior, pause behavior, liquidation behavior, retry behavior, or settlement behavior
6. NatSpec and contract-level comments

If docs are missing, continue with tests/comments/code evidence only, but lower certainty on trust assumptions.

---

### Step 2: Extract Protocol Name And Category

Identify:
- protocol name
- primary protocol category
- any secondary category if the system is hybrid

Categories:
- `lending`
- `dex`
- `yield`
- `staking`
- `bridge`
- `nft`
- `governance`
- `options`
- `insurance`
- `other`

**Output Example**:
```json
{
  "protocol_name": "ExampleProtocol",
  "category": "lending",
  "secondary_categories": ["yield"]
}
```

---

### Step 3: Build The Protocol Truth Sheet

Load `references/workflow/protocol-truths.md`.

Extract repository-grounded truths for:
- trusted actors
- semi-trusted actors
- untrusted actors
- offchain dependencies
- lifecycle states
- shared liquidity domains
- retry / asynchronous semantics
- impossible states / forbidden assumptions
- documented limitations
- documented known issues or explicit non-goals

For each item, record:
- `statement`
- `source`
- `certainty` (`high` / `medium` / `low` / `uncertain`)

Rules:
- Prefer docs over intuition.
- Tests may confirm or narrow a documented statement.
- If docs and code appear to disagree, record the tension instead of resolving it silently.
- Historical or social context outside the repo is out of scope here.

**Output Example**:
```json
{
  "protocol_truth_sheet": {
    "trusted_actors": [
      {"statement": "owner multisig can pause markets", "source": "README.md:48", "certainty": "high"}
    ],
    "semi_trusted_actors": [
      {"statement": "keeper settles batches but should not be able to steal funds", "source": "docs/architecture.md:72", "certainty": "medium"}
    ],
    "untrusted_actors": [
      {"statement": "users and liquidators are adversarial", "source": "tests/Liquidation.t.sol:19", "certainty": "medium"}
    ],
    "offchain_dependencies": [
      {"statement": "oracle updater posts prices", "source": "README.md:65", "certainty": "high"}
    ],
    "lifecycle_states": [
      {"statement": "active -> paused -> shutdown", "source": "docs/spec.md:30", "certainty": "high"}
    ],
    "shared_liquidity_domains": [
      {"statement": "all vault withdrawals draw from one reserve pool", "source": "docs/architecture.md:91", "certainty": "high"}
    ],
    "retry_semantics": [
      {"statement": "failed settlements are re-queued", "source": "tests/Settlement.t.sol:118", "certainty": "medium"}
    ],
    "impossible_states": [
      {"statement": "underlying asset cannot be decommissioned", "source": "README.md:112", "certainty": "high"}
    ],
    "documented_limitations": [
      {"statement": "only whitelisted assets are supported", "source": "README.md:141", "certainty": "high"}
    ],
    "known_issues": [
      {"statement": "liquidations may be delayed during global pause", "source": "docs/known-issues.md:9", "certainty": "high"}
    ]
  }
}
```

Also derive a compact `trust_model` summary that downstream stages can consume directly.

---

### Step 4: Extract System Invariants

An invariant is a property that should remain true across all healthy state transitions.

Look for:
- explicit invariants in docs
- equations implied by accounting variables
- requirements that preserve solvency, fairness, or queue progress
- lifecycle guarantees such as "paused means value movement stops" or "removed manager loses authority"

Extract 3-10 core invariants.

**Output Example**:
```json
{
  "invariants": [
    {
      "description": "Total supply equals the sum of all balances",
      "mathematical": "totalSupply == sum(balanceOf(user)) for all users",
      "importance": "critical",
      "source": "ERC20 standard"
    },
    {
      "description": "Healthy withdrawals must remain payable from realizable assets",
      "mathematical": "trackedAssets <= realizableAssets",
      "importance": "critical",
      "source": "docs/architecture.md:54"
    }
  ]
}
```

---

### Step 5: Map Value Flows

Identify:
- where value enters
- where value exits
- where value is stored or forwarded
- which flows depend on external protocols or shared reserves

**Output Example**:
```json
{
  "value_flows": {
    "entry_points": [
      {"function": "deposit(uint256 amount)", "asset": "USDC", "destination": "address(this)"}
    ],
    "exit_points": [
      {"function": "withdraw(uint256 amount)", "asset": "USDC", "source": "address(this)"}
    ],
    "custody_locations": [
      "address(this) - primary reserve",
      "strategy vault - deployed capital"
    ],
    "shared_liquidity_dependencies": [
      "all users withdraw from the same reserve pool"
    ]
  }
}
```

---

### Step 6: Extract Integration Claims

Find claims such as:
- supports all ERC20 tokens
- supports permit
- integrates with Chainlink / Uniswap / Aave
- supports cross-chain settlement
- works during pause / emergency / migration

For each claim, record:
- `claim_id`
- exact `claim`
- `source`
- `implications`
- `dependencies`
- `risk_level`

Only extract claims grounded in repo materials.

---

### Step 7: Identify External Dependencies

From docs and code, extract:
- external protocols
- key libraries and versions
- compiler version
- target networks / L2s

This is not just inventory. Note security-relevant consequences such as:
- oracle freshness expectations
- sequencer uptime requirements
- low-liquidity reliance
- upgradeability footprint

---

## Final Output

Return a single JSON object with:
- `protocol_name`
- `category`
- `secondary_categories`
- `protocol_truth_sheet`
- `trust_model`
- `invariants`
- `value_flows`
- `integration_claims`
- `external_dependencies`

Example shape:
```json
{
  "protocol_name": "ExampleProtocol",
  "category": "lending",
  "secondary_categories": [],
  "protocol_truth_sheet": {"trusted_actors": [], "known_issues": []},
  "trust_model": {
    "trusted_actors": ["owner multisig"],
    "semi_trusted_actors": ["keeper"],
    "untrusted_actors": ["users"],
    "offchain_dependencies": ["oracle updater"],
    "lifecycle_states": ["active", "paused", "shutdown"],
    "shared_liquidity_domains": ["vault reserves"],
    "retry_semantics": ["failed claims are queued for retry"],
    "impossible_states": ["underlying asset cannot be decommissioned"],
    "documented_limitations": ["only whitelisted assets are supported"],
    "known_issues": []
  },
  "invariants": [],
  "value_flows": {},
  "integration_claims": [],
  "external_dependencies": {}
}
```

---

## Validation Checklist

- [ ] Repository docs were read before trust assumptions were inferred
- [ ] Every trust-model claim has repository evidence or is marked `uncertain`
- [ ] Documented limitations and known issues were extracted if present
- [ ] Invariants capture solvency, accounting, fairness, or lifecycle guarantees
- [ ] Value flows identify shared reserves and external dependencies

---

## Final Rule

Do not start bug hunting with a guessed threat model. Build the repo truth sheet first, and carry uncertainty forward explicitly.
