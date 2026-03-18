# ERC20 Token Integration Variants

> **Source**: Based on [d-xo/weird-erc20](https://github.com/d-xo/weird-erc20) - the definitive reference for non-standard ERC20 behaviors.

This file documents **24 critical ERC20 token variants** that break standard assumptions. These patterns catch **integration bugs** where protocols claim "supports all ERC20 tokens" but make assumptions that don't hold for all tokens.

**Historical Impact**: These variant issues have caused:
- imBTC/Lendf.me: $25M drained (reentrancy via ERC777 callbacks)
- Balancer: $500k loss (fee-on-transfer tokens)
- Uniswap V4: Critical vulnerability on Celo (native ERC20 double-spend)
- Multiple protocols: Broken permit functionality (DAI)
- Bridge contracts: Trapped rebasing rewards (stETH)

---

## 1. Missing Return Values (USDT, BNB, OMG)

**D:** (Description)
Tokens like USDT, BNB, and OMG do not return a boolean value from `transfer()` and `transferFrom()` functions. They either return `void` or omit the return statement entirely. Solidity contracts compiled with version 0.4.22+ will revert when calling these tokens if the code expects a boolean return value.

**Affected Tokens**:
- USDT (Tether): Most widely used stablecoin
- BNB (Binance Coin)
- OMG (OmiseGO)
- 130+ other tokens

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Expects boolean return
function deposit(IERC20 token, uint256 amount) external {
    bool success = token.transferFrom(msg.sender, address(this), amount);
    require(success, "Transfer failed");
}
```

**Impact**:
- All transactions with these tokens will revert
- Protocol becomes unusable for major tokens like USDT
- Severity: HIGH (breaks core functionality)

**FP:** (False Positive Prevention)
- ✅ Safe if using OpenZeppelin's `SafeERC20.safeTransfer()` or `SafeERC20.safeTransferFrom()`
- ✅ Safe if using low-level call with `abi.encodeWithSelector`
- ✅ Safe if contract only supports specific tokens (check README for token whitelist)
- ❌ Vulnerable if raw `transfer()` or `transferFrom()` calls expect boolean return

**Detection**:
```solidity
// Pattern to detect:
bool success = token.transfer(...)
bool success = token.transferFrom(...)

// NOT using SafeERC20
```

**Solodit Query**:
```json
{
  "keywords": ["USDT", "transfer", "return value"],
  "tags": ["erc20", "token", "integration"],
  "severity": ["High", "Medium"]
}
```

**Fix**:
```solidity
// SAFE: Using SafeERC20
using SafeERC20 for IERC20;

function deposit(IERC20 token, uint256 amount) external {
    token.safeTransferFrom(msg.sender, address(this), amount);
    // No boolean return needed - safeTransferFrom reverts on failure
}
```

---

## 2. Fee-on-Transfer / Deflationary Tokens (STA, PAXG)

**D:** (Description)
Some tokens deduct a fee during transfers, meaning the recipient receives less than the sent amount. If a protocol tracks balances using the `amount` parameter instead of checking actual balance changes, accounting becomes corrupted. Attackers can exploit this to drain contracts.

**Affected Tokens**:
- STA (Statera): 1% burn on transfer
- PAXG (Paxos Gold): Variable fee
- Deflationary tokens: Various percentages

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Assumes amount sent == amount received
function deposit(IERC20 token, uint256 amount) external {
    token.transferFrom(msg.sender, address(this), amount);
    userBalance[msg.sender] += amount;  // WRONG! Actual received < amount
}

function withdraw(uint256 amount) external {
    userBalance[msg.sender] -= amount;
    token.transfer(msg.sender, amount);  // Can drain more than deposited
}
```

**Real Exploit**: Balancer ($500k - June 2023)
- STA token has 1% fee on transfer
- Balancer's AMM didn't account for fee
- Attacker executed 24 consecutive swaps
- Each swap took 1% fee but pool reserves didn't reflect this
- Protocol released more collateral than actually gained
- Total loss: $500k across WETH, WBTC, LINK, SNX

**Impact**:
- Accounting corruption (tracked balance > actual balance)
- Drain attack: Users can withdraw more than deposited
- Pool insolvency
- Severity: CRITICAL (direct fund loss)

**FP:** (False Positive Prevention)
- ✅ Safe if code checks `balanceOf()` before and after transfer
- ✅ Safe if protocol explicitly documents "fee-on-transfer tokens not supported"
- ✅ Safe if token whitelist excludes fee-on-transfer tokens
- ❌ Vulnerable if balance tracking uses `amount` parameter directly

**Detection**:
```solidity
// Pattern to detect:
token.transferFrom(user, address(this), amount);
balance[user] += amount;  // RED FLAG: using amount, not actual received

// Missing pattern:
uint256 balanceBefore = token.balanceOf(address(this));
token.transferFrom(...);
uint256 balanceAfter = token.balanceOf(address(this));
uint256 actualReceived = balanceAfter - balanceBefore;
```

**Solodit Query**:
```json
{
  "keywords": ["fee on transfer", "deflationary token", "balance accounting"],
  "tags": ["erc20", "accounting"],
  "severity": ["Critical", "High"]
}
```

**Fix**:
```solidity
// SAFE: Check actual balance change
function deposit(IERC20 token, uint256 amount) external {
    uint256 balanceBefore = token.balanceOf(address(this));
    token.transferFrom(msg.sender, address(this), amount);
    uint256 balanceAfter = token.balanceOf(address(this));
    uint256 actualReceived = balanceAfter - balanceBefore;

    userBalance[msg.sender] += actualReceived;  // Correct accounting
}
```

---

## 3. Rebasing Tokens (stETH, AMPL, aTokens)

**D:** (Description)
Rebasing tokens modify all holder balances automatically without transfer events. Examples: stETH (Lido staked ETH) accrues staking rewards by rebasing balances upward; AMPL (Ampleforth) rebases based on price oracle. If a protocol caches balances or uses them in calculations, rebases cause accounting corruption.

**Affected Tokens**:
- stETH (Lido): Rebases upward (staking rewards)
- aTokens (Aave): Rebases upward (lending interest)
- AMPL (Ampleforth): Rebases up/down (price targeting)

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Cached balance becomes stale after rebase
mapping(address => uint256) public stakedAmount;

function stake(IERC20 token, uint256 amount) external {
    token.transferFrom(msg.sender, address(this), amount);
    stakedAmount[msg.sender] += amount;  // Cached
}

function unstake() external {
    uint256 amount = stakedAmount[msg.sender];
    token.transfer(msg.sender, amount);  // WRONG: Actual balance may be higher due to rebase
}
```

**Impact**:
- Liquidity providers lose rebasing rewards (stuck in pools/bridges)
- Accounting mismatch (cached balance ≠ actual balance)
- Users can't access their rebased rewards
- Severity: HIGH (loss of rewards, user funds stuck)

**Real Example**: stETH Integration Issues
- Uniswap V2/V3: stETH rebases break constant product formula
- Bridges: Rebasing rewards trapped on source chain
- Lending protocols: Cached collateral values don't reflect rebases
- Lido's official guidance: Use wstETH (wrapped, non-rebasing) instead

**FP:** (False Positive Prevention)
- ✅ Safe if protocol uses shares-based accounting (like Lido's wstETH)
- ✅ Safe if protocol explicitly documents "rebasing tokens not supported"
- ✅ Safe if code calls `balanceOf()` real-time instead of caching
- ✅ Safe if tracking "shares" instead of "balances"
- ❌ Vulnerable if balance is cached in state variable
- ❌ Vulnerable if AMM formula assumes constant balances

**Detection**:
```solidity
// Pattern to detect:
mapping(address => uint256) public stakedBalance;  // Cached balance - risky for rebasing
stakedBalance[user] = amount;  // RED FLAG

// vs SAFE pattern:
uint256 balance = token.balanceOf(address(this));  // Real-time query
```

**Solodit Query**:
```json
{
  "keywords": ["rebasing token", "stETH", "AMPL", "balance accounting"],
  "tags": ["erc20", "rebasing"],
  "severity": ["High", "Medium"]
}
```

**Fix**:
```solidity
// Option 1: Use wrapped tokens (e.g., wstETH instead of stETH)
// Option 2: Track shares, not balances
mapping(address => uint256) public shares;

function stake(IERC20 token, uint256 amount) external {
    uint256 shareAmount = convertToShares(amount);  // Convert to shares
    token.transferFrom(msg.sender, address(this), amount);
    shares[msg.sender] += shareAmount;
}

function unstake() external {
    uint256 shareAmount = shares[msg.sender];
    uint256 tokenAmount = convertToTokens(shareAmount);  // Convert back at current rate
    token.transfer(msg.sender, tokenAmount);  // Includes rebased rewards
}
```

---

## 4. Non-Standard Permit Signatures (DAI, RAI, GLM, STAKE)

**D:** (Description)
EIP-2612 standardizes the `permit()` function signature, but several major tokens implemented permit BEFORE the standard was finalized, using different parameters. DAI's permit is the most common variant. Protocols assuming standard EIP-2612 will always revert when used with these tokens.

**Affected Tokens**:
- DAI (MakerDAO): Most critical (widely used stablecoin)
- RAI (Reflexer): Different nonce system
- GLM (Golem)
- STAKE (xDai)

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Assumes standard EIP-2612 permit
interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

function depositWithPermit(...) external {
    IERC20Permit(token).permit(owner, spender, value, deadline, v, r, s);
    // ^^^ This ALWAYS reverts for DAI
    token.transferFrom(owner, address(this), amount);
}
```

**DAI's Actual Signature**:
```solidity
// DAI uses different parameter names and types
function permit(
    address holder,     // NOT "owner"
    address spender,
    uint256 nonce,      // NOT "value"
    uint256 expiry,     // NOT "deadline"
    bool allowed,       // NOT uint256 - this is critical!
    uint8 v,
    bytes32 r,
    bytes32 s
) external;
```

**Impact**:
- All permit transactions with DAI revert (100% failure rate)
- Gas-less approval feature completely broken for DAI
- User experience severely degraded
- Severity: HIGH (breaks advertised functionality for major stablecoin)

**FP:** (False Positive Prevention)
- ✅ Safe if protocol has token-specific permit adapters
- ✅ Safe if DAI not in supported token list
- ✅ Safe if using permit2 (Uniswap's universal permit)
- ❌ Vulnerable if single permit interface used + DAI in scope

**Detection**:
```solidity
// Pattern to detect:
interface IERC20Permit {
    function permit(address owner, address spender, uint256 value, ...) external;
}

// + Protocol claims support for DAI or "all ERC20 tokens"
```

**Solodit Query**:
```json
{
  "keywords": ["DAI permit", "permit signature", "EIP-2612"],
  "tags": ["erc20", "permit", "signature"],
  "severity": ["High", "Medium"]
}
```

**Fix**:
```solidity
// Option 1: Token-specific adapters
interface IDAI {
    function permit(address holder, address spender, uint256 nonce, uint256 expiry, bool allowed, uint8 v, bytes32 r, bytes32 s) external;
}

function depositWithPermit(address token, ...) external {
    if (token == DAI_ADDRESS) {
        IDAI(token).permit(holder, spender, nonce, expiry, true, v, r, s);
    } else {
        IERC20Permit(token).permit(owner, spender, value, deadline, v, r, s);
    }
    token.transferFrom(...);
}

// Option 2: Use Uniswap Permit2 (universal permit contract)
```

---

## 5. Pausable Tokens (USDC, USDT)

**D:** (Description)
Tokens like USDC and USDT can be paused by their admin/governance, causing all transfers to revert. If a protocol's critical operations depend on these tokens and they get paused, the entire protocol can be bricked. Emergency withdrawals may fail, liquidations may fail, causing cascading failures.

**Affected Tokens**:
- USDC (Circle): Can be paused by Circle
- USDT (Tether): Can be paused by Tether
- Other centralized stablecoins

**Vulnerability Pattern**:
```solidity
// VULNERABLE: No handling for paused token state
function liquidate(address user) external {
    uint256 debtAmount = userDebt[user];
    usdc.transferFrom(msg.sender, address(this), debtAmount);  // REVERTS if USDC paused
    // Liquidation fails, user's bad debt accumulates
}

function emergencyWithdraw() external {
    uint256 amount = userBalance[msg.sender];
    usdc.transfer(msg.sender, amount);  // REVERTS if USDC paused
    // User funds stuck
}
```

**Impact**:
- Protocol bricked during pause period
- Liquidations fail → bad debt accumulates
- Emergency withdrawals fail → user funds stuck
- Cascading failures in dependent protocols
- Severity: HIGH (protocol availability + potential insolvency)

**FP:** (False Positive Prevention)
- ✅ Safe if protocol has pause-aware emergency mechanisms
- ✅ Safe if alternative withdrawal paths exist
- ✅ Safe if only non-critical operations use pausable tokens
- ❌ Vulnerable if critical paths (liquidations, emergency exits) depend on pausable tokens

**Detection**:
```solidity
// Pattern to detect:
- Critical functions (liquidate, emergencyWithdraw, etc.)
- Calling transferFrom/transfer on USDC/USDT
- No try/catch or alternative execution path
```

**Solodit Query**:
```json
{
  "keywords": ["pausable token", "USDC pause", "emergency withdrawal"],
  "tags": ["erc20", "centralization"],
  "severity": ["High", "Medium"]
}
```

**Fix**:
```solidity
// Option 1: Pause-aware logic with alternatives
function emergencyWithdraw() external {
    uint256 amount = userBalance[msg.sender];

    try usdc.transfer(msg.sender, amount) {
        userBalance[msg.sender] = 0;
    } catch {
        // USDC paused - allow internal balance transfer
        pendingWithdrawals[msg.sender] += amount;
        userBalance[msg.sender] = 0;
        emit WithdrawalPending(msg.sender, amount);
    }
}

// Option 2: Multi-token collateral (don't rely on single pausable token)
```

---

## 6. Blacklist Functionality (USDC, USDT)

**D:** (Description)
USDC and USDT can blacklist specific addresses, making all transfers to/from those addresses revert. If a protocol's smart contract address gets blacklisted (e.g., sanctioned by OFAC), the entire protocol becomes bricked. All user funds may become inaccessible.

**Affected Tokens**:
- USDC (Circle): Address blacklist for sanctions compliance
- USDT (Tether): Address blacklist
- Other centralized stablecoins

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Protocol contract holds user funds in USDC
contract Vault {
    mapping(address => uint256) public usdcBalance;

    function deposit(uint256 amount) external {
        usdc.transferFrom(msg.sender, address(this), amount);  // REVERTS if address(this) blacklisted
        usdcBalance[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        usdc.transfer(msg.sender, amount);  // REVERTS if address(this) OR msg.sender blacklisted
        usdcBalance[msg.sender] -= amount;
    }
}
```

**Impact**:
- If `address(this)` blacklisted → entire protocol bricked
- If user address blacklisted → user can't withdraw their funds
- Mass user fund lock-in if protocol contract blacklisted
- Severity: CRITICAL (complete protocol failure + fund loss)

**Real Scenario**: Tornado Cash (2022)
- OFAC sanctioned Tornado Cash contract addresses
- USDC/USDT blacklisted these addresses
- All user funds in those contracts became inaccessible
- Users with clean funds couldn't withdraw

**FP:** (False Positive Prevention)
- ✅ Safe if using decentralized stablecoins (DAI, LUSD)
- ✅ Safe if multi-token support allows switching away from blacklisted token
- ✅ Safe if non-custodial design (users hold tokens, not contract)
- ❌ Vulnerable if protocol contract custodies USDC/USDT
- ❌ Vulnerable if no alternative withdrawal mechanism

**Detection**:
```solidity
// Pattern to detect:
- Protocol holds user USDC/USDT balances
- No alternative withdrawal mechanism if blacklist occurs
- Centralized/custodial design pattern
```

**Solodit Query**:
```json
{
  "keywords": ["blacklist", "USDC blacklist", "OFAC sanctions"],
  "tags": ["erc20", "centralization", "censorship"],
  "severity": ["Critical", "High"]
}
```

**Fix**:
```solidity
// Option 1: Non-custodial design (don't hold user funds)
// Users approve contract but keep tokens in their wallet

// Option 2: Multi-token support with emergency migration
function emergencyTokenSwitch(address newToken) external onlyGovernance {
    // Allow users to switch collateral to non-blacklisted token
    allowedTokens[newToken] = true;
    emit EmergencyTokenAdded(newToken);
}

// Option 3: Distribute risk across multiple stablecoins
// Don't put all eggs in USDC/USDT basket
```

---

## 7. Reentrant Calls (ERC777, imBTC)

**D:** (Description)
ERC777 tokens and some ERC20 tokens allow callbacks during transfer operations. The token calls a hook (like `tokensReceived`) on the recipient BEFORE updating balances, enabling reentrancy attacks. This has caused multiple real-world exploits including the imBTC/Lendf.me hack.

**Affected Tokens**:
- ERC777 tokens (all of them)
- imBTC (wrapped BTC with hooks)
- Tokens with transfer callbacks

**Real Exploits**:
- imBTC/Lendf.me: $25M drained via reentrancy
- Uniswap V1: ERC777 reentrancy issues

**Vulnerability Pattern**:
```solidity
// VULNERABLE: State updated after external call
function deposit(address token, uint256 amount) external {
    IERC20(token).transferFrom(msg.sender, address(this), amount); // Callback here!
    balances[msg.sender] += amount; // Too late - attacker already re-entered
}
```

**Impact**:
- Complete fund drain via reentrancy
- Severity: CRITICAL

**FP:** (False Positive Prevention)
- ✅ Safe if nonReentrant modifier used
- ✅ Safe if Checks-Effects-Interactions pattern followed
- ✅ Safe if protocol explicitly excludes ERC777
- ❌ Vulnerable if state updated after transferFrom

**Fix**:
```solidity
// SAFE: CEI pattern + nonReentrant
function deposit(address token, uint256 amount) external nonReentrant {
    balances[msg.sender] += amount; // Effects FIRST
    IERC20(token).transferFrom(msg.sender, address(this), amount); // Interaction LAST
}
```

---

## 8. Upgradeable Tokens (USDC, USDT)

**D:** (Description)
Many major tokens use proxy patterns and can be upgraded at any time. Token behavior can change without notice - a safe integration today may become exploitable after an upgrade.

**Affected Tokens**:
- USDC (Circle): Upgradeable proxy
- USDT (Tether): Upgradeable proxy
- Most centralized stablecoins

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Hardcoded assumptions about token behavior
function swap(address token, uint256 amount) external {
    // What if token adds fees after upgrade?
    // What if token changes return value behavior?
    token.transfer(recipient, amount);
}
```

**Impact**:
- Future exploits after token upgrade
- Silent behavior changes break protocols
- Severity: MEDIUM (future risk)

**FP:** (False Positive Prevention)
- ✅ Safe if protocol monitors token upgrades
- ✅ Safe if defensive coding used (SafeERC20, balance checks)
- ❌ Vulnerable if hardcoded assumptions about token behavior

---

## 9. Flash Mintable Tokens (DAI)

**D:** (Description)
Some tokens allow flash minting (minting tokens temporarily within a transaction). This can be used to manipulate governance votes, liquidity pool ratios, or any calculation based on totalSupply or token balances.

**Affected Tokens**:
- DAI: Has flash mint functionality
- Custom flash-mint tokens

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Uses totalSupply for calculations
function getShareValue() external view returns (uint256) {
    return totalAssets / token.totalSupply(); // Can be manipulated via flash mint
}
```

**Impact**:
- Governance manipulation
- Oracle/price manipulation
- Severity: HIGH

**FP:** (False Positive Prevention)
- ✅ Safe if not using totalSupply for critical calculations
- ✅ Safe if flash loan protection exists
- ❌ Vulnerable if totalSupply used in same-block calculations

---

## 10. Approval Race Condition Protection (USDT, KNC)

**D:** (Description)
Some tokens prevent the approval race condition by reverting if you try to approve a non-zero amount when a non-zero approval already exists. You must first approve to 0, then to the new amount.

**Affected Tokens**:
- USDT (Tether)
- KNC (Kyber Network)

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Direct approval without zeroing first
function approveMax(address token, address spender) external {
    IERC20(token).approve(spender, type(uint256).max); // REVERTS if existing approval > 0
}
```

**Impact**:
- Approve transactions revert unexpectedly
- Breaks integrations with these tokens
- Severity: MEDIUM

**FP:** (False Positive Prevention)
- ✅ Safe if using SafeERC20.forceApprove() (OZ 4.9+)
- ✅ Safe if approving to 0 first
- ❌ Vulnerable if direct approve() with non-zero amount

**Fix**:
```solidity
// SAFE: Zero first, then approve
IERC20(token).approve(spender, 0);
IERC20(token).approve(spender, amount);

// Or use SafeERC20.forceApprove()
```

---

## 11. Revert on Zero Value Transfers (LEND)

**D:** (Description)
Some tokens revert when transferring zero amounts. Protocols that transfer calculated amounts may fail when the amount rounds down to zero.

**Affected Tokens**:
- LEND (Aave V1 token)
- Various others

**Vulnerability Pattern**:
```solidity
// VULNERABLE: May transfer 0 after calculation
function distributeRewards(address[] users) external {
    for (uint i = 0; i < users.length; i++) {
        uint256 reward = calculateReward(users[i]); // May be 0
        token.transfer(users[i], reward); // REVERTS if reward == 0
    }
}
```

**Impact**:
- Batch operations fail entirely
- Severity: MEDIUM

**FP:** (False Positive Prevention)
- ✅ Safe if zero-amount check before transfer
- ❌ Vulnerable if transferring calculated amounts without check

**Fix**:
```solidity
if (reward > 0) {
    token.transfer(users[i], reward);
}
```

---

## 12. Low Decimals (USDC, GUSD)

**D:** (Description)
Not all tokens use 18 decimals. USDC uses 6, Gemini USD uses 2. Calculations assuming 18 decimals cause massive precision loss or overflow.

**Affected Tokens**:
- USDC: 6 decimals
- USDT: 6 decimals
- GUSD: 2 decimals
- WBTC: 8 decimals

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Assumes 18 decimals
function calculatePrice(address token, uint256 amount) external view returns (uint256) {
    return amount * 1e18 / oracle.getPrice(token); // Wrong for non-18 decimal tokens
}
```

**Impact**:
- Massive calculation errors (up to 10^12 difference)
- Price manipulation
- Severity: HIGH

**FP:** (False Positive Prevention)
- ✅ Safe if reading decimals() dynamically
- ✅ Safe if explicit decimal handling
- ❌ Vulnerable if hardcoded 1e18 assumptions

**Fix**:
```solidity
uint8 decimals = IERC20Metadata(token).decimals();
uint256 normalized = amount * 1e18 / (10 ** decimals);
```

---

## 13. High Decimals (YAM-V2)

**D:** (Description)
Some tokens have more than 18 decimals (e.g., YAM-V2 with 24 decimals). Calculations with these tokens can overflow.

**Affected Tokens**:
- YAM-V2: 24 decimals

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Overflow with high decimals
function calculateValue(uint256 amount) external view returns (uint256) {
    return amount * price; // May overflow with 24-decimal token
}
```

**Impact**:
- Arithmetic overflow
- Severity: HIGH

---

## 14. Multiple Token Addresses (Proxied Tokens)

**D:** (Description)
Some tokens are accessible via multiple contract addresses (proxies pointing to same implementation). A token whitelist checking addresses may be bypassed.

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Whitelist check bypassed via alternate address
mapping(address => bool) public allowedTokens;

function deposit(address token, uint256 amount) external {
    require(allowedTokens[token], "Token not allowed");
    // Attacker uses alternate token address not in whitelist
}
```

**Impact**:
- Whitelist bypass
- Severity: MEDIUM

---

## 15. No Revert on Failure (ZRX, EURS)

**D:** (Description)
Some tokens return `false` instead of reverting on failure. If the return value isn't checked, transfers silently fail.

**Affected Tokens**:
- ZRX (0x)
- EURS (Stasis Euro)

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Return value not checked
function withdraw(uint256 amount) external {
    token.transfer(msg.sender, amount); // Returns false on failure, doesn't revert!
    balances[msg.sender] -= amount; // State updated even though transfer failed
}
```

**Impact**:
- Silent transfer failures
- Fund loss
- Severity: HIGH

**FP:** (False Positive Prevention)
- ✅ Safe if using SafeERC20.safeTransfer()
- ❌ Vulnerable if return value not checked

---

## 16. Revert on Large Approvals (UNI, COMP)

**D:** (Description)
Some tokens use uint96 internally and revert if approval/transfer amount exceeds uint96.max. Approving type(uint256).max (common pattern) may revert.

**Affected Tokens**:
- UNI (Uniswap): uint96 internally
- COMP (Compound): uint96 internally

**Vulnerability Pattern**:
```solidity
// VULNERABLE: max approval pattern fails
token.approve(spender, type(uint256).max); // REVERTS for UNI/COMP
```

**Impact**:
- Common approval pattern fails
- Severity: MEDIUM

**Fix**:
```solidity
// Safe: Use uint96 max for these tokens
token.approve(spender, type(uint96).max);
```

---

## 17. Non-Standard Permit (DAI, RAI, GLM, etc.)

**D:** (Description)
Multiple tokens have non-EIP-2612 permit implementations. Some may not revert on invalid signatures, causing "phantom permit" where permit() succeeds but approval isn't granted.

**Affected Tokens**:
- DAI, RAI, GLM, STAKE, CHAI, HAKKA, USDFL, HNY

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Assumes permit reverts on failure
function depositWithPermit(...) external {
    try IERC20Permit(token).permit(...) {} catch {}
    // ^^ Permit may "succeed" without granting approval
    token.transferFrom(owner, address(this), amount); // Fails unexpectedly
}
```

**Impact**:
- Phantom approvals
- Unexpected failures
- Severity: MEDIUM

---

## 18. Revert on Transfer to Zero Address

**D:** (Description)
OpenZeppelin tokens revert on transfer to address(0). Burning by sending to zero address doesn't work.

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Burning via zero address
function burn(uint256 amount) external {
    token.transfer(address(0), amount); // REVERTS on OZ tokens
}
```

**Impact**:
- Burn functionality broken
- Severity: LOW

---

## 19. Non-String Metadata (MKR)

**D:** (Description)
Some tokens return `bytes32` instead of `string` for name() and symbol(). Calling as string causes unexpected behavior.

**Affected Tokens**:
- MKR (MakerDAO)

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Assumes string return
string memory name = IERC20Metadata(token).name(); // Fails for MKR
```

---

## 20. Code Injection via Token Name

**D:** (Description)
Malicious tokens can include JavaScript in their name/symbol. Front-ends displaying this without sanitization are vulnerable to XSS.

**Historical Example**: EtherDelta XSS exploit

**Vulnerability Pattern**:
```javascript
// VULNERABLE: Frontend displaying unsanitized token name
element.innerHTML = token.name; // XSS if name contains <script>
```

**Impact**:
- Frontend XSS attacks
- Severity: HIGH (for frontends)

---

## 21. Transfer Less Than Amount (cUSDCv3)

**D:** (Description)
Some tokens transfer only the user's balance when `amount == type(uint256).max`, not the full max value.

**Affected Tokens**:
- cUSDCv3 (Compound V3)

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Assumes max transfer gives max amount
token.transferFrom(user, address(this), type(uint256).max);
// Actually only transfers user's balance
```

---

## 22. ERC-20 Native Currency Wrappers (CELO, POL)

**D:** (Description)
Some chains represent native currency as ERC20. The same value can exist as both native and ERC20, enabling double-spending if a protocol accepts both forms without checking.

**Vulnerable Chains**:
- Celo (CELO token)
- Polygon (POL token)
- zkSync Era (ETH as ERC20)

**Real Exploit**: Uniswap V4 critical vulnerability on Celo (2024)

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Accepts both native and ERC20 form
function deposit(address token, uint256 amount) external payable {
    if (msg.value > 0) {
        // Accept native
    } else {
        token.transferFrom(msg.sender, address(this), amount);
    }
    // Double-spend: use same value twice!
}
```

**Impact**:
- Double-spending of native currency
- Severity: CRITICAL

---

## 23. Approval to Zero Address Reverts

**D:** (Description)
OpenZeppelin tokens revert when approving to address(0).

**Vulnerability Pattern**:
```solidity
// VULNERABLE: May pass address(0) from calculation
address spender = getSpender(); // May return address(0)
token.approve(spender, amount); // REVERTS if spender == address(0)
```

---

## 24. transferFrom Self Inconsistency

**D:** (Description)
When `msg.sender == from` in transferFrom, some tokens (DSToken) don't decrease allowance while others (OpenZeppelin) do. This causes inconsistent behavior.

**Vulnerability Pattern**:
```solidity
// INCONSISTENT: Allowance handling varies
token.approve(address(this), 100);
token.transferFrom(address(this), recipient, 50);
// DSToken: allowance still 100
// OpenZeppelin: allowance now 50
```

---

## Integration Checklist (All 24 Patterns)

When integrating ERC20 tokens, verify the following:

### Transfer Safety:
- [ ] Using `SafeERC20` for all transfers (handles #1 Missing Return, #15 No Revert)
- [ ] Using `nonReentrant` modifier (handles #7 Reentrant Calls)
- [ ] Balance diff verification for deposits (handles #2 Fee-on-Transfer)
- [ ] Zero amount checks before transfer (handles #11 Revert on Zero)
- [ ] Proper decimal handling with `decimals()` (handles #12 Low, #13 High Decimals)

### Approval Safety:
- [ ] Approve to 0 before new approval OR use `forceApprove()` (handles #10 Race Protection)
- [ ] Use safe max values for UNI/COMP (handles #16 Large Approvals)
- [ ] Validate spender != address(0) (handles #23 Zero Address Reverts)

### Accounting:
- [ ] Shares-based accounting for yield tokens (handles #3 Rebasing)
- [ ] Don't rely on `totalSupply` for same-block calculations (handles #9 Flash Mint)
- [ ] Handle `type(uint256).max` transfer special cases (handles #21 Transfer Less)

### Permit:
- [ ] Token-specific permit adapters (handles #4, #17 Non-Standard Permit)
- [ ] Verify permit actually granted approval (handles #17 Phantom Permit)

### Centralization Risks:
- [ ] Emergency paths not dependent on pausable tokens (handles #5 Pausable)
- [ ] Multi-token support or non-custodial design (handles #6 Blacklist)
- [ ] Monitor for token upgrades (handles #8 Upgradeable)

### Multi-Chain:
- [ ] Prevent double-spend with native ERC20 wrappers (handles #22 CELO/POL/zkSync)
- [ ] Handle multiple token addresses (handles #14 Proxied Tokens)

### Frontend:
- [ ] Sanitize token name/symbol before display (handles #20 XSS Injection)
- [ ] Handle bytes32 metadata (handles #19 MKR)

### Documentation:
- [ ] Explicitly list supported tokens (NEVER claim "all ERC20")
- [ ] Document which variants are NOT supported
- [ ] Warn users about centralized stablecoin risks

### Testing:
- [ ] Test with USDT (no return value, approval race)
- [ ] Test with fee-on-transfer mock
- [ ] Test with DAI permit
- [ ] Test with low decimal token (USDC - 6 decimals)
- [ ] Test with UNI/COMP (uint96 limits)
- [ ] Test emergency scenarios (pause, blacklist)

---

## Quick Reference: Token → Issues

| Token | Issues |
|-------|--------|
| USDT | #1 Missing Return, #5 Pausable, #6 Blacklist, #8 Upgradeable, #10 Race Protection |
| USDC | #5 Pausable, #6 Blacklist, #8 Upgradeable, #12 Low Decimals (6) |
| DAI | #4 Non-Standard Permit, #9 Flash Mintable |
| UNI/COMP | #16 Revert on Large Approvals (uint96) |
| stETH/AMPL | #3 Rebasing |
| ERC777/imBTC | #7 Reentrant Calls |
| MKR | #19 bytes32 Metadata |
| CELO/POL | #22 Native ERC20 Double-Spend |
| ZRX/EURS | #15 No Revert on Failure |
| LEND | #11 Revert on Zero Transfer |

---

## References

- [Weird ERC20 Tokens](https://github.com/d-xo/weird-erc20) - Primary source for all 24 patterns
- [imBTC/Lendf.me Exploit Analysis](https://peckshield.medium.com/uniswap-lendf-me-hacks-root-cause-and-loss-analysis-50f3263dcc09)
- [Balancer STA Exploit](https://www.coindesk.com/markets/2020/06/29/hacker-drains-500k-from-defi-liquidity-provider-balancer)
- [Uniswap V4 Celo Vulnerability](https://blog.uniswap.org/)
- [Missing Return Value Bug](https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca)
- [Lido stETH Integration Guide](https://docs.lido.fi/guides/steth-integration-guide/)
- [Safe ERC20 by OpenZeppelin](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#SafeERC20)
