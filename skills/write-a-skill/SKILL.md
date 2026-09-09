---
name: write-a-skill
description: "Use when asked to create, improve, or audit an OMP skill — managed/global or local/project. Picks the right install location so a project skill never lands in the global root, and decides the reuse/ mirror for spawn binding."
---

# Writing a Skill

A skill wrangles determinism out of a stochastic system. The root virtue is **predictability** -
the agent taking the same *process* every run. Phases gate each other; the Craft section is what
makes the result actually good. (Craft vocabulary adapted from Matt Pocock's writing-great-skills.)

## Phase 0 - Scope: local or managed?
Decide the blast radius FIRST — it fixes WHERE the skill lives and HOW it installs. Two kinds, never mixed:

- **Managed (global)** — `~/.omp/agent/managed-skills/<name>/`. Reusable across ALL your work, not tied to one repo: a CLI/API workflow (`gum`, `typst`, `confluence`), a cross-cutting method (`harden-plan`). Install via `manage_skill` (Phase 4). `manage_skill` is **GLOBAL-ONLY** — it has no local option and always writes under the global root.
- **Local (project)** — `<repo>/.omp/skills/<name>/`. Tied to ONE repo; meaningless outside it (a project's deploy workflow, its bespoke conventions, its repo-specific tooling). Install via the `write` tool to `<repo>/.omp/skills/<name>/SKILL.md`, frontmatter `name:`+`description:` inline. Scripts in `<repo>/.omp/skills/<name>/scripts/`. **NEVER use `manage_skill` for a local skill** — it silently writes to the global root, which is the exact bug this phase exists to prevent.

Test: "if this repo vanished, would the skill still mean anything?" No → local. Yes → managed.

## Phase 1 - Understand
1. Read external docs (web_search + context7). Never rely on memory.
2. Live-enumerate the system. Docs lie, live state is truth. Cross-check: every running service has a skill entry.
3. Read all skills touching this domain. Fix contradictions before adding new ones.
4. List dangerous ops (widest blast radius) and repetitive ops (done manually several×/week).

## Phase 2 - Experiment
1. Scout scripts first (read-only, safe anytime). JSON via `jq -n` (bash) or `json.dumps` (python). `set -uo pipefail`, never `-e`. Must work degraded - every field populated or null.
2. Test scouts live in degraded state. No silent omissions.
3. Action scripts second: backup -> mutate -> verify -> rollback. NEVER auto-restart services (print "run X to apply"). Restart-capable = HARD GATE marker. Must have `--dry-run` or read-only equivalent.
4. Test actions: `bash -n` isn't enough. Test dry-run, rollback, degraded.

Conventions: `scripts/` subdir; scout = `scout-` prefix, never mutates; action = descriptive verb; pick the right language (bash+jq for SSH/parse, python for API/complex); JSON to stdout only.

## Phase 3 - Write SKILL.md
**Operational rules, NOT reference.** Required frontmatter (name + **trigger-first description**: answers "when do I reach for this skill?", not "what is it"). Required sections: HARD GATE · Current state (dated table; a single dated line suffices for procedural skills) · Failure modes (symptom->cause->fix) · Session mistakes (ALWAYS present, empty = none yet) · Scripts table. Max 150 lines.

## Phase 4 - Install (path follows Phase 0)
- **Managed**: `manage_skill` create/update with `name` + `description` + `body`; scripts via `write`/`bash` to `~/.omp/agent/managed-skills/<name>/scripts/`; verify in skills list; smoke `read skill://<name>`.
- **Local**: `write` the SKILL.md (with `name:`+`description:` frontmatter) to `<repo>/.omp/skills/<name>/SKILL.md`; scripts to `<repo>/.omp/skills/<name>/scripts/`. No `manage_skill` call at all. Discovery picks it up at the next session start (or after a session restart).

## Phase 4.5 - Reuse mirror (spawn binding)
Subagents start blank and inherit nothing; Gate R points them at `~/.omp/agent/skills/reuse/`
(`INDEX.md` there is the coverage list). Right after install, decide the mirror. The skill
obviously belongs in reuse when it is ANY of:
- a Gate procedure every task must follow (ready-first / ui-kits / tailwind / doc-standards class);
- a ready-tool workflow that replaces hand-rolling (gum / vhs / beads / typst / context7 class);
- a method a spawned agent must be able to follow on ANY project (debugging recipe, TDD,
  code-amount discipline, plan hardening).

No mirror for: live personal systems - env, jira, confluence, google-sheets (operations gated by
explicit user request, per INDEX.md "Out of scope"); user-private content (quote books, REF);
project-local skills (meaningless outside their repo); pure explainers with no operational rules.

Mirror procedure (distillate, NOT a raw copy):
1. Write `~/.omp/agent/skills/reuse/<name>.md`, no frontmatter: title + one-line what it replaces,
   `## When` / `## Entry` / `## Essentials` / `## Pitfalls`, footer
   `Full skill: skill://<name> (source: <absolute skill path>)`. Only essentials; facts from the
   skill, never from memory.
2. Add one row to the matching table in `~/.omp/agent/skills/reuse/INDEX.md` (Gates or Tools).
3. The skill file stays the single source of truth: after ANY later edit of the skill, re-mirror
   in the same turn; a stale mirror is worse than none. State in the skill's Current state line
   that a mirror exists and where.

## Research preservation
When the user ran research and asks to keep it (e.g. "сохрани ресерч", "положи в скилл"), and the topic maps to an existing skill:
- Update that skill or create a `researches/` folder inside it; add ONE pointer line in SKILL.md naming the folder; write an index `researches/README.md` (topic table, `NN-topic.md` files).
- SKILL.md states that research exists (pointer), so future work loads the fact sheet instead of re-searching.

Research files are a HARD GATE distillate:
- Dry facts only: one fact = one verbatim quote from one source; no opinions, conclusions, or recommendations.
- Authority stated explicitly per claim (official vendor / community measurement / aggregator); extrapolations marked as such.
- SEO/scam/spam sources never enter; fabricated or unverifiable facts never enter (mark [unverified]/[estimate] or omit).

## Craft - what makes a skill predictable
**Invocation = the description - say WHEN, not WHAT.** OMP surfaces every skill's description in the system-prompt skills list - that list IS the router. The description MUST answer "when do I reach for this skill?" - NOT "what does this skill contain?". Lead with the trigger (the situation that makes the agent pick this skill); follow with a compact hint of what it covers. BAD: `Audit and control the metamio dev stand` (describes WHAT). GOOD: `Use when the stand is down or needs bringing up, after a reboot, or to free ports + RAM` (says WHEN). Do NOT build a router skill; one trigger per branch (synonyms renaming one branch are *duplication* - collapse them); cut identity already in the body.

**Completion criteria.** Each step ends on a checkable, and where it matters *exhaustive*, condition ("every modified file accounted for", not "produce a change list"). A vague criterion invites *premature completion*.

**Information hierarchy.** In-skill step (ordered action) > in-skill reference (on-demand fact) > external reference (linked file, loaded by pointer). Push down via *progressive disclosure* only when the top bloats; keep a concept's definition + rules + caveats *co-located*.

**Leading words.** A compact pretrained concept (_tight_ loop, _red_ signal, _relentless_) anchors a region of behaviour in the fewest tokens and sharpens invocation when the same word recurs in prompts/docs. Collapse restatements into one leading word.

**Single source of truth.** One authoritative place per meaning - a one-place edit.

**Absolute paths.** State every script's absolute path — `~/.omp/agent/managed-skills/<name>/scripts/<script>` (managed) or `<repo>/.omp/skills/<name>/scripts/<script>` (local) — both in the Scripts table and in a prominent line near the top of the body. The agent invokes it directly; it never searches, computes, or guesses the path. A relative `scripts/foo` in a skill body is a bug.

**Artifact-producing procedures.** Encode a standing rule as an ordered procedure that ends in a forced observable artifact - a one-line decision record, a filled template, a checklist the session must contain. Advice without output is ignored under load; artifacts are checkable by the model itself (self-check) and by the user. This sharpens the no-op test: a rule that produces no output is a no-op.

**Escape valves.** An absolute rule with no listed exceptions trains the model to rationalize ignoring it (it "knows" *always* can't be true). Ship exception tags/conditions with the rule and require the tag to be stated explicitly when invoked. No tag = no exception.

**Top-and-tail the load-bearing rule.** HARD GATE as the first line of the body; echo the check as the final line ("self-check before yielding: ..."). Conflicting instructions resolve toward the ends of the context - occupy both ends with the same rule.

**Dated catalogs verify at use.** Any list of named tools/libraries/formats carries "defaults; verify currency at use time" - catalogs age silently and a stale catalog is worse than none.

## Failure modes (diagnose a struggling skill)
- **Premature completion** - step ends before genuinely done; attention slips to "being done". Fix: sharpen the completion criterion first (cheap, local); only if irreducibly fuzzy *and* you observe the rush, split the sequence.
- **Duplication** - same meaning in >1 place. Collapse to one source.
- **Sediment** - stale layers nobody prunes; the default fate without a pruning habit.
- **Sprawl** - too long even if every line is live. Cure: disclose reference behind pointers, split by branch/sequence.
- **No-op** - a line the model obeys by default. Test: does it change behaviour vs the default? If not, delete the whole sentence.
- **Trigger miss** - the skill exists but did not fire in the situation it was written for. The description lacks the situation's leading words; rewrite the description from the observed miss, do not pile up synonyms.
