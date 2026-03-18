# Custom Attack Patterns

User-defined attack patterns for the Slayer Security Auditor. Add your own patterns here and the skill will scan for them during audits.

---

## How to Add a Pattern

Copy the template below and fill in the fields:

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

## User-Added Patterns

### CP-001: [Your First Pattern Title]

**Summary**: [One-line description]

**Description**:
[Detailed explanation]

**Code Pattern** (Vulnerable):
```solidity
// Vulnerable code example
```

**Code Pattern** (Safe):
```solidity
// Safe code example
```

**Detection Triggers**:
- [Trigger 1]
- [Trigger 2]

**Reference**: [Link]

---

<!-- Add more patterns below using the template above -->

