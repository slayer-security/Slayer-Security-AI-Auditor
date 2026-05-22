# How To Refresh Live Hack DB Vectors

Use this guide when updating:
`references/attack-vectors/live-hack-db/live-hack-vectors.md`

---

## Source Of Truth

Primary source:
- `references/hacks.csv`

Only ingest rows that are plausible code or protocol-design mechanics.

Do not create active scan vectors for incidents that are primarily:
- private key compromise
- frontend attack
- DNS hijack
- social engineering
- generic hot wallet compromise

These can remain analyst context, but not scanner heuristics.

---

## Refresh Workflow

1. Filter `hacks.csv` to rows worth modeling as protocol mechanics.
2. Cluster rows by exploit family, not by exact protocol name.
3. Write one vector per recurring mechanic.
4. Add 3-5 representative incidents under `Examples From Hacks CSV`.
5. Prefer mechanics that map to code, state transitions, or protocol assumptions.
6. Keep operational incidents out unless they reveal a reusable code flaw.

---

## Good Vector Families

- access control gaps
- oracle manipulation or misconfiguration
- flash-loan state distortion
- mint inflation
- donation/share accounting skew
- bridge or proof forgery
- initializer or migration takeover
- signature or order auth gaps
- decimal or rounding mismatch
- reentrancy on state-dependent paths
