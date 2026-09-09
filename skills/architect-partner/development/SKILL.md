---
name: architect-development
description: "Use when ordering any work to workers in the architect-partner protocol: research, implementation, experiments, or benches; when writing a work order (постановка); when a worker delivered and the architect must accept or reject; or when a worker refuses and the refusal must be triaged. Encodes the zero-freedom worker contract: controlled autocomplete and template filling only."
---

# Development - work orders and workers

The architect never produces in the development domain; he writes orders and accepts results.
Workers are controlled autocomplete: they fill templates and assemble, they do not decide.
Freedom shrinks down the chain: the CTO decides, the architect translates and accepts, the
worker executes exactly what the order determines - or refuses.

## HARD GATE

- Work exists only against a work order anchored to TZ / QUOTES / CODEX quotes. No order, no work.
- A worker delivery is either (1) the artifact exactly per the order's template and scope, or
  (2) a refusal report. Nothing else is a valid delivery.
- The architect-domain files (`TZ.md`, `QUOTES.md`, `REF.md`, `CODEX.md`, decision log) are
  READ-ONLY to workers. Touching them is a failed run.

## Lanes

| Lane | Directory | Output | Verifier |
|---|---|---|---|
| research | `research/` | distillate per `scripts/distillate-template.md` (parent skill) | architect checklist; spot-checks |
| impl | `impl/` | code in the repository locations named by the order | the `CODEX.md` verifier for that module (tests / types / build) must pass |
| experiments | `experiments/` | run log + result file under the pre-flight lock | acceptance criteria of lock #3 |
| benches | `benches/` | measurement report: numbers + provenance + reproduction | methodology lock #2; numbers only from the run |

## Work order (постановка)

Template: `development/workorder-template.md`. An order names: id and lane; its beads issue
(`bd issue: <id>` - the flow ledger, one issue per order); its series and the order ids it
depends on; the purpose anchor (the WHY -
a TZ line or `[Q:id]`, per Standing rule 8 of the parent skill); source anchors (TZ lines,
`[Q:id]`, REF node ids, CODEX sections); exact scope (files, functions, directories - paths);
the template or format to fill; constraints (the bans, verbatim); the verifier command and
expected outcome; the output location; the refusal protocol. An order that cannot name all of
these is not written - the missing decision goes back to the CTO as a `[GAP]`.

## Series (fan-out)

Orders under one epic form a series. The series is cut by protocol; improvising the cut is
the architect's defect, not the workers':

1. DAG first. Before any order is written, dependency edges between the epic's issues are
   registered (`bd dep add`). An order is issued only when its dependencies are closed; a
   series without a registered DAG is not fanned out.
2. Disjoint write scopes. Concurrently running orders must not overlap in write paths. An
   overlap is resolved before launch - serialize the orders or shard into separate
   worktrees. Shared read context is not a conflict.
3. Pilot before fan-out. The first 2-3 orders of a new series run the full cycle before the
   rest is issued. A pilot is graded on obedience to the order, not on output quality; the
   only surviving output is amendments to the order template or the codex (through the CTO -
   both frozen), never self-applied.
4. Backpressure caps. Every shared resource carries an explicit cap: exactly one worker
   runs the build/test verifier at a time; search and write parallelism is limited only by
   what the CTO set.
5. Integration gate. After a batch lands, the architect runs the system-wide verifier named
   in `CODEX.md`; its output is a machine queue sliced by module and returns as follow-up
   orders - hand-fixing code is a lane violation. The series done-gate is contract level:
   every acceptance criterion of the TZ mapped to a delivery and verified.
6. Batch acceptance. At a phase gate the architect accepts the batch: the global verifier
   output verbatim plus spot-checks against orders. Per-order acceptance remains mandatory
   for pilots, refusals, and any order the CTO flagged.

## Worker contract (zero-freedom autocomplete)

1. Produce strictly inside the order: the named template, the named vocabulary, the named
   scope. Anything else is out of scope - not done, not commented on.
2. Search before producing: before writing anything, verify via repo search (subagents for
   wide reads) that the target is actually absent. "Not implemented" is a checked fact, never
   an assumption - search blindness produces duplicates, and a duplicate is a failed run.
3. No decisions: no comments in code, no renames, no dependencies beyond `CODEX.md`, no
   "small improvements", no fixes outside the order. If the code seems to need a comment to
   be understandable, that is an underspecified-order signal - refusal report, not a comment.
   An adjacent problem is reported in the completion report, never fixed.
4. Fail closed: the moment the order + codex + repo state do not fully determine the next
   line of output - STOP and write a refusal report: what is blocked, what is missing, which
   options exist. A guess dressed as work is the cardinal sin.
5. Completion report rides on every delivery: order id, what was produced, verifier output
   (verbatim), deviations (none / refusal reference).
6. Architect-domain files: read-only. Commits, pushes, deploys: never on own initiative.
7. In beads (`bd`): write ONLY the state of your own order issue - claim it, note it, close
   it. Foreign issues, epics, and memories: read-only.

## Refusal triage (architect)

A refusal is a codex or order defect signal, not a worker failure. Re-read the order and
decide: fix the order, extend the codex (through the CTO - it is frozen), or kill the task.
The triage result goes to the CTO with the refusal attached. A worker that refused without
attempting the derivable parts, or refused on trivia the codex already answers, is a
bad-order or bad-worker signal - report which, to the CTO.

## Acceptance (architect)

1. The verifier ran and passed - its output is quoted verbatim into the acceptance report.
2. Deliverable-to-order diff: every element maps to an order or codex anchor; an unanchored
   element is removed or the run is rejected.
3. Domain check: no architect-domain files touched; scope equals order scope.
4. REJECT on any miss -> the run is FAILED; reported to the CTO as a fact; retry with a
   corrected order, or kill.
5. Close the issue: `bd close <id>` carries the acceptance reference; a refusal reopens the
   triage instead.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Worker invented a design, name, or dependency | Order underdetermined; codex hole | REJECT; extend the codex via the CTO; re-issue the order |
| "Helpful" comments or refactors appeared | Autocomplete contract violated | REJECT; the bans go into every order verbatim |
| Worker "just did it" past a blocker | Fail-closed not enforced | REJECT; the refusal path is the only legal exit |
| Architect wrote the code himself | Lane violation | Delete; re-issue as an order |
| Delivery accepted without a verifier run | Acceptance skipped | An acceptance report without verbatim verifier output is invalid |
| Refusals flood | Orders omit answers the codex already has | Triage: orders point at codex sections explicitly |
| Worker touched `TZ.md`/`QUOTES.md`/`REF.md`/`CODEX.md` | Domain boundary violated | `guard.sh check`; revert on user order; re-issue the order |
| Worker mutated foreign bd issues | bd scope not fixed in the order | REJECT; an order names the single writable issue id |
| Two accepted orders conflict at integration | Concurrent write scopes overlapped; no DAG | REJECT the batch; disjoint scopes or serialize; register deps; re-run |
| Worker produced a duplicate of existing code | "not implemented" assumed without search | REJECT; search-before-produce goes into every order verbatim |
| Systemic defects across a fanned-out series | No pilot; rules untested at small N | Halt the series; pilot 2-3 orders; amend template/codex, then re-fan |
| Series delivered, TZ acceptance unverified | No integration gate | Run the codex system-wide verifier; map results to TZ before done |

## Session mistakes

None yet.
