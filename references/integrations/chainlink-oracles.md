# Chainlink Oracle Integration Patterns

This file documents critical oracle integration vulnerabilities, focusing on Chainlink (the most widely used oracle network). Oracle bugs have caused some of the largest DeFi exploits, including $89M (Compound 2020) and ongoing issues in 2024 (Midas protocol).

**Historical Impact**:
- Compound (2020): $89M liquidations from oracle manipulation
- Midas Protocol (2024): Stale price acceptance led to bad debt
- Venus Protocol (2021): $11M loss from oracle lag
- Hundreds of smaller protocols affected by oracle issues

---

## 1. Stale Price Data (Missing `updatedAt` Check)

**D:** (Description)
Chainlink price feeds update based on two triggers: deviation threshold (e.g., 0.5% price change) or heartbeat interval (e.g., 1 hour or 24 hours). During low volatility or network congestion, prices can become stale. If a protocol doesn't check the `updatedAt` timestamp, it may use prices that are hours or days old, leading to incorrect liquidations or arbitrage opportunities.

**Vulnerability Pattern**:
```solidity
// VULNERABLE: No staleness check
function getPrice() public view returns (uint256) {
    (, int256 price,,,) = priceFeed.latestRoundData();
    require(price > 0, "Invalid price");
    return uint256(price);
}
```

**Heartbeat Intervals by Feed** (Critical Knowledge):
- ETH/USD: 1 hour
- BTC/USD: 1 hour
- Stablecoin pairs: 24 hours
- Less liquid pairs: Up to 24 hours

**Real Exploit**: Midas Protocol (2024)
- Protocol hardcoded staleness threshold: `_HEALTHY_DIFF = 3 days`
- Used this same threshold for feeds with 1-hour heartbeats
- During market volatility, 1-hour feeds lagged but were within 3-day threshold
- Protocol accepted 24+ hour old prices as "current"
- Bad debt accumulated, positions improperly liquidated

**Impact**:
- Stale prices lead to incorrect liquidations
- Arbitrage: Buy at stale oracle price, sell at real market price
- Protocol insolvency (bad debt accumulation)
- Severity: CRITICAL (direct fund loss + insolvency)

**FP:** (False Positive Prevention)
- ✅ Safe if checking `updatedAt` against appropriate threshold for each feed
- ✅ Safe if using TWAP with sufficiently long window
- ✅ Safe if protocol has circuit breakers for price staleness
- ❌ Vulnerable if no `updatedAt` check
- ❌ Vulnerable if using generic staleness threshold (same value for all feeds)

**Detection**:
```solidity
// Pattern to detect:
(, int256 price,,,) = priceFeed.latestRoundData();
// Missing: uint256 updatedAt check

// Also check for hardcoded thresholds:
require(block.timestamp - updatedAt < 3 days);  // RED FLAG: generic threshold
```

**Solodit Query**:
```json
{
  "keywords": ["chainlink", "stale price", "updatedAt", "oracle lag"],
  "tags": ["oracle", "chainlink"],
  "severity": ["Critical", "High"]
}
```

**Fix**:
```solidity
// SAFE: Proper staleness check with feed-specific threshold
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

    // Feed-specific staleness threshold
    uint256 stalenessThreshold = getFeedHeartbeat(address(priceFeed)) * 2;
    require(block.timestamp - updatedAt <= stalenessThreshold, "Price too stale");

    return uint256(price);
}

// Store heartbeat per feed
mapping(address => uint256) public feedHeartbeats;
// ETH/USD: 3600 (1 hour)
// Stablecoin pairs: 86400 (24 hours)
```

---

## 2. Incorrect Decimal Handling

**D:** (Description)
Chainlink price feeds return prices with varying decimal precision:
- USD pairs: 8 decimals (e.g., ETH/USD returns price * 10^8)
- ETH pairs: 18 decimals (e.g., LINK/ETH returns price * 10^18)
- Other pairs: May vary

If a protocol assumes all feeds have the same decimals (e.g., always 18), price calculations will be off by 10^10, leading to massive over/under-valuation of assets.

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Assumes all feeds return 18 decimals
function getTokenValue(address token, uint256 amount) public view returns (uint256) {
    (, int256 price,,,) = priceFeeds[token].latestRoundData();
    return (amount * uint256(price)) / 1e18;  // WRONG if feed uses 8 decimals!
}
```

**Example Calculation Error**:
```
ETH/USD price: $2000
Chainlink returns: 2000 * 10^8 = 200000000000

Protocol assumes 18 decimals:
value = (1 ETH * 200000000000) / 10^18
      = 0.0000002 USD  // WRONG! Should be $2000

Correct (8 decimals):
value = (1 ETH * 200000000000) / 10^8
      = 2000 USD  // Correct
```

**Impact**:
- 10^10 factor error in valuations
- Severe over/under-collateralization
- Liquidations at wrong thresholds
- Protocol insolvency or unfair liquidations
- Severity: CRITICAL (massive valuation errors)

**FP:** (False Positive Prevention)
- ✅ Safe if calling `priceFeed.decimals()` for each feed
- ✅ Safe if normalizing all prices to same decimal base
- ✅ Safe if using Chainlink's `AggregatorV3Interface` correctly
- ❌ Vulnerable if hardcoding decimal assumptions

**Detection**:
```solidity
// Pattern to detect:
price / 1e18  // Hardcoded decimal assumption
price * 1e18  // Hardcoded decimal assumption

// NOT using:
priceFeed.decimals()
```

**Solodit Query**:
```json
{
  "keywords": ["chainlink decimals", "oracle decimals", "price precision"],
  "tags": ["oracle", "chainlink", "decimals"],
  "severity": ["Critical", "High"]
}
```

**Fix**:
```solidity
// SAFE: Query decimals from each feed
function getTokenValue(address token, uint256 amount) public view returns (uint256) {
    AggregatorV3Interface feed = priceFeeds[token];
    (, int256 price,,,) = feed.latestRoundData();
    uint8 feedDecimals = feed.decimals();

    // Normalize to 18 decimals for internal calculations
    uint256 normalizedPrice = uint256(price) * (10 ** (18 - feedDecimals));
    return (amount * normalizedPrice) / 1e18;
}
```

---

## 3. L2 Sequencer Uptime Check (Arbitrum, Optimism)

**D:** (Description)
On Layer 2 networks (Arbitrum, Optimism), Chainlink price feeds can continue updating even when the L2 sequencer is down. This creates a critical vulnerability: during sequencer downtime, users can't submit transactions, but when it comes back up, stale prices from before the outage are still in the oracle. This allows arbitrage attacks immediately after sequencer restart.

**L2-Specific Risk**:
- Sequencer goes down for 1 hour
- Price feeds continue updating via L1
- Real market: ETH drops 10%
- Sequencer comes back up
- Oracle price is current, but users couldn't trade during volatility
- Attacker immediately liquidates positions at outdated collateral ratios

**Vulnerability Pattern**:
```solidity
// VULNERABLE: No sequencer uptime check on L2
function getPrice() public view returns (uint256) {
    (, int256 price,,,) = priceFeed.latestRoundData();
    return uint256(price);
    // Missing: sequencer uptime check
}
```

**Impact**:
- Mass liquidations immediately after sequencer restart
- Users can't defend positions during downtime
- Arbitrage opportunities (stale prices vs real market)
- Severity: HIGH (unfair liquidations, user loss)

**FP:** (False Positive Prevention)
- ✅ Safe if on Ethereum mainnet (no sequencer)
- ✅ Safe if checking Chainlink's L2 Sequencer Uptime Feed
- ✅ Safe if adding grace period after sequencer restart
- ❌ Vulnerable if on L2 (Arbitrum/Optimism) without sequencer check

**Detection**:
```solidity
// Pattern to detect:
- Deployment on Arbitrum or Optimism
- Using Chainlink price feeds
- No reference to sequencerUptimeFeed
```

**Solodit Query**:
```json
{
  "keywords": ["L2 sequencer", "Arbitrum sequencer", "Optimism sequencer downtime"],
  "tags": ["oracle", "chainlink", "L2"],
  "severity": ["High", "Medium"]
}
```

**Fix**:
```solidity
// SAFE: Check L2 sequencer uptime (Arbitrum example)
AggregatorV3Interface public sequencerUptimeFeed;

constructor() {
    // Arbitrum Sequencer Uptime Feed
    sequencerUptimeFeed = AggregatorV3Interface(0xFdB631F5EE196F0ed6FAa767959853A9F217697D);
}

function getPrice() public view returns (uint256) {
    // Check sequencer status
    (, int256 answer, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();

    bool isSequencerUp = answer == 0;
    require(isSequencerUp, "Sequencer is down");

    // Grace period: wait 1 hour after sequencer restart
    uint256 timeSinceUp = block.timestamp - startedAt;
    require(timeSinceUp > 3600, "Grace period not over");

    // Now safe to use price feed
    (, int256 price,,,) = priceFeed.latestRoundData();
    return uint256(price);
}
```

**L2 Sequencer Feed Addresses**:
- Arbitrum One: `0xFdB631F5EE196F0ed6FAa767959853A9F217697D`
- Optimism: `0x371EAD81c9102C9BF4874A9075FFFf170F2Ee389`

---

## 4. Negative or Zero Price Handling

**D:** (Description)
Chainlink can return negative prices during extreme market events or oracle malfunctions. Some assets can theoretically have negative prices (e.g., oil futures in 2020). If a protocol doesn't handle this, it can lead to:
- Underflow when converting `int256` to `uint256`
- Division by zero
- Incorrect collateral calculations

**Vulnerability Pattern**:
```solidity
// VULNERABLE: No negative price check
function getCollateralValue(uint256 amount) public view returns (uint256) {
    (, int256 price,,,) = priceFeed.latestRoundData();
    return (amount * uint256(price)) / 1e8;  // DANGER: uint256(price) can underflow
}
```

**Impact**:
- Underflow: Negative price becomes huge positive number
- Zero price: Division by zero or infinite collateral ratios
- Incorrect liquidations or unbounded minting
- Severity: HIGH (valuation errors, potential exploits)

**FP:** (False Positive Prevention)
- ✅ Safe if explicitly checking `price > 0`
- ✅ Safe if using `require(price > 0, "Invalid price")`
- ❌ Vulnerable if directly casting `int256` to `uint256` without check

**Detection**:
```solidity
// Pattern to detect:
int256 price = ...;
uint256(price)  // RED FLAG: No positive check before cast
```

**Solodit Query**:
```json
{
  "keywords": ["chainlink negative price", "price zero", "int256 to uint256"],
  "tags": ["oracle", "chainlink"],
  "severity": ["High", "Medium"]
}
```

**Fix**:
```solidity
// SAFE: Check for positive price before casting
function getCollateralValue(uint256 amount) public view returns (uint256) {
    (, int256 price,,,) = priceFeed.latestRoundData();

    require(price > 0, "Invalid price: must be positive");

    return (amount * uint256(price)) / 1e8;
}
```

---

## 5. Missing `answeredInRound` Check

**D:** (Description)
The `latestRoundData()` function returns `roundId` and `answeredInRound`. If `answeredInRound < roundId`, it means the round hasn't been fully answered yet, and the data might be incomplete or stale. This is a subtle staleness indicator that many protocols miss.

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Ignoring answeredInRound
function getPrice() public view returns (uint256) {
    (uint80 roundId, int256 price,,,) = priceFeed.latestRoundData();
    // Missing: answeredInRound check
    return uint256(price);
}
```

**Impact**:
- Using incomplete round data
- Potential price manipulation if round not finalized
- Severity: MEDIUM (additional staleness indicator)

**FP:** (False Positive Prevention)
- ✅ Safe if checking `answeredInRound >= roundId`
- ✅ Safe if using comprehensive staleness checks
- ❌ Vulnerable if only checking `updatedAt` without `answeredInRound`

**Detection**:
```solidity
// Pattern to detect:
(uint80 roundId, int256 price, , uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

// Missing:
require(answeredInRound >= roundId, "Stale price");
```

**Solodit Query**:
```json
{
  "keywords": ["answeredInRound", "roundId", "chainlink round"],
  "tags": ["oracle", "chainlink"],
  "severity": ["Medium"]
}
```

**Fix**:
```solidity
// SAFE: Complete staleness check
function getPrice() public view returns (uint256) {
    (
        uint80 roundId,
        int256 price,
        ,
        uint256 updatedAt,
        uint80 answeredInRound
    ) = priceFeed.latestRoundData();

    require(price > 0, "Invalid price");
    require(answeredInRound >= roundId, "Stale price - incomplete round");
    require(block.timestamp - updatedAt <= STALENESS_THRESHOLD, "Price too old");

    return uint256(price);
}
```

---

## 6. Flash Loan Price Manipulation (Not Using TWAP)

**D:** (Description)
While Chainlink oracles themselves are resistant to flash loan attacks (they aggregate off-chain data), protocols sometimes combine Chainlink with on-chain AMM prices. If the on-chain component can be manipulated with flash loans, the combined price can be attacked. Always use Chainlink prices directly, not combined with spot AMM prices.

**Vulnerability Pattern**:
```solidity
// VULNERABLE: Combining Chainlink with manipulable AMM price
function getPrice() public view returns (uint256) {
    uint256 chainlinkPrice = getChainlinkPrice();
    uint256 uniswapPrice = getUniswapSpotPrice();  // DANGER: Flash loan manipulable

    // Average of two prices
    return (chainlinkPrice + uniswapPrice) / 2;  // Can be manipulated
}
```

**Impact**:
- Flash loan attack on AMM component
- Manipulation of combined price
- Incorrect valuations
- Severity: HIGH (price manipulation)

**FP:** (False Positive Prevention)
- ✅ Safe if using only Chainlink price
- ✅ Safe if using Uniswap TWAP (Time-Weighted Average Price)
- ❌ Vulnerable if combining with spot AMM prices

**Detection**:
```solidity
// Pattern to detect:
getReserves()  // Spot price from AMM
reserve0 / reserve1  // Spot price calculation

// Combined with Chainlink price in same function
```

**Solodit Query**:
```json
{
  "keywords": ["oracle manipulation", "flash loan oracle", "AMM price manipulation"],
  "tags": ["oracle", "flash-loan", "manipulation"],
  "severity": ["Critical", "High"]
}
```

**Fix**:
```solidity
// SAFE Option 1: Use only Chainlink
function getPrice() public view returns (uint256) {
    return getChainlinkPrice();  // Flash loan resistant
}

// SAFE Option 2: If need AMM price, use TWAP
function getPrice() public view returns (uint256) {
    uint256 chainlinkPrice = getChainlinkPrice();
    uint256 twapPrice = getUniswapTWAP();  // Time-weighted, not spot

    // Use the more conservative price
    return chainlinkPrice < twapPrice ? chainlinkPrice : twapPrice;
}
```

---

## Integration Checklist

When integrating Chainlink oracles:

### Mainnet (Ethereum L1):
- [ ] Check `updatedAt` with feed-specific staleness threshold
- [ ] Check `answeredInRound >= roundId`
- [ ] Check `price > 0` before casting to `uint256`
- [ ] Query `decimals()` for each feed (don't hardcode)
- [ ] Store heartbeat intervals per feed
- [ ] Use only Chainlink prices (no AMM spot price mixing)

### L2 (Arbitrum, Optimism):
- [ ] All mainnet checks above, plus:
- [ ] Check sequencer uptime feed
- [ ] Add grace period (1 hour) after sequencer restart
- [ ] Test scenarios with sequencer down

### Documentation:
- [ ] Document which price feeds are used
- [ ] Document staleness thresholds
- [ ] Document L2-specific safety measures

### Circuit Breakers:
- [ ] Pause protocol if oracle price deviates >10% from backup oracle
- [ ] Pause liquidations if sequencer was recently down
- [ ] Emergency pause if price staleness exceeds threshold

---

## Chainlink Price Feed Addresses

### Ethereum Mainnet:
- ETH/USD: `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`
- BTC/USD: `0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c`
- DAI/USD: `0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9`

### Arbitrum One:
- Sequencer Uptime: `0xFdB631F5EE196F0ed6FAa767959853A9F217697D`
- ETH/USD: `0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612`

### Optimism:
- Sequencer Uptime: `0x371EAD81c9102C9BF4874A9075FFFf170F2Ee389`
- ETH/USD: `0x13e3Ee699D1909E989722E753853AE30b17e08c5`

[Full list at: https://docs.chain.link/data-feeds/price-feeds/addresses]

---

## References

- [Chainlink Price Feeds Documentation](https://docs.chain.link/data-feeds/price-feeds)
- [L2 Sequencer Uptime Feeds](https://docs.chain.link/data-feeds/l2-sequencer-feeds)
- [Midas Protocol Exploit Analysis](https://medium.com/@0xnolo/midas-protocol-oracle-manipulation-2024)
- [Compound Oracle Manipulation (2020)](https://www.coindesk.com/markets/2020/11/26/oracle-exploit-sees-100m-liquidated-on-compound/)
- [Venus Protocol Oracle Lag](https://rekt.news/venus-blizz-rekt/)
