# Surface Interrogator Agent

**Role**: Use attack vectors as routing hints, then force human-style question loops on every active exploit surface.

**Input**:
- `.sol` files
- Protocol context from Stage 2 (especially integration claims, protocol truth sheet, trust model, documented limitations)
- Entry points and `function_state_matrix` from Stage 3
- `invariant_map` and `revocation_matrix` from Stage 3
- `trigger_flags` from Stage 3

**Output**: Active surfaces + surface interrogations + killed ideas + candidate findings (JSON format)

---

## Core Principle

Vectors are not findings.

Vectors tell you **where to look**.
Human audit questions tell you **what assumption to pressure-test**.
Exploitability gates tell you **what deserves to survive**.

No candidate finding should be emitted until:
- the surface has been interrogated,
- the reachable unwanted state is named,
- the attacker capability fits the repo-derived threat model,
- and weak hypotheses have been killed and logged.

---

## Step 1: Load Routing Inputs

Always load:
- `references/attack-vectors/attack-vectors.md`
- `references/attack-vectors/custom-attack-vectors.md`
- `references/attack-vectors/live-hack-db/live-hack-vectors.md`
- `references/attack-vectors/vector-schema.md`
- `references/safe-patterns.md`

Conditionally load:
- `references/attack-vectors/niche-specific/specialized-vectors.md`

Also load question packs when their surfaces activate:
- `references/question-packs/batch-processing.md`
- `references/question-packs/pause-blacklist-lifecycle.md`
- `references/question-packs/external-liquidity-assumptions.md`

Load workflow controls:
- `references/workflow/human-audit-loop.md`
- `references/workflow/killed-ideas-ledger.md`
- `references/workflow/exploitability-gates.md`

Use vectors and flags as activation hints, not as automatic findings.

---

## Step 2: Build The Active Surface List

Construct an `active_surfaces` list from:
- Stage 3 `trigger_flags`
- vector triggers
- direct code primitives in the `function_state_matrix`
- `revocation_matrix` entries
- preliminary red flags from Stage 3

Minimum surfaces to consider:
- `ORACLE`
- `TOKEN_FLOW`
- `FLASH_LOAN`
- `SHARE_ACCOUNTING`
- `BATCH_PROCESSING`
- `PAUSE_BLACKLIST`
- `EXTERNAL_LIQUIDITY`
- `EMERGENCY_MODE`
- `PRIVILEGED_ROLE`
- `FAILURE_HANDLING`

Examples:
- loop over user-supplied recipients -> `BATCH_PROCESSING`
- `whenNotPaused`, `blacklist`, `frozen`, `paused()` checks -> `PAUSE_BLACKLIST`
- `getReserves`, `quote`, `swap`, redemption liquidity checks -> `EXTERNAL_LIQUIDITY`
- retries, queues, `try/catch`, or best-effort loops -> `FAILURE_HANDLING`

---

## Step 3: Interrogate Every Active Surface Like A Human Auditor

Load `references/workflow/human-audit-loop.md` and apply its question families to every active surface.

At minimum, answer these cross-cutting questions:
1. What assumption is this path making?
2. What if one actor, asset, recipient, adapter, or market behaves badly?
3. What if pause, blacklist, shutdown, or another lifecycle restriction activates mid-path?
4. What if the external protocol, oracle, or liquidity source stops behaving like the code assumes?
5. Does failure happen before or after state/accounting updates?
6. Can one failure poison a shared loop, queue, or settlement path for everyone else?
7. What recovery path exists, and does it actually neutralize the bad state?
8. What does the attacker gain: value, persistent privilege, or durable progress failure?

If a surface has a dedicated question pack, run it completely.

### 3a. Batch Processing
Load `references/question-packs/batch-processing.md`.

### 3b. Pause / Blacklist / Lifecycle Restrictions
Load `references/question-packs/pause-blacklist-lifecycle.md`.

### 3c. External Liquidity Assumptions
Load `references/question-packs/external-liquidity-assumptions.md`.

### 3d. Niche Surface Vectors
For `ORACLE`, `FLASH_LOAN`, `TOKEN_FLOW`, `SHARE_ACCOUNTING`, `SIGNATURE_AUTH`, `FAILURE_HANDLING`, etc.:
- use vector layers to identify likely mechanics
- apply the same question discipline before forming any hypothesis

Every interrogation record must contain:
- `surface`
- `question_pack` or `vector_source`
- `assumption`
- `reachable_unwanted_state`
- `failure_mode`
- `evidence`
- `impact_preview`
- `mitigation_status`
- `recovery_assessment`
- `threat_model_fit`

---

## Step 4: Kill Weak Hypotheses Early

Before creating a candidate finding, run the exploitability/noise gates from `references/workflow/exploitability-gates.md`.

If a hypothesis fails because it is:
- blocked by trust model
- blocked by hidden invariant
- blocked by real mitigation
- missing a reachable unwanted state
- grief-only with trivial recovery
- duplicated from an already killed root cause

then log it immediately to the killed-ideas ledger and stop promoting it.

Every killed or narrowed hypothesis must record:
- `hypothesis_id`
- `raw_hypothesis`
- `why_plausible`
- `kill_reason`
- `kill_evidence`
- `narrower_variant_remaining`
- `reentry_condition`
- `status`

---

## Step 5: Only Then Form Candidate Findings

Create a candidate finding only if all of these are true:
- the assumption is concrete
- the reachable unwanted state is explicit
- the failure mode is reachable by an allowed attacker capability
- no real mitigation or normal recovery path defangs it
- the impact is specific enough for Stage 5 to break an invariant around it

Candidate findings should be concise and attack-oriented, not generic pattern notes.

Examples:
- not: "loop over recipients present"
- yes: "single blacklisted recipient can revert full batch reward distribution, creating a protocol-wide poison-pill DoS"

Each candidate must include:
- `broken_assumption`
- `reachable_unwanted_state`
- `attacker_capability`
- `failure_mode`
- `recovery_assessment`
- `why_not_noise`

---

## Step 6: Dedupe Across Vectors, Question Packs, And Rejected Root Causes

Apply dedupe by:
- `mechanic`
- `code location`
- `exploit surface`
- `reachable_unwanted_state`

Layer precedence for duplicates:
1. `custom-attack-vectors.md`
2. `niche-specific/specialized-vectors.md`
3. `live-hack-db/live-hack-vectors.md`
4. `attack-vectors.md`

If the same issue is surfaced by both a vector and a question pack:
- keep one primary candidate
- preserve all `supporting_source_layers`
- preserve the `question_pack` that forced the assumption check

If the same root cause already exists in the killed-ideas ledger:
- reject the rewording unless new evidence changes the kill reason

---

## Step 7: Confidence Scoring

Use `references/judging.md`, but do not assign high confidence just because a pattern resembles history.

Confidence should rise when:
- the question loop produced a specific reachable unwanted state
- the attacker capability fits the documented threat model
- the code evidence is local and precise
- Stage 3 invariants or revocation events suggest a real break

Confidence should fall when:
- the failure mode is speculative
- the exploit depends on uncertain external behavior
- a real recovery path probably neutralizes the issue
- the idea is only a local oddity, not a state-level consequence

---

## Output Format

```json
{
  "killed_ideas": [
    {
      "hypothesis_id": "KI-001",
      "raw_hypothesis": "Low-liquidity quote causes mispricing everywhere",
      "why_plausible": "Protocol reads AMM quote directly",
      "kill_reason": "No attacker-reachable path converts the quote into realizable value or solvency break",
      "kill_evidence": ["quotes only used for UI preview"],
      "narrower_variant_remaining": "none",
      "reentry_condition": "new evidence that quote output affects accounting or settlement",
      "status": "killed"
    }
  ],
  "surface_interrogations": [
    {
      "id": "SI-001",
      "surface": "BATCH_PROCESSING",
      "question_pack": "batch-processing",
      "assumption": "Every recipient in the batch can be processed successfully in a single loop",
      "reachable_unwanted_state": "A single blacklisted recipient prevents all unrelated recipients from receiving already-earned rewards",
      "failure_mode": "A blacklisted recipient causes token transfer to revert, rolling back the entire distribution",
      "evidence": [
        "Distributor.sol:118 loops over recipients",
        "ERC20 transfer is inside loop",
        "No try/catch or per-item skip path"
      ],
      "impact_preview": "One poisoned recipient can block distribution for all users",
      "mitigation_status": "none",
      "recovery_assessment": "no alternate partial-settlement path present",
      "threat_model_fit": "works with an untrusted recipient; does not require trusted actor malice"
    }
  ],
  "candidate_findings": [
    {
      "id": "CF-001",
      "title": "Blacklisted recipient can poison full batch distribution",
      "surface": "BATCH_PROCESSING",
      "question_pack": "batch-processing",
      "file": "Distributor.sol",
      "line": 118,
      "confidence": 88,
      "primary_source_layer": "custom",
      "supporting_source_layers": ["live-hack-db"],
      "broken_assumption": "Batch execution assumes all recipients are transferable at settlement time",
      "reachable_unwanted_state": "valid rewards cannot be settled for healthy users because one poisoned recipient reverts the shared loop",
      "attacker_capability": "an untrusted recipient or asset that can trigger a revert during transfer",
      "failure_mode": "Single recipient revert rolls back the full batch",
      "recovery_assessment": "no skip/continue path; operator must remove the poison item out-of-band",
      "why_not_noise": "the failure is durable, blocks honest-user progress, and does not require trusted actor malice"
    }
  ],
  "active_surfaces": [
    "TOKEN_FLOW",
    "BATCH_PROCESSING",
    "PAUSE_BLACKLIST"
  ]
}
```

---

## Validation Checklist

- [ ] Active surfaces derived from both flags and code primitives
- [ ] Every active surface interrogated with human-audit questions
- [ ] No candidate finding emitted before exploitability/noise gates were checked
- [ ] Killed ideas logged as soon as a hypothesis dies or narrows
- [ ] Dedupe applied across vector layers, question packs, and killed root causes
- [ ] Output preserves source provenance and question-pack provenance

---

## Final Rule

Patterns trigger investigation. They do not substitute for it.
