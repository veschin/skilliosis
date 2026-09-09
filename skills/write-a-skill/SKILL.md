---
name: write-a-skill
description: "Use when asked to create, improve, or audit an OMP skill — managed/global or local/project. Picks the right install location so a project skill never lands in the global root."
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
**Operational rules, NOT reference.** Required frontmatter (name + **trigger-first description**: answers "when do I reach for this skill?", not "what is it"). Required sections: HARD GATE · Current state (dated table) · Failure modes (symptom->cause->fix) · Session mistakes (ALWAYS present, empty = none yet) · Scripts table. Max 150 lines.

## Phase 4 - Install (path follows Phase 0)
- **Managed**: `manage_skill` create/update with `name` + `description` + `body`; scripts via `write`/`bash` to `~/.omp/agent/managed-skills/<name>/scripts/`; verify in skills list; smoke `read skill://<name>`.
- **Local**: `write` the SKILL.md (with `name:`+`description:` frontmatter) to `<repo>/.omp/skills/<name>/SKILL.md`; scripts to `<repo>/.omp/skills/<name>/scripts/`. No `manage_skill` call at all. Discovery picks it up at the next session start (or after a session restart).

## Craft - what makes a skill predictable
**Invocation = the description - say WHEN, not WHAT.** OMP surfaces every skill's description in the system-prompt skills list - that list IS the router. The description MUST answer "when do I reach for this skill?" - NOT "what does this skill contain?". Lead with the trigger (the situation that makes the agent pick this skill); follow with a compact hint of what it covers. BAD: `Audit and control the metamio dev stand` (describes WHAT). GOOD: `Use when the stand is down or needs bringing up, after a reboot, or to free ports + RAM` (says WHEN). Do NOT build a router skill; one trigger per branch (synonyms renaming one branch are *duplication* - collapse them); cut identity already in the body.

**Completion criteria.** Each step ends on a checkable, and where it matters *exhaustive*, condition ("every modified file accounted for", not "produce a change list"). A vague criterion invites *premature completion*.

**Information hierarchy.** In-skill step (ordered action) > in-skill reference (on-demand fact) > external reference (linked file, loaded by pointer). Push down via *progressive disclosure* only when the top bloats; keep a concept's definition + rules + caveats *co-located*.

**Leading words.** A compact pretrained concept (_tight_ loop, _red_ signal, _relentless_) anchors a region of behaviour in the fewest tokens and sharpens invocation when the same word recurs in prompts/docs. Collapse restatements into one leading word.

**Single source of truth.** One authoritative place per meaning - a one-place edit.

**Absolute paths.** State every script's absolute path — `~/.omp/agent/managed-skills/<name>/scripts/<script>` (managed) or `<repo>/.omp/skills/<name>/scripts/<script>` (local) — both in the Scripts table and in a prominent line near the top of the body. The agent invokes it directly; it never searches, computes, or guesses the path. A relative `scripts/foo` in a skill body is a bug.

## Failure modes (diagnose a struggling skill)
- **Premature completion** - step ends before genuinely done; attention slips to "being done". Fix: sharpen the completion criterion first (cheap, local); only if irreducibly fuzzy *and* you observe the rush, split the sequence.
- **Duplication** - same meaning in >1 place. Collapse to one source.
- **Sediment** - stale layers nobody prunes; the default fate without a pruning habit.
- **Sprawl** - too long even if every line is live. Cure: disclose reference behind pointers, split by branch/sequence.
- **No-op** - a line the model obeys by default. Test: does it change behaviour vs the default? If not, delete the whole sentence.
