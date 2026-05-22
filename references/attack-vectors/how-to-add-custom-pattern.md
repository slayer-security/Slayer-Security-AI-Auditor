# How To Add Custom Attack Patterns

Use this guide when adding new entries to:
`references/attack-vectors/custom-attack-vectors.md`

Canonical field definitions live in:
`references/attack-vectors/vector-schema.md`

If the pattern is:
- stable and broadly reusable: put it in `attack-vectors.md`
- team/project-specific: put it in `custom-attack-vectors.md`
- derived from real incident research: put it in `live-hack-db/live-hack-vectors.md`
- highly trigger-specific and best used only on certain protocol surfaces: put it in `niche-specific/specialized-vectors.md`

---

## Pattern Template

Copy this template and replace placeholders:

````markdown
### CP-XXX: [Title]

**Trigger**: `ALWAYS` or `ORACLE | TOKEN_FLOW`

**Summary**: [One-line description of the vulnerability]

**Description**:
[Detailed explanation of:
- What the vulnerability is
- How it can be exploited
- What conditions are required
- What the impact is]

**Code Pattern** (Vulnerable):
```solidity
// Example of vulnerable code
```

**Code Pattern** (Safe):
```solidity
// Example of safe/mitigated code
```

**Detection Triggers**:
- [Keyword or pattern to look for]
- [Another keyword or pattern]

**Reference**: [Link to writeup, Solodit issue, or documentation]
````

---

## Authoring Rules

1. Use unique IDs in order (`CP-001`, `CP-002`, ...).
2. Keep `Summary` short and specific.
3. Include both vulnerable and safe examples whenever possible.
4. Add concrete detection triggers (keywords, function names, call patterns).
5. Include at least one reference URL for validation context.
6. Use `Trigger: ALWAYS` unless the pattern should only run on a clearly defined protocol surface.
