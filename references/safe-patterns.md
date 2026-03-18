# Safe Code Patterns - False Positive Prevention

This file documents code patterns that **look vulnerable but are actually SAFE** due to mitigations. Use this to prevent false positives by recognizing when "dangerous patterns" are properly protected.

**Purpose**: Train the AI to understand WHEN vulnerable patterns are acceptable.

---

## 1. Reentrancy with Protection

### Pattern: External Call with `nonReentrant` Modifier

**Looks Vulnerable**:
```solidity
function withdraw(uint256 amount) external nonReentrant {
    require(balances[msg.sender] >= amount, "Insufficient balance");
    balances[msg.sender] -= amount;

    // External call BEFORE state update - looks like reentrancy
    payable(msg.sender).transfer(amount);
}
```

**Why It's SAFE**:
- `nonReentrant` modifier (OpenZeppelin ReentrancyGuard) prevents reentrant calls
- Even though external call comes before some state updates, the guard blocks reentrancy

**Detection**:
```
IF function has external call
AND has `nonReentrant` modifier
THEN reentrancy is SAFE (not a finding)
```

**Common Modifiers That Make Reentrancy Safe**:
- `nonReentrant` (OpenZeppelin)
- `lock` / `unlock` (custom mutex patterns)
- `noReenter` (various naming conventions)

---

### Pattern: Checks-Effects-Interactions (CEI)

**Looks Vulnerable** (but isn't):
```solidity
function claim() external {
    uint256 reward = calculateReward(msg.sender);
    require(reward > 0, "No rewards");

    // State update BEFORE external call = CEI pattern
    lastClaim[msg.sender] = block.timestamp;
    claimedRewards[msg.sender] += reward;

    // External call LAST = SAFE
    rewardToken.transfer(msg.sender, reward);
}
```

**Why It's SAFE**:
- Follows Checks-Effects-Interactions pattern
- All state changes happen before external call
- Reentrancy would see updated state (no double-claim possible)

**Detection**:
```
IF all state writes occur BEFORE first external call
THEN reentrancy risk is mitigated (CEI pattern)
```

---

## 2. ERC20 Transfers with SafeERC20

### Pattern: SafeERC20 Wrappers

**Looks Vulnerable**:
```solidity
using SafeERC20 for IERC20;

function deposit(IERC20 token, uint256 amount) external {
    // Looks like raw transfer - but it's using SafeERC20
    token.safeTransferFrom(msg.sender, address(this), amount);
    balances[msg.sender] += amount;
}
```

**Why It's SAFE**:
- `SafeERC20` library handles:
  - Tokens with no return value (USDT)
  - Tokens that return false on failure
  - Proper revert on failure
- The `using SafeERC20 for IERC20` directive applies safety wrappers

**Detection**:
```
IF file has `using SafeERC20 for IERC20`
AND using `.safeTransfer()` or `.safeTransferFrom()`
THEN missing return value issue is SAFE (not a finding)
```

**Safe Methods**:
- `safeTransfer()`
- `safeTransferFrom()`
- `safeApprove()`
- `safeIncreaseAllowance()`
- `safeDecreaseAllowance()`

---

## 3. Oracle Staleness with Proper Checks

### Pattern: Comprehensive Oracle Validation

**Looks Vulnerable** (but isn't):
```solidity
function getPrice() public view returns (uint256) {
    (
        uint80 roundId,
        int256 price,
        ,
        uint256 updatedAt,
        uint80 answeredInRound
    ) = priceFeed.latestRoundData();

    require(price > 0, "Invalid price");
    require(answeredInRound >= roundId, "Stale price");
    require(block.timestamp - updatedAt <= STALENESS_THRESHOLD, "Price too old");

    return uint256(price);
}
```

**Why It's SAFE**:
- Checks `answeredInRound >= roundId` (round completion)
- Checks `updatedAt` against staleness threshold
- Checks `price > 0` (no negative/zero prices)
- All three checks together = comprehensive validation

**Detection**:
```
IF oracle call includes:
  - `answeredInRound >= roundId` check
  - `updatedAt` staleness check
  - `price > 0` check
THEN oracle staleness is properly handled (not a finding)
```

---

## 4. Access Control with Proper Modifiers

### Pattern: OpenZeppelin Access Control

**Looks Vulnerable**:
```solidity
function setFeeRate(uint256 newRate) external onlyOwner {
    feeRate = newRate;  // Critical parameter change
}
```

**Why It's SAFE**:
- `onlyOwner` modifier restricts access
- Only owner can call this function
- Not an access control vulnerability if intentionally admin-only

**Detection**:
```
IF function has privileged operation
AND has `onlyOwner` / `onlyRole` / `requiresAuth` modifier
THEN access control is present (not a finding)

UNLESS:
- Modifier implementation is flawed
- Owner is EOA (centralization risk, but not access control bug)
```

**Safe Modifiers**:
- `onlyOwner` (OpenZeppelin Ownable)
- `onlyRole(bytes32 role)` (OpenZeppelin AccessControl)
- `requiresAuth` (Solmate Auth)
- `authorized` (custom but common)

---

## 5. Integer Overflow with Solidity 0.8+

### Pattern: Automatic Overflow Protection

**Looks Vulnerable** (but isn't):
```solidity
// Solidity 0.8.0+
function add(uint256 a, uint256 b) public pure returns (uint256) {
    return a + b;  // No SafeMath needed in 0.8+
}
```

**Why It's SAFE**:
- Solidity 0.8.0+ has built-in overflow/underflow protection
- Automatic revert on overflow/underflow
- SafeMath no longer needed

**Detection**:
```
IF pragma solidity >= 0.8.0
AND no `unchecked` block
THEN overflow/underflow is SAFE (not a finding)
```

**Exception** (actually vulnerable):
```solidity
unchecked {
    return a + b;  // VULNERABLE: explicit overflow allowed
}
```

---

## 6. Fee-on-Transfer with Balance Tracking

### Pattern: Actual Balance Change Verification

**Looks Vulnerable** (but isn't):
```solidity
function deposit(IERC20 token, uint256 amount) external {
    uint256 balanceBefore = token.balanceOf(address(this));
    token.transferFrom(msg.sender, address(this), amount);
    uint256 balanceAfter = token.balanceOf(address(this));

    // Track actual received amount (not `amount` parameter)
    uint256 actualReceived = balanceAfter - balanceBefore;
    userBalance[msg.sender] += actualReceived;
}
```

**Why It's SAFE**:
- Checks actual balance change
- Handles fee-on-transfer tokens correctly
- Accounting matches reality

**Detection**:
```
IF deposit/transfer function:
  - Calls `balanceOf()` before transfer
  - Calls `balanceOf()` after transfer
  - Uses (after - before) for accounting
THEN fee-on-transfer is handled (not a finding)
```

---

## 7. Pausable Contracts with Emergency Mechanisms

### Pattern: Pause with Alternative Execution

**Looks Vulnerable** (but isn't):
```solidity
function emergencyWithdraw() external {
    uint256 amount = userBalance[msg.sender];

    try usdc.transfer(msg.sender, amount) {
        userBalance[msg.sender] = 0;
    } catch {
        // USDC paused - allow internal accounting transfer
        pendingWithdrawals[msg.sender] += amount;
        userBalance[msg.sender] = 0;
        emit WithdrawalPending(msg.sender, amount);
    }
}
```

**Why It's SAFE**:
- Uses `try/catch` to handle pausable tokens
- Provides alternative execution path (internal accounting)
- Users not stuck even if token paused

**Detection**:
```
IF critical function uses pausable token (USDC/USDT)
AND has `try/catch` with alternative path
THEN pause handling is present (not a finding)
```

---

## 8. Delegate Call with Known Target

### Pattern: Upgradeable Proxy Pattern

**Looks Vulnerable**:
```solidity
function _delegate(address implementation) internal virtual {
    assembly {
        calldatacopy(0, 0, calldatasize())
        let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
        returndatacopy(0, 0, returndatasize())
        switch result
        case 0 { revert(0, returndatasize()) }
        default { return(0, returndatasize()) }
    }
}
```

**Why It's SAFE** (in correct context):
- Standard EIP-1967 proxy pattern
- `implementation` address controlled by governance
- Well-audited pattern (OpenZeppelin, UUPS, Transparent Proxy)

**Detection**:
```
IF delegatecall to address from:
  - EIP-1967 implementation slot
  - Governed by timelock/multisig
  - OpenZeppelin proxy pattern
THEN controlled delegatecall (not arbitrary delegation vulnerability)

UNLESS:
- Implementation address is user-controlled
- No upgrade delay/governance
```

---

## 9. Low-Level Call with Return Check

### Pattern: Safe Low-Level Call

**Looks Vulnerable** (but isn't):
```solidity
function sendValue(address payable recipient, uint256 amount) internal {
    require(address(this).balance >= amount, "Insufficient balance");

    (bool success, ) = recipient.call{value: amount}("");
    require(success, "Call failed");
}
```

**Why It's SAFE**:
- Return value is checked (`require(success, ...)`)
- Reverts if call fails
- No silent failures

**Detection**:
```
IF low-level call `.call()` / `.staticcall()` / `.delegatecall()`
AND return value is checked with `require(success, ...)`
THEN call failure is handled (not a finding)
```

---

## 10. Floating Pragma in Test Files

### Pattern: Test Contract Flexibility

**Looks Vulnerable**:
```solidity
// In file: test/MyContract.t.sol
pragma solidity ^0.8.0;  // Floating pragma
```

**Why It's SAFE**:
- Test files don't deploy to mainnet
- Floating pragma allows testing across compiler versions
- Not a production security issue

**Detection**:
```
IF file path contains `/test/`, `/tests/`, or ends with `.t.sol`
AND has floating pragma
THEN this is acceptable (not a finding)
```

---

## 11. Unchecked Block for Gas Optimization (Safe Cases)

### Pattern: Overflow Impossible by Design

**Looks Vulnerable** (but isn't):
```solidity
function distribute(uint256 totalAmount, uint256 shares) external {
    for (uint256 i; i < recipients.length;) {
        // Logic here

        unchecked {
            ++i;  // SAFE: i < recipients.length, cannot overflow
        }
    }
}
```

**Why It's SAFE**:
- Loop counter increments
- Bounded by array length
- Mathematically impossible to overflow `uint256` in realistic scenarios

**Detection**:
```
IF unchecked block only contains:
  - Loop counter increments (++i, i++)
  - Known bounded operations
THEN unchecked usage is safe gas optimization (not a finding)

UNLESS:
- Unchecked contains user-controlled arithmetic
- Unchecked contains balance calculations
```

---

## 12. msg.value in Payable Function

### Pattern: Proper Payable Design

**Looks Vulnerable** (but isn't):
```solidity
function deposit() external payable {
    balances[msg.sender] += msg.value;
    emit Deposit(msg.sender, msg.value);
}
```

**Why It's SAFE**:
- Function is `payable` (can receive ETH)
- `msg.value` only accessible in payable context
- Proper accounting of received ETH

**Detection**:
```
IF function uses `msg.value`
AND function is marked `payable`
THEN msg.value usage is intentional (not a finding)

UNLESS:
- msg.value used in non-payable function (impossible, won't compile)
- msg.value used in loop (multipl deposit trick)
```

---

## False Positive Decision Tree

When evaluating a potential finding, ask:

1. **Is there a mitigation modifier?**
   - `nonReentrant` → Reentrancy SAFE
   - `onlyOwner`/`onlyRole` → Access control SAFE
   - `whenNotPaused` → Pause handling present

2. **Is the pattern  properly implemented?**
   - Using `SafeERC20`? → Token issues SAFE
   - Checks-Effects-Interactions? → Reentrancy SAFE
   - Balance diff tracking? → Fee-on-transfer SAFE

3. **Is the context special?**
   - Test file? → Many issues acceptable
   - Solidity 0.8+? → Overflow SAFE
   - OpenZeppelin standard? → Well-audited pattern

4. **Is there error handling?**
   - `try/catch` on external calls? → Failure handled
   - `require(success, ...)` on low-level calls? → Checked

**If answer is YES to any → Likely safe pattern, not a vulnerability**

---

## Usage in Audit

### Stage 1: Pattern Detection
Scan code for vulnerable patterns (from attack-vectors/)

### Stage 2: Mitigation Check
For each match, check this file:
- Does a safe pattern apply?
- Are mitigations present?

### Stage 3: Context Verification
- Is this in a test file? (many findings acceptable)
- Is this part of a standard library? (likely safe)
- Is there comprehensive error handling?

### Stage 4: Final Decision
```
IF (pattern matches attack vector)
AND (NO safe pattern applies)
AND (NO mitigations present)
THEN → Valid finding

IF (pattern matches attack vector)
AND (safe pattern applies)
THEN → False positive, suppress finding
```

---

## Extending This File

When you encounter a false positive:
1. Document the pattern here
2. Explain why it's safe
3. Add detection rules
4. Update MEMORY.md

This file should grow over time as new safe patterns are discovered.
