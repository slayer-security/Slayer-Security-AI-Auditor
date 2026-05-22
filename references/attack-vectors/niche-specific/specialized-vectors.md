# Niche-Specific Specialized Vectors

Trigger-gated vectors for protocol surfaces that need deeper, more specialized checks.

Use these vectors only when their `Trigger` expression matches the Stage 3 `trigger_flags`.

Supported trigger flags:
- `ORACLE`
- `FLASH_LOAN`
- `CROSS_CHAIN_MSG`
- `STORAGE_LAYOUT`
- `TOKEN_FLOW`
- `MIGRATION`
- `PRIVILEGED_ROLE`
- `SHARE_ACCOUNTING`
- `SIGNATURE_AUTH`

---

### NS-001: Oracle Decimal Drift And Hardcoded Normalizer

**Trigger**: `ORACLE`
**Summary**: Hardcoded decimal scaling or stale assumptions about oracle precision corrupt price-dependent accounting.
**Mechanic**: Protocol multiplies or divides by fixed constants (`1e8`, `1e18`, `1e10`) instead of adapting to the actual oracle `decimals()` and feed semantics.
**Detection Clues**:
- `latestRoundData()` or TWAP calls combined with hardcoded normalization constants
- code paths that mix multiple feeds without explicit unit reconciliation
- stale-answer checks missing or only partially enforced
**False Positive Checks**:
- feed decimals are fetched dynamically and normalized per feed
- wrapper contract guarantees a single canonical precision and every consumer uses it
**Deep Check Focus**: heartbeat/staleness validation, decimal parity, failure-mode fallback behavior

### NS-002: Cross-Chain Message Authentication Drift

**Trigger**: `CROSS_CHAIN_MSG`
**Summary**: Message receivers trust the wrong peer, endpoint, sender, or proof format.
**Mechanic**: Cross-chain receive paths accept messages before fully authenticating origin chain, sender, peer registry, nonce, or message domain.
**Detection Clues**:
- `lzReceive`, `receiveMessage`, `execute`, `process`, `handle`, `prove`, or custom bridge receiver functions
- peer mappings, endpoint setters, or proof validators reachable from upgrade/admin flows
- message payload decoding without tight source validation
**False Positive Checks**:
- peer registry is immutable or tightly access-controlled
- receiver validates chain id, sender, nonce, replay state, and payload structure together
**Deep Check Focus**: peer registry hygiene, replay protection, origin binding, endpoint upgrade safety

### NS-003: Cross-Chain Timing Window Exploit

**Trigger**: `CROSS_CHAIN_MSG`
**Summary**: Delay, ordering, or settlement gaps across chains let attackers act on stale assumptions.
**Mechanic**: Protocol assumes message order or settlement freshness that does not actually hold across asynchronous delivery windows.
**Detection Clues**:
- state transitions that depend on "latest" cross-chain state
- challenge windows, pending queues, delayed mint/burn settlement
- destination-side actions that can be front-run before a source-side message lands
**False Positive Checks**:
- protocol explicitly tolerates reordering and delayed delivery
- messages are idempotent and safe under duplication or out-of-order arrival
**Deep Check Focus**: replay windows, stale cache invalidation, asynchronous arbitrage surfaces

### NS-004: Flash-Loan-Accessible Cached State

**Trigger**: `FLASH_LOAN | TOKEN_FLOW`
**Summary**: Atomic balance distortion breaks assumptions cached within a single transaction.
**Mechanic**: Protocol snapshots balances, reserves, prices, or utilization and reuses them after attacker-controlled token movement in the same transaction.
**Detection Clues**:
- flash-loan callbacks or obvious flash-loan attack surface
- accounting derived from `balanceOf(address(this))`, reserves, or temporary pool ratios
- multi-step flows that compute once and settle later in the same transaction
**False Positive Checks**:
- protocol recomputes critical values after external effects
- snapshot values are invariant to attacker-controlled transfers
**Deep Check Focus**: atomic state reuse, donation compounding, cross-function attack chains

### NS-005: Storage Layout Collision Or Semantic Corruption

**Trigger**: `STORAGE_LAYOUT | MIGRATION`
**Summary**: Upgrade or low-level storage handling corrupts state semantics without obviously reverting.
**Mechanic**: New implementation, delegatecall path, or manual slot logic reinterprets old storage in a way that changes meaning or authorization.
**Detection Clues**:
- UUPS, ERC1967, beacon proxies, storage gaps, inline assembly slot access
- migrations that repack structs, enums, or mappings
- literal slot hashes, `sstore`, `sload`, `delegatecall`
**False Positive Checks**:
- layout diff is documented and storage-safe across versions
- migrations initialize every newly interpreted slot before use
**Deep Check Focus**: proxy slot collisions, struct repacking drift, manual assembly storage reads

### NS-006: Semi-Trusted Role Abuse Of User Preconditions

**Trigger**: `PRIVILEGED_ROLE`
**Summary**: Keeper/operator/governance roles can abuse timing or user-set assumptions without being fully malicious superusers.
**Mechanic**: Semi-trusted actors can grief, selectively execute, censor, route, or reorder actions in ways that violate user expectations or economic fairness.
**Detection Clues**:
- keeper, operator, guardian, relayer, sequencer, auctioneer, offchain signer roles
- delayed execution, batching, liquidation, settlement, or rebalance permissions
- user operations whose safety depends on role honesty
**False Positive Checks**:
- user-provided bounds are enforced onchain at execution time
- role actions are tightly bounded, slashable, or economically neutral
**Deep Check Focus**: griefability, selective execution, keeper advantage, user-side abuse paths

### NS-007: Share Allocation And First-Depositor Skew

**Trigger**: `SHARE_ACCOUNTING | TOKEN_FLOW`
**Summary**: Share minting or receipt token math unfairly favors early, strategic, or donation-assisted actors.
**Mechanic**: Vault-style issuance uses manipulable exchange rates, empty-state math, or stale total asset values.
**Detection Clues**:
- `totalAssets`, `convertToShares`, `previewDeposit`, `previewMint`, receipt-token minting
- empty-vault bootstrap logic, rounding asymmetry, donation-sensitive balances
- mint and burn paths using different price sources
**False Positive Checks**:
- minimum liquidity or dead shares neutralize first-depositor capture
- total assets excludes unsolicited balances or uses internal accounting
**Deep Check Focus**: donation attacks, first-depositor capture, asymmetric rounding, share-price resets

### NS-008: Return-To-Zero Residual Asset Trap

**Trigger**: `TOKEN_FLOW | SHARE_ACCOUNTING`
**Summary**: Protocol appears reset but residual balances or state poison the next lifecycle.
**Mechanic**: After full withdrawal, migration, or emergency unwind, leftover dust/state causes the next depositor or next cycle to inherit bad assumptions.
**Detection Clues**:
- emergency exit, reset, epoch rollover, unwind, or full redemption logic
- zero-state assumptions tied to `totalSupply == 0` or `totalAssets == 0`
- residual asset paths, unclaimed rewards, or stale accounting slots
**False Positive Checks**:
- reset path explicitly clears or quarantines residual state
- new lifecycle derives values from internal accounting, not raw residual balances
**Deep Check Focus**: residual dust, restarted vaults, epoch reset contamination, re-entry after unwind

### NS-009: Signature Domain Drift In Multi-Path Settlement

**Trigger**: `SIGNATURE_AUTH | TOKEN_FLOW`
**Summary**: Orders, RFQs, permits, or typed-data signatures remain valid in contexts they should not.
**Mechanic**: Signature domain, nonce, path, or settlement context is under-bound, allowing replay across routers, chains, markets, or function variants.
**Detection Clues**:
- `permit`, `ecrecover`, `hashTypedDataV4`, `order`, `RFQ`, offchain quote settlement
- signatures that omit destination contract, execution path, fee recipient, or chain context
**False Positive Checks**:
- signed payload binds contract, chain, nonce, path, amount bounds, and recipient
- nonces are consumed exactly once per intended domain
**Deep Check Focus**: replay boundaries, under-specified payloads, partial signature coverage

### NS-010: Missing ERC20 Return Value Handling

**Trigger**: `TOKEN_FLOW`
**Summary**: Protocol assumes every ERC20 returns a boolean on transfer and breaks on tokens like USDT.
**Mechanic**: Raw `transfer` or `transferFrom` calls treat return values as standard even when major tokens return no value.
**Detection Clues**:
- `bool success = token.transfer(...)`
- `bool success = token.transferFrom(...)`
- raw transfer calls without `SafeERC20`
**False Positive Checks**:
- `SafeERC20` wrappers are used consistently
- protocol explicitly supports only a tightly controlled token allowlist
**Deep Check Focus**: missing-return compatibility, revert behavior, inconsistent wrapper usage

### NS-011: Fee-On-Transfer Accounting Drift

**Trigger**: `TOKEN_FLOW | SHARE_ACCOUNTING`
**Summary**: Internal accounting trusts nominal transfer amounts instead of actual received balances.
**Mechanic**: Deposit or accounting logic credits `amount` directly even though the token charges a transfer fee.
**Detection Clues**:
- `balance += amount` immediately after `transferFrom`
- no before/after balance check around incoming transfers
- raw vault balance used as share input without fee-aware handling
**False Positive Checks**:
- actual received amount is computed from balance deltas
- fee-on-transfer tokens are clearly unsupported and gated out
**Deep Check Focus**: deposit balance deltas, insolvency risk, downstream share skew

### NS-012: Rebasing Token Cached Balance Trap

**Trigger**: `TOKEN_FLOW | SHARE_ACCOUNTING`
**Summary**: Cached balances or supply assumptions go stale when token balances change without transfers.
**Mechanic**: Protocol stores token amounts in state and later treats them as equal to live balances for rebasing assets.
**Detection Clues**:
- cached stake or vault balances for rebasing assets
- no share abstraction for rebasing tokens
- use of live `balanceOf` only at deposit time, not settlement time
**False Positive Checks**:
- protocol tracks shares rather than balances
- rebasing assets are explicitly unsupported or wrapped into non-rebasing equivalents
**Deep Check Focus**: reward trapping, stale accounting, empty-vault resets after rebases

### NS-013: Non-Standard Permit Integration Mismatch

**Trigger**: `SIGNATURE_AUTH | TOKEN_FLOW`
**Summary**: Protocol assumes standard EIP-2612 permit semantics and breaks on non-standard tokens like DAI.
**Mechanic**: The signed fields or function signature used by the protocol do not match the target token's permit implementation.
**Detection Clues**:
- direct `permit(...)` integration without token-specific handling
- order/settlement paths assuming a single permit ABI across assets
- no explicit branching for DAI-style permits
**False Positive Checks**:
- protocol only supports tokens with verified standard permit behavior
- token-specific adapters normalize permit handling
**Deep Check Focus**: signature field mismatch, nonce handling, approval flow failure

### NS-014: Chainlink Stale Price Acceptance

**Trigger**: `ORACLE`
**Summary**: Protocol uses Chainlink feed data without a feed-appropriate staleness check.
**Mechanic**: `latestRoundData()` is consumed without validating `updatedAt`, heartbeat assumptions, or answered round freshness.
**Detection Clues**:
- `latestRoundData()` without `updatedAt` check
- generic stale threshold reused across unrelated feeds
- liquidation or collateral logic depending on freshness-sensitive prices
**False Positive Checks**:
- feed-specific heartbeat thresholds are enforced
- stale data paths halt sensitive actions or fall back safely
**Deep Check Focus**: heartbeat handling, stale windows, liquidation safety

### NS-015: Chainlink L2 Sequencer Recovery Window

**Trigger**: `ORACLE`
**Summary**: L2 protocols use Chainlink prices without sequencer uptime and grace-period checks.
**Mechanic**: The protocol trusts oracle values immediately after sequencer recovery, enabling unfair post-downtime liquidations or arbitrage.
**Detection Clues**:
- Arbitrum/Optimism/Base deployment with Chainlink price feeds
- no sequencer uptime feed check
- no grace period after sequencer restart
**False Positive Checks**:
- protocol is not on an affected L2
- uptime feed and recovery delay are enforced before price-sensitive actions
**Deep Check Focus**: sequencer downtime behavior, restart grace windows, user defense ability
