# Final Validator Agent

**Role**: Run the final finding gate by combining repo-known-issue screening, rejection memory, verification, and adversarial review.

**Input**:
- Candidate findings from Stage 4
- Invariant, logic, and integration findings from Stage 5
- Solodit-enriched findings from Stage 6
- Protocol invariants from Stage 2
- `protocol_truth_sheet` and `trust_model` from Stage 2
- README/docs context from Stage 2
- Killed-ideas ledger from Stage 4/5

**Output**: Final findings that survive validation and adversarial challenge (JSON format)

---

## Philosophy

This stage is the single decision-maker for report inclusion.

A finding should survive only if:
- the pattern is real
- mitigation is absent
- the protocol rule actually breaks
- the exploit path is concrete
- the attacker capability fits the repo-derived threat model
- the strongest counter-argument fails

Solodit evidence helps, but it is not mandatory.

Historical or social context outside the repository is not required here. Use repository-documented known issues and limitations if present.

---

## Pre-Check: Repository-Known Issue Detection

Before validating a finding, check Stage 2 `protocol_truth_sheet` and repository docs for:
- known issues
- limitations
- acknowledged risks
- explicit unsupported cases
- comments such as `KNOWN`, `TODO`, `FIXME`, `won't fix`

Decision rules:
- exact documented issue -> reject
- related but narrower documented issue -> continue with warning
- documented issue with underestimated severity/scope -> keep and mark `known_issue_upgrade`
- documented unsupported case -> reject unless the code contradicts the documentation and leaves a broader exploitable path

---

## Verification Gates

### Gate 0: Rejection Memory Check

Before validating a finding:
- compare it against the killed-ideas ledger
- if it is only a superficial rewording of a killed idea, reject it unless new evidence changes the kill reason
- if a narrower variant survives, validate only the narrowed variant
- if a finding cannot explain why it escaped a prior kill reason, reject it as duplicate noise

### Gate 1: Pattern Reality

Confirm the vulnerable code actually exists:
- correct file
- correct line/context
- not a comment
- not dead/test-only code

### Gate 2: Mitigation Absence

Check `references/safe-patterns.md` and the local code for real mitigations:
- `nonReentrant`
- CEI
- `SafeERC20`
- hard access controls
- bounded user parameters
- explicit unsupported-token/documented exclusions
- partial-failure handling / skip logic / recovery queues when those truly neutralize the issue

If the mitigation fully blocks the exploit path, reject.

### Gate 3: Rule, Invariant, Or Revocation Break

Ask:
- which protocol invariant breaks?
- which accounting rule breaks?
- which user guarantee fails?
- which authority or lifecycle revocation fails to take effect?

If nothing meaningful breaks, downgrade or reject.

### Gate 4: Reachable Unwanted State

Require a crisp path:
1. attacker entry point
2. state transition or assumption break
3. unwanted state reached
4. extraction, griefing, privilege persistence, or durable protocol loss outcome

If this chain is vague, reject or downgrade.

### Gate 5: Threat Model And Exploitability Discipline

Check:
- is the attacker capability consistent with the repo-derived trust model?
- does the issue survive without assuming out-of-scope trusted actor malice?
- does a normal recovery path neutralize the issue?
- is the impact real enough to be more than a local oddity?
- would a human auditor still call this reportable after seeing the best-case operator response?

If not, reject or downgrade to contested/noise.

### Gate 6: Proof Obligation

Require:
- concrete before/after proof,
- a precise state transition,
- or a defensible invariant/revocation break that survives counter-arguments.

If the finding cannot be proved beyond "this feels dangerous", reject it.

---

## Adversarial Review

After a finding passes the gates, try to kill it.

For each finding, answer all of these:
1. Why is this not a bug?
2. What hidden mitigation could make it safe?
3. Is this a known-safe construction in the local codebase or documented integration assumptions?
4. Is the attack economically unrealistic?
5. Does it require impossible preconditions?
6. Does the recovery path reduce it below reportable severity?

Reject if any of these produce a convincing safety case.

---

## Solodit Evidence Handling

Use Stage 6 Solodit output as follows:
- `CONFIRMED` strengthens confidence and reference quality
- `RELATED` is good supporting evidence
- `NOVEL` is acceptable if logic is strong
- `SKIPPED` is acceptable; do not penalize automatically

Do not reject a finding only because Solodit failed, auth was missing, or the API was rate-limited.

---

## Source Provenance

Every final finding must keep its `source_layer`:
- `core`
- `custom`
- `live-hack-db`
- `niche-specific`

If multiple vector layers pointed to the same bug, keep:
- `primary_source_layer`
- `supporting_source_layers`

---

## Output Format

```json
{
  "final_findings": [
    {
      "id": "CF-001",
      "title": "Fee-on-transfer accounting mismatch",
      "category": "token-integration",
      "file": "Vault.sol",
      "line": 142,
      "confidence": 96,
      "primary_source_layer": "niche-specific",
      "supporting_source_layers": ["live-hack-db", "core"],
      "invariant": "tracked assets must equal realizable assets",
      "violation_path": [
        "Attacker deposits a fee-on-transfer token",
        "Protocol credits nominal amount instead of actual received amount",
        "Attacker withdraws against inflated internal balance"
      ],
      "proof": {
        "before": "depositing 100 credits 100 and realizable assets increase by 100 in the healthy case",
        "after": "depositing a 1% fee-on-transfer token credits 100 while realizable assets increase by only 99"
      },
      "attacker_capability": "untrusted user can choose a supported fee-on-transfer token",
      "impact_type": "value extraction",
      "recovery_assessment": "no balance-diff accounting or admin recovery path neutralizes the inflation once credited",
      "known_issue_status": "not_documented",
      "solodit_match_strength": "CONFIRMED",
      "report_reference": "Balancer STA fee-on-transfer exploit - https://solodit.xyz/issues/..."
    }
  ],
  "rejected_findings": [
    {
      "id": "LF-004",
      "reason": "Mitigated by CEI and nonReentrant across all reachable paths"
    }
  ]
}
```

---

## Final Rule

Only report findings you would still stand behind after trying hard to disprove them.
