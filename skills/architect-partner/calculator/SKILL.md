---
name: architect-calculator
description: "Use when creating or updating the architectural data calculator workbook (xlsx) of an architect-partner project - record sizing through kafka / file storage / clickhouse with compression chains, codec bonus and hardware blocks - or when advising how to compute the project's metrics, sizings and process volumes, and how to verify that every number is correct. Locks the variable list and the desired final cells BEFORE any workbook; prototypes all math as a throwaway python script in /tmp first; owns the exact formatting palette, cell typology, units convention, and the create/verify scripts."
---

# Architectural calculator - creation and verification rules

The calculator is the most responsible artifact of the project: its numbers drive hardware and
cost decisions. This sub-skill advises how to compute the project's metrics, sizings and
process volumes, and how to verify that everything is computed correctly.

## Precondition (hard, user order 2026-08-21)

The workbook is NOT started until the user has given BOTH lists: the variables and the desired
final cells. Without both there is nothing to build against - asking for them is the correct
next step; building anything is not.

## Pipeline (user order 2026-08-21)

1. LOCK - variables + desired finals, quote-anchored per the parent-skill THE RULE.
2. PROTOTYPE - write ALL computations as a throwaway python script under /tmp and run it;
   cross-check the key totals a second, independent way and iterate until everything
   converges. The xlsx is never the place where the math is invented.
3. BUILD - only a converged prototype is transcribed into the workbook (create.py skeleton
   for new books; never re-run create.py on an existing book).
4. GATE - check.py AND check_usage.py AND unwind.py all pass before delivery. Automation must
   catch ~99% of problems: unused variables, wrong formulas, broken references, scale errors.

One sheet. Sections in fixed order (model as locked with the user, 2026-08-20):

1. глобальные переменные - parquet compression levels table (reference for level choice),
   message layout-compression percent (SINGLE compression value, never a chained product),
   kafka compression percent, db base compression percent, replication multipliers per system
   (db, kafka, file store).
2. переменные под источник - name, records per day, growth percent (source-owned and passive
   by design: the OWNER raises records per day by it; formulas never reference it), record
   weight, share of the fh record needed by the db, business redundancy multiplier.
3. формульные веса - fh record weight = raw x (1 - layout compression), single compression;
   db raw weight; db base-compressed weight; db weight with redundancy.
4. итоговые сводные ячейки - columns час/сутки/месяц/год (24/30/365 embedded); records row
   in millions; system rows (kafka, fh, clickhouse) in TB; volumes INCLUDE replication.
5. итоговые сводные ячейки железа - rows per system (kafka, clickhouse, file store); ONE
   years-multiplier cell applied to every row; SSD = year-TB x years multiplier (the stored
   data itself - NO disk norm); CPU = SSD x cpu-cores-per-TB norm; RAM = SSD x ram-GB-per-TB
   norm / 1000; norms are sourced variables; growth NEVER enters hardware formulas.
6. бонус - codec table (name + compression percent), codec rows and saved-TB rows in TB.
   Pipeline: raw share keeps base compression + codec share compressed by the codec; savings
   = share x (codec - base). The x1000 kb-to-bytes factor MUST be present in every
   weight-to-TB formula. Cross-check: codec row + savings row = base db volume row.

## HARD rules

Cell typology (the user's systematization; colors are theme-based, EXACT):

| Cell type | Fill | Font |
|---|---|---|
| Section headers | theme 1, tint 0.35 | theme 0 (white) |
| Summary / table headers | theme 6, tint 0.8 | theme 1 |
| Variable labels | theme 3, tint 0.8 | theme 1 |
| Values | none | plain |
| Literals (text-valued cells) | none | italic |

- No borders; Calibri 11; theme+tint colors, never raw RGB.
- Units: every dimensioned label carries its unit after a comma
  ("записей в сутки, миллионы", "вес записи в кафке, кб").
- кб = 1000 bytes; ТБ = 10^12 bytes; records counted in millions.
- Every summary cell: ROUNDUP(x, 2). Month = 30 days, year = 365 days, hour = day/24 -
  embedded in formulas, never visible variables.
- Formulas reference cells; user-entered values are never duplicated inside formulas.
- NEVER change column widths the user has touched. On creation, widths come from the longest
  content; on updates widths are not touched at all.
- A number in a variable cell is either measured, sourced, or explicitly marked as a
  placeholder pending research - invented "realistic" values are forbidden.
- DELIVERY GATE: check.py AND check_usage.py AND unwind.py all pass. check_usage: every
  numeric cell must be referenced by some formula (text literals exempt; passive-by-design
  numerics pass via --allow and are named in the delivery note).
- Never rewrite a formula range with one uniform template: per-column factors (the RAM /1000)
  die silently. After any batch rewrite, diff every column and unwind the finals.
- Every new section ships with an arithmetic cross-check against an existing row
  (codec + savings = base volume).
- The workbook ships only after check.py passes (no #N/A, no #ERR, no dangling references).
- Nothing beyond the user's named variables and blocks: an element without a spec quote is
  removed or asked about. Everything in the workbook carries meaning: no extra words, no
  extra cells - no helper cells, no decorative text, no own constants block.

## Scripts

Script paths are relative to this sub-skill's directory (`calculator/`).

| Script | Purpose |
|---|---|
| `scripts/create.py` | Build the skeleton workbook from the canonical spec with the palette (new books only). |
| `scripts/check.py` | Evaluate every formula, fail on any error value; optional width freeze comparison. |
| `scripts/check_usage.py` | Fail on any numeric variable cell referenced by no formula (literals exempt; --allow for passive-by-design). |
| `scripts/unwind.py` | Print the full computation tree (label, formula, value) of final cells; no args = all true finals. |

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Workbook shows #N/A / #ERR | Shipped without evaluation | check.py before every delivery |
| User's widths overwritten | Creation logic run on an existing book | create.py only for new books |
| Dead numeric variables after model changes | Nothing re-checks usage | check_usage.py in the delivery gate |
| Section plausible but 1000x off (kb vs bytes) | Scale never cross-checked | unwind.py + arithmetic cross-check rule |
| Workbook started with no variable/final lists from the user | Precondition skipped | Ask for both lists; build nothing until they are quoted |
| Math invented inside the xlsx | Prototype stage skipped | /tmp python prototype converges first |

## Current state

| Date | Note |
|---|---|
| 2026-08-19 | Extracted from a real project calculator.xlsx reworked by the author; theme palette read from that file; hardware block per its example. |
| 2026-08-20 | Model relocked per user: hardware = data x replication x years (SSD IS the data; no disk norms), CPU/RAM from SSD via per-TB norms, growth is a passive source variable, single fh compression, redundancy calibrated from the project's own prod-table audit measurement. check_usage.py + unwind.py added after the session post-mortem. |
| 2026-08-21 | Open-source pass: script paths made relative to the sub-skill directory, project identifiers and private numbers removed. |
| 2026-08-21 | Precondition + pipeline added per user order: no workbook before the user gives the variables and the desired final cells; all math prototyped as a throwaway python script in /tmp and cross-checked before any xlsx; advisory role fixed (metrics, sizings, processes, verification). |

## Session mistakes

- 2026-08-20: built hardware norms with inverted semantics (capacity-per-resource instead of
  resource-per-TB; divided instead of multiplying) - implausible totals. Fix: norms are
  resource per 1 TB, totals multiply. Prevention: state each norm's semantics against its
  label before writing formulas.
- 2026-08-20: batch-rewrote formulas column-uniformly and silently dropped the RAM /1000
  (GB->TB). Fix: per-column diff after every rewrite. Prevention: never one template for a
  formula range with per-column factors; unwind the finals after.
- 2026-08-20: bonus section shipped 1000x under (kb-to-bytes x1000 missing) from day one;
  checks caught references, not scale. Fix: x1000 + cross-check (codec + savings = base).
  Prevention: delivery gate now includes unwind.py.
- 2026-08-20: accepted an unsourced user variable without checking the project's own audit
  measurements. Fix: calibrated it from the audit. Prevention: an unsourced user variable is
  a question; check project measurements first.
