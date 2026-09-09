---
name: architect-reflection
description: "Use when the user orders a session reflection ('сделай рефлексию', 'разбор ошибок за сессию'), when the session's work is about to be committed and mistakes may remain unrecorded, or when the project quote book has grown beyond the genuinely important. Collects only CONFIRMED mistakes into the project lessons, collects user-locked document patterns and conventions into AGENTS.md, squashes the quote book into high-authority artifacts, routes protocol-level mistakes into the parent skill."
---

# Reflection - session mistakes and quote-book compaction

Turns the session's real mistakes into durable never-repeat lessons, and squashes the project
quote book into the artifacts that earned authority.

## HARD GATE

Only CONFIRMED mistakes enter the lessons:

- the user explicitly called it a mistake, or
- it is an observed failure of a canon rule (the rule is quoted in the lesson's prevention).

Only USER-LOCKED document patterns enter AGENTS.md: a pattern qualifies only when the user
confirmed it as the way his documents are maintained (a quote locking it exists). An
unconfirmed style observation is a question to the user, never a rule.

Never invent or pad. A lesson without evidence from the current session is forbidden.
Likewise, a quote is removed from the book ONLY when its content already lives in a
high-authority artifact.

## Procedure

1. Re-scan the session in order: every user correction, every canon violation observed by
   tooling (guard FAIL, failed check), every deliverable the user rejected.
2. For each real mistake write ONE compact lesson into the project lessons file (AGENTS.md,
   section "Lessons - never repeat"):
   `- <problem, one line>. Real fix: <what actually resolved it>. Prevention: <concrete check>.`
3. Respect the lessons file: dedupe against existing lessons - merge into the older entry,
   never duplicate; keep it short; no entry without the three fields; remove or reword a
   lesson only on the user's order.
4. Scan for document patterns and conventions the user locked this session (notation like
   join annotations, layout, marking rules such as quoting a spec point verbatim or marking
   items info vs decision). Write each into AGENTS.md under the project's conventions
   section (create it on first use), one line per pattern, quote-anchored:
   `- <rule, one line> (source: Q...)`. Dedupe against existing conventions the same way.
5. Squash the quote book (QUOTES.md): a quote whose content now lives in a high-authority
   artifact (project lessons, project docs, the decision log) is REMOVED - numbering never
   shifts, removed numbers stay as gaps, every removal cites this reflection order; guard
   approve after. The book must hold only not-yet-embodied source material.
6. Mistakes about the skill/protocol itself (not project-specific) additionally go to the
   Session mistakes section of the parent architect-partner SKILL.md.
7. Finish with a commit: work in the directory is finished only with a commit.

## Quote-book intake (prevention, not cleanup)

The book never becomes a 1000-quote dump: at RECORDING time only project-important quotes
enter - a quote that changes a decision, a design or an artifact. Session flow commands,
superseded questions and chat noise are never recorded. Compaction later is the safety net;
intake discipline is the primary defense.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Lessons file bloats with non-lessons | HARD GATE violated | Delete the padding; only confirmed mistakes |
| Vague lessons ("be more careful") | No concrete check | Rewrite: the check must name the exact action |
| Lesson contradicts the canon | No quote check | Anchor the prevention in a quote or drop it |
| Same lesson re-added next session | No dedupe | Merge into the existing entry |
| Quote book only grows, never shrinks | No compaction step | Squash embodied quotes at every reflection |
| Important quote deleted, content nowhere | Removed before embodiment | Remove only what already lives in an artifact |
| Unconfirmed style preference written as a convention | Pattern gate violated | Ask the user; a pattern enters only with a locking quote |

## Session mistakes

None yet.
