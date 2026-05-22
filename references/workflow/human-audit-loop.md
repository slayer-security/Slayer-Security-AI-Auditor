# Human Audit Loop

Purpose: force the audit to think like a careful human reviewer instead of stopping at pattern recognition.

For every active surface, ask these questions before forming a finding.

## Core Questions

1. **What assumption is this path making?**
- About a token, recipient, keeper, oracle, reserve, queue, or state transition.

2. **What if one item is bad?**
- One recipient blacklisted
- One asset paused
- One order malformed
- One adapter reverting
- One market illiquid

3. **What if lifecycle restrictions activate mid-path?**
- pause / unpause
- blacklist / freeze
- shutdown / rescue
- migration / delist / decommission

4. **What if the external dependency stops behaving like the code assumes?**
- low liquidity
- stale oracle
- manipulated spot price
- bridge delay
- token semantics mismatch

5. **Does failure happen before or after accounting updates?**
- Are liabilities recorded before value moves?
- Is progress marked before transfer succeeds?
- Is cleanup skipped on revert or retry?

6. **Can one failure poison global progress?**
- shared loop
- shared queue
- global settlement
- batched distribution
- multicall aggregation

7. **What should have been revoked, but might still be alive?**
- authority after role removal
- settlement path after pause
- withdrawability after shutdown
- asset reachability after delisting

8. **What is the attacker win?**
- value extraction
- privilege persistence
- durable progress failure
- solvency break
- queue blockage / poison-pill griefing

9. **What is the recovery path, and is it real?**
- automatic retry
- operator cleanup
- user escape hatch
- bounded loss mechanism

If the recovery path is manual, slow, privileged, or incomplete, it may still be a real bug.

## Final Rule

A pattern match is only a lead. A reportable issue needs a broken assumption, a reachable unwanted state, and a meaningful attacker win or durable user loss.
