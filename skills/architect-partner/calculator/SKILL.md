---
name: architect-calculator
description: "Use when an architect-partner project needs sizing or metrics math: understanding the system being sized, locking the mandatory inputs, creating or updating the input constants file, researching unknown constants, writing the human-readable justification, or rendering the final xlsx calculator. Pipeline: understand system -> lock mandatory inputs -> constants file -> research -> constants recursion -> justification -> xlsx render; the workbook is only drawn when every variable is known - math is never invented there."
---

# Architectural calculator - constants-first sizing pipeline

The calculator is the most responsible artifact of the project: its numbers drive hardware and
cost decisions. The math is NEVER invented in the workbook. It is built bottom-up through five
stages; each stage gates the next.

## Pipeline (user orders 2026-08-25: mini-ERIR sizing session; understand-then-lock first)

0. SYSTEM UNDERSTANDING - first understand the system the calculator is made for. The agent
   states its model of the dataflow and layers (who writes what, in what order) and the user
   corrects it. A wrong mental model invalidates every downstream number - the user's
   correction here is the most valuable input of the whole pipeline. No artifacts.
1. MANDATORY INPUTS LOCK - strictly fix the data without which nothing can be computed: the
   base inputs every number traces to (inflow per period, volumes per store, retention,
   ratios). Locked with the user; a missing mandatory input blocks all calculation - it is a
   question, never a filled-in guess.
2. CONSTANTS FILE - the single source of truth. A python file holding constants only:
   - ONLY constants. No explanatory comments, no essay text, no argumentation - only group
     header comments (`# TIME`, `# PRODUCTION DATA`, `# RATIOS`). Argumentation lives in
     chat and in the justification stage.
   - No magic numbers: every literal is a named constant (`0.60` -> `S3_FILE_SHARE_OF_INCOME`,
     `6` -> `S3_WINDOW_MONTHS`). A number appears only as the value of a named constant.
   - Measured per-entity data goes in dicts (hashmaps); totals and ratios are COMPUTED from
     them, never re-typed.
   - User's exact variable names are honored. Python forbids identifiers starting with a
     digit (`12MONTH` -> `MONTH12`) - state that to the user, do not silently rename.
   - Derived constants reference their sources and are defined after their dependencies.
   - Dead constants (unreferenced, superseded, `None` placeholders) are removed.
3. RESEARCH - fill UNKNOWN constants. Sources: measurements from prod (SQL over partitions,
   MinIO listing, counters), official vendor docs for ratio norms. Every constant gets a
   status argued in chat: measured / user-given / derived / assumption.
4. CONSTANTS RECURSION - research results update the constants file; new gaps surface; loop
   until every constant that matters has a value. Two or three passes is the normal state,
   not a failure. This is where the pipeline spends most of its time.
5. JUSTIFICATION - human-readable text (Telegram message, doc) drawn FROM the constants:
   every number in the text traces to a named constant. The user owns the wording; the agent
   proposes phrasing, the user edits the file. The agent NEVER full-rewrites a user-edited
   file - targeted edits only, re-read first.
6. XLSX RENDER - only when every variable is known and the math is locked (stage 5 done).
   The workbook RENDERS the locked computation; it adds no math of its own.

## HARD GATE - the workbook

- Not started until stage 4 is done and the user has named the desired final cells.
- ALL math is prototyped as a throwaway python script in /tmp and cross-checked by a second,
  independent computation before any xlsx exists.
- xlsx formulas carry the locked constants' values; no magic numbers in formulas.
- Delivery gate: `check.py` AND `check_usage.py` AND `unwind.py` all pass, and the
  justification text's numbers match the constants (extract-and-compare).
- Nothing beyond the user's named blocks: no helper cells, no decorative text, no own
  constants block inside the workbook.

## HARD rules (from the mini-ERIR session)

- Units: binary (TiB = 2^40) and decimal (TB = 10^12) are different scales - name the scale
  in the variable name or state it. A TiB/TB mix is a ~10% error that survives every check
  because it is consistent.
- Replication and erasure coding are explicit named multipliers, applied per system
  according to its architecture:
  - Kafka: replication factor multiplies disk (each segment stored N times).
  - MinIO: erasure coding multiplies physical disk; the ratio is measured from the prod
    topology and does NOT transfer to a different topology.
  - ClickHouse replicas SERVE queries: disk, RAM and CPU all multiply by replica count.
  - Greenplum mirrors do NOT serve queries: disk multiplies, CPU and RAM do not.
- A number in a variable cell is measured, user-given, or derived from those - never an
  invented "realistic" value. An assumption enters only with the user's ok and is flagged in
  the justification text.
- The user edits artifacts themselves; agent edits are targeted (`edit`), never a full-file
  rewrite of a file the user touched.
- Vocabulary is locked by the user's accepted terms; introducing a synonym (e.g. "зеркала"
  instead of the user's "репликация") is a defect.

## Scripts

Absolute paths (all relative to this sub-skill's directory `calculator/`):

| Script | Purpose |
|---|---|
| `~/.omp/agent/managed-skills/architect-partner/calculator/scripts/create.py` | Build the skeleton workbook from the locked spec with the palette (new books only; never re-run on an existing book). |
| `~/.omp/agent/managed-skills/architect-partner/calculator/scripts/check.py` | Evaluate every formula, fail on any error value (#N/A, #ERR, dangling references). |
| `~/.omp/agent/managed-skills/architect-partner/calculator/scripts/check_usage.py` | Fail on any numeric variable cell referenced by no formula (literals exempt; passive-by-design pass via --allow and are named in the delivery note). |
| `~/.omp/agent/managed-skills/architect-partner/calculator/scripts/unwind.py` | Print the full computation tree (label, formula, value) of final cells; no args = all true finals. |

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| User's cleanup clobbered | Full-file rewrite over a user-edited file | Targeted edits only; re-read before every edit |
| Calculator built for the wrong system | Agent's mental model of the dataflow never checked | Stage 0: state the model, let the user correct it before any math |
| Numbers computed with a mandatory input missing | Calculation started before the input lock | Stage 1: lock base inputs first; a missing input is a question |
| Constants file carries essays | Argumentation written into the file | Only group headers; argumentation to chat |
| Magic numbers in formulas | No naming discipline | Every literal a named constant |
| Workbook math differs from constants | Math invented in the xlsx | Render only; prototype and cross-check in /tmp first |
| Everything ~10% off | TiB and TB mixed consistently | Name the scale; keep one everywhere |
| CPU/RAM doubled wrongly | Replication semantics not thought through | Per system: who serves queries (CH replicas yes, GP mirrors no) |
| Dead numeric variables after model change | Nothing re-checks usage | check_usage.py in the delivery gate |
| Constant used before defined | Import-order error | Define dependencies first; verify in a fresh python process |

## Current state

| Date | Note |
|---|---|
| 2026-08-25 | Rewritten from scratch after the mini-ERIR sizing session. The old project-specific workbook spec (parquet/codec/compression chains, fixed sheet order) is removed; the skill now encodes the constants-first pipeline (0-5) and the constants-file discipline. Scripts and the delivery gate are kept. |

## Session mistakes

- 2026-08-25: presented a dataflow with wrong layer shares (treated ФХ as the source of everything, ignored the highload -> Kafka -> ФХ -> ETL -> ODS Cloudberry -> DS -> CH chain); the user corrected it ("ты не понимаешь архитектуру"). Prevention: stage 0 - state the dataflow model first and get the user's correction before any percentage.
- 2026-08-25: full-file rewrite of message.txt clobbered the user's cleanup (Kafka/MinIO lines); he had to re-fix. Prevention: targeted edits only on user-edited files.
- 2026-08-25: formal-language pass changed word order and register beyond the asked orthography ("Пускай"->"Пусть", "прод"->"продакшена", "софт"->"ПО"); user reverted. Prevention: fix exactly what was asked, list the rest as options.
- 2026-08-25: introduced "зеркала" where the user's term is "репликация". Prevention: lock vocabulary from the user's accepted terms.
- 2026-08-25: constants referenced before definition; an eval kernel cached a stale module. Prevention: define dependencies first; verify with a fresh python process.
- 2026-08-25: Cloudberry segments initially computed from the mirrored disk, doubling CPU/RAM wrongly; mirrors do not serve queries. Prevention: replication semantics per system before writing formulas.
