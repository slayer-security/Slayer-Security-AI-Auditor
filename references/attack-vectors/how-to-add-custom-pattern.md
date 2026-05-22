# How To Add Custom Attack Patterns

Use this guide when adding new entries to:
`references/attack-vectors/custom-attack-vectors.md`

---

## Pattern Template

Copy this template and replace placeholders:

```markdown
### CP-XXX: [Title]

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
```

---

## Authoring Rules

1. Use unique IDs in order (`CP-001`, `CP-002`, ...).
2. Keep `Summary` short and specific.
3. Include both vulnerable and safe examples whenever possible.
4. Add concrete detection triggers (keywords, function names, call patterns).
5. Include at least one reference URL for validation context.
