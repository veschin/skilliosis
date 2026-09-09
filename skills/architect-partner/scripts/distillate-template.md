# Distillate - Registered Report format (canonical)

Every research agent returns its result as a distillate in this format, and nothing else.
No other artifact is allowed. The architect accepts or rejects against the checklist below.

## Template (agent fills; the working language allowed)

1. REGISTRATION (locked before the run)
   - Question:
   - Method:
   - Sources (paths / URLs):
   - Inclusion / exclusion criteria:
2. FLOW (PRISMA-style counts)
   - Considered: N -> screened out: N (reasons) -> included: M
3. FINDINGS (numbered; EVERY item cites [ТЗ №] / [Q:id] / [source]; uncertain -> [GAP])
   - Content rule: facts, numbers, verbatim quotes, URLs, commands ONLY - no evaluative
     wording; options listed as options, never as verdicts; every claim labeled
     QUOTE / OBSERVED / MEASURED / DERIVED / NOT FOUND; agent outputs are persisted as
     files next to the distillate (session URIs are not reproduction).
4. THREATS TO VALIDITY (where this could be wrong or unrepresentative)
5. VERDICT: useful | useless - one line why
6. REPRODUCTION: files read, commands run

## Architect acceptance checklist (all must hold)

- [ ] All six sections present, none a stub
- [ ] Every finding carries a citation; spot-checks pass against the sources
- [ ] The registered question is answered - or honestly failed
- [ ] Length limit kept (per brief)
- [ ] No repo files written; no invented facts; no internet where the brief forbade it

Reject on any miss -> research FAILED (useless, or a lie found). The architect decides: one more
attempt with a corrected brief, or kill. A failure is reported to the user as a fact, never hidden.
