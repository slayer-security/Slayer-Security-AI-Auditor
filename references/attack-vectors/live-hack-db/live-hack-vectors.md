# Live Hack DB Vectors

Mechanics distilled from `references/hacks.csv` so Stage 4 can match against recurring real-world exploit classes.

Scope rules for this layer:
- Include mechanics that can plausibly map to code patterns, state transitions, or protocol design flaws
- Exclude incidents that are primarily operational (`private key compromised`, `frontend attack`, `DNS hijack`) unless the row clearly exposes a reusable code weakness

Current source basis:
- `references/hacks.csv`
- filtered to `Classification == Protocol Logic`

---

### LV-001: Access Control Drift Or Authorization Gap

**Trigger**: `PRIVILEGED_ROLE`
**Summary**: Sensitive state transitions are reachable by the wrong caller or by an under-scoped privileged path.
**Mechanic**: Functions that mint, upgrade, withdraw, reconfigure, whitelist, or validate proofs rely on missing, weak, or bypassable authorization.
**Detection Clues**:
- weak modifiers on admin-sensitive functions
- alternate code paths that skip access checks
- owner/operator role overlap without clear boundary
**False Positive Checks**:
- every privileged branch is gated by a single, auditable authority model
- delegated authority cannot widen its own scope
**Examples From Hacks CSV**:
- SQ Protocol
- Quant
- Aethir
- SubQuery Network

### LV-002: Oracle Price Manipulation Or Misconfiguration

**Trigger**: `ORACLE`
**Summary**: Protocol trusts manipulable, stale, or mis-scaled pricing inputs.
**Mechanic**: Price-dependent accounting reads an oracle or pricing source that can be spoofed, delayed, thinly traded, or incorrectly normalized.
**Detection Clues**:
- stale/heartbeat checks missing
- decimal normalization hardcoded
- single-source price dependency on thin liquidity
**False Positive Checks**:
- robust oracle composition and stale protection exist
- attacker cannot cheaply move the priced venue or the protocol uses safe delay/TWAP assumptions
**Examples From Hacks CSV**:
- SEA Token
- Sharwa.Finance
- Blend Pools V2
- Moonwell Lending

### LV-003: Flash-Loan-Assisted State Distortion

**Trigger**: `FLASH_LOAN | TOKEN_FLOW | ORACLE`
**Summary**: Atomic capital temporarily distorts state that the protocol treats as stable.
**Mechanic**: Balances, pool shares, oracle observations, borrow indices, or collateral ratios are sampled during an attacker-controlled flash loan window.
**Detection Clues**:
- flash loan callbacks or obvious atomic composability
- balance-dependent accounting in deposit/withdraw/borrow flows
- single-transaction multi-step state reads and writes
**False Positive Checks**:
- protocol revalidates state after external effects
- sampled values are not attacker-controllable within one transaction
**Examples From Hacks CSV**:
- SmartCredit
- JUDAO
- Cyrus Finance
- Wise Lending V2

### LV-004: Infinite Mint Or Unsound Supply Inflation

**Trigger**: `TOKEN_FLOW | SHARE_ACCOUNTING | PRIVILEGED_ROLE`
**Summary**: Users or privileged paths can inflate supply beyond intended conservation rules.
**Mechanic**: Minting, accounting conversion, or reserve backing checks are incomplete, letting attackers create redeemable claims from nothing or from under-collateralized state.
**Detection Clues**:
- mint paths without full backing validation
- inconsistent reserve-to-supply accounting
- burn/mint loops that ratchet supply upward
**False Positive Checks**:
- every mint is tied to conserved collateral or explicit capped authority
- accounting invariant is enforced on both normal and exceptional paths
**Examples From Hacks CSV**:
- MAP Protocol
- DGLD
- Saga
- Port3 Network

### LV-005: Donation Or Share Accounting Skew

**Trigger**: `SHARE_ACCOUNTING | TOKEN_FLOW`
**Summary**: Unsolicited transfers or empty-state share math distort exchange rates in an attacker-favorable way.
**Mechanic**: Raw token balances, donation-sensitive math, or asymmetric mint/burn rounding let attackers capture value from future users.
**Detection Clues**:
- vault math based on `balanceOf(address(this))`
- first-depositor sensitivity
- share minting that uses stale or externally mutable totals
**False Positive Checks**:
- internal accounting excludes unsolicited balances
- bootstrap protection and dead shares eliminate empty-state capture
**Examples From Hacks CSV**:
- Venus Core Pool
- Curve LlamaLend
- Goose Finance
- dTRINITY dLEND

### LV-006: Bridge, Proof, Or Message Forgery

**Trigger**: `CROSS_CHAIN_MSG | SIGNATURE_AUTH`
**Summary**: Protocol accepts invalid bridge state, spoofed cross-chain messages, or forged proofs.
**Mechanic**: Verification logic under-binds origin, proof material, peer identity, or finality assumptions.
**Detection Clues**:
- custom proof verification
- message handlers with weak source binding
- fake proof/state proof/state root acceptance paths
**False Positive Checks**:
- full domain binding and replay protection exist
- proof verification delegates to hardened, immutable infrastructure with narrow interfaces
**Examples From Hacks CSV**:
- Verus-Ethereum Bridge
- Hyperbridge
- FOOM Cash
- CrossCurve

### LV-007: Initialization, Migration, Or Proxy Takeover

**Trigger**: `MIGRATION | STORAGE_LAYOUT | PRIVILEGED_ROLE`
**Summary**: Upgrade and migration surfaces expose uninitialized, replayable, or ownership-stealing paths.
**Mechanic**: `initialize`, `reinitialize`, migration adapters, proxy admin flows, or deprecated contracts remain callable or misconfigured.
**Detection Clues**:
- initializer functions without permanent lockout
- versioned contract coexistence with stale approvals or stale assets
- deprecated contracts still own value or authority
**False Positive Checks**:
- initializers are disabled after first use
- migration drains, approvals, and asset routing are one-way and complete
**Examples From Hacks CSV**:
- Aurellion
- Renegade
- Transit Finance
- Rari Capital

### LV-008: Signature, Order, Or RFQ Authentication Gap

**Trigger**: `SIGNATURE_AUTH`
**Summary**: Offchain authorization is valid in more contexts than intended.
**Mechanic**: Signed payload omits route, recipient, chain, nonce, fee terms, or settlement path, allowing replay or forged fills.
**Detection Clues**:
- `permit`, RFQ, order settlement, offchain quotes
- partial hashing of execution context
- reusable signatures across functions or contracts
**False Positive Checks**:
- signatures bind full execution context and single-use nonce
- domain separator cannot drift across deployments or chains unexpectedly
**Examples From Hacks CSV**:
- TrustedVolumes
- Giddy
- US Permissionless Dollar

### LV-009: Slippage, Quoting, Or Router Trust Abuse

**Trigger**: `TOKEN_FLOW`
**Summary**: Settlement trusts quoted outputs or routes without enforcing user-provided economic bounds.
**Mechanic**: Attacker exploits stale quotes, weak slippage checks, path ambiguity, or router authority to extract value.
**Detection Clues**:
- route execution without min-out or max-in enforcement
- quoting functions reused as settlement truth
- offchain router or bundler decides economically sensitive fields
**False Positive Checks**:
- user bounds are enforced onchain at execution
- quote source is advisory only and recomputed before settlement
**Examples From Hacks CSV**:
- Kipseli
- YO Protocol
- Hyperdrive HL

### LV-010: Fake Collateral Or Reserve Mismatch

**Trigger**: `TOKEN_FLOW | ORACLE`
**Summary**: Protocol accepts assets, reserves, or backing values that do not actually support issued liabilities.
**Mechanic**: Collateral onboarding, reserve accounting, or backing verification trusts spoofable or non-equivalent assets.
**Detection Clues**:
- collateral lists without strong asset validation
- reserve or vault accounting based on assumptions about token identity or backing
- wrappers or bridged assets treated as equivalent without proof
**False Positive Checks**:
- collateral acceptance performs identity, valuation, and transferability checks
- reserves are reconciled against actual redeemable assets
**Examples From Hacks CSV**:
- Rhea Lend
- BSC TMM/USDT
- Moonwell Lending
- SolvBTC

### LV-011: Decimal, Unit, Or Rounding Mismatch

**Trigger**: `TOKEN_FLOW | ORACLE | SHARE_ACCOUNTING`
**Summary**: Unit conversion or rounding assumptions create extractable asymmetry.
**Mechanic**: Precision loss, wrong decimals, or directional rounding lets users mint too much, redeem too much, or bypass caps.
**Detection Clues**:
- mixed 6/8/18-decimal assets
- integer division in share math or collateral checks
- cap checks and issuance checks that round in attacker-favorable direction
**False Positive Checks**:
- consistent scaling library used end-to-end
- rounding direction is conservative on every user-favorable branch
**Examples From Hacks CSV**:
- Mobius Token
- Blend Pools V2
- Veil Cash

### LV-012: Reentrancy On State-Dependent Paths

**Trigger**: `TOKEN_FLOW | PRIVILEGED_ROLE`
**Summary**: External calls happen before critical state is finalized or before all coupled state is synchronized.
**Mechanic**: Transfer hooks, callbacks, low-level calls, or token side effects re-enter flows that assume intermediate state is final.
**Detection Clues**:
- external calls before invariant restoration
- token callbacks or hooks on settlement paths
- multi-function coupled state updates across separate calls
**False Positive Checks**:
- reentrancy guard and CEI pattern both hold across all reachable paths
- external token side effects cannot re-enter a dangerous surface
**Examples From Hacks CSV**:
- Arcadia V2
- GMX V1 Perps

### LV-013: Incident Classes Tracked But Not Pattern-Matched In Code

**Trigger**: `ALWAYS`
**Summary**: Some `Protocol Logic` rows in the live hack dataset are still poor direct code vectors and should remain analyst context, not scanner heuristics.
**Mechanic**: Compromised keys, frontend attacks, DNS hijacks, and similar incidents often matter for threat modeling but not for static contract pattern matching.
**Detection Clues**:
- `Admin Key Compromised`
- `Private Key Compromised`
- `Frontend Attack`
- `DNS Hijacking`
**False Positive Checks**:
- if the incident also reveals a reusable code flaw, capture that code flaw separately instead of matching the operational label
**Examples From Hacks CSV**:
- Wasabi Perps
- Ribbon
- Balancer V2
- CoinDash
