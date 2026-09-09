# Repository Guidelines

## Project Overview

skilliosis is a public, one-way mirror of the author's favorite daily-use
[OMP (Oh My Pi)](https://github.com/can1350/oh-my-pi) agent skills, kept in
`~/.omp` on the author's machine. This repo contains no authored code beyond `README.md` and this file. The
mirror toolchain - `sync` (Python) + `skills.toml` (what gets published) - is
**local-only**: deliberately not tracked and gitignored, because it encodes
the author's `~/.omp` layout. It exists only in the author's working copy of
this repo; a fresh clone cannot run `./sync`.
The two mirrored skills encode the author's machine (paths, versions) by
design.

## Architecture & Data Flow

Strictly one-way pipeline: `~/.omp` -> `./sync` -> this repo.

1. `skills.toml` is the single source of truth - one `[[skill]]` block per
   published skill (`name`, `source` = `managed` | `user`, optional `exclude`).
2. `sync` scans the configured sources for `*/SKILL.md` and `*/*/SKILL.md`
   (a nested dir counts only as a category when it has no own `SKILL.md`,
   so sub-skills like `architect-partner/calculator` never sync standalone;
   `managed` wins name collisions with `user`).
3. Copy semantics per skill:
   - source skill is itself a git repo -> copy **only `git ls-files` tracked
     files** (this is what keeps `QUOTES.md`, `REF.md`, `.arch-guard/` etc.
     out of the public copy);
   - otherwise -> full directory walk minus exclude patterns
     (fnmatch on any path part; global defaults `.git`, `__pycache__`,
     `*.pyc`, `.DS_Store` + per-skill `exclude`).
4. `skills/<name>/` is replaced wholesale (rmtree + fresh copy - copy2 keeps
   modes), dirs not in the config are pruned. The README has **no generated
   skill list since 2026-09**: per-skill sections are hand-written, and
   `sync` skips README regeneration (with a warning) when the
   `<!-- skills:start -->` / `<!-- skills:end -->` markers are absent.

Consequence: **never edit anything under `skills/`** - the next `./sync`
overwrites it. Edit the skill in `~/.omp`, then sync and commit. When
publishing a new skill, add its hand-written README section yourself.

## Key Directories

- `skills/` - generated mirror output. Read-only by convention.
- `skills/<name>/SKILL.md` - a skill's entry point (loaded by OMP by name).
- `skills/<name>/scripts/` - runnable helpers and self-tests (bash/python).
- `skills/<name>/reference/` - load-by-pointer docs (commands, recipes).
- Repo root - authored files: `README.md`, `AGENTS.md`, `.gitignore`. The
  toolchain files `sync` and `skills.toml` also live here on the author's
  machine but untracked (see Project Overview); never stage them.

## Development Commands

Run on the author's machine only - `sync` and `skills.toml` are not in the
repo (see Project Overview):

```sh
./sync                  # mirror every skill in skills.toml into skills/
./sync add <name>...    # register a skill found in ~/.omp, then mirror
./sync list             # skills available in ~/.omp ([tracked] = published)
python3 -c "import ast; ast.parse(open('sync').read())"  # syntax check after editing sync
git status && git diff  # review mirror changes before committing
```

Publishing a skill = `./sync add <name>` -> commit. Unpublishing = delete its
`[[skill]]` block -> `./sync` (prunes `skills/<name>/`) -> commit. There is no
build, install, or CI step.

## Code Conventions & Common Patterns

- `sync` is dependency-free Python 3.11+ (stdlib only: `tomllib`, `shutil`,
  `fnmatch`, `subprocess`). Keep it that way.
- SKILL.md frontmatter: exactly `name` + `description`; descriptions are
  double-quoted with `\"` escapes and may be long - `sync` unescapes and
  truncates them for the README list.
- Recurring SKILL.md sections across skills (an established pattern for new
  skills): `# HARD GATE` (never-do rules), `## Current state` (verified
  facts table with dates), `## Failure modes` (symptom -> cause -> fix),
  `## Session mistakes` (dated error log), `## Scripts` (path -> purpose
  table with absolute `~/.omp/...` paths).
- Skills reference the author's live paths (`~/.omp/agent/managed-skills/...`)
  inside SKILL.md bodies - mirrored copies keep those absolute paths as-is.
- All artifacts are English; shebangs `#!/usr/bin/env bash` / `python3`;
  scripts are executable (copy2 preserves modes).
- `skills/architect-partner/.gitignore` travels with the skill and is inert
  here (its private targets are never copied in the first place).

## Important Files

- `sync` - the entire maintainer toolchain (CLI, discovery, copy, prune,
  README regeneration). Untracked local file - never stage or commit it.
- `skills.toml` - publish list + sources + global excludes. Untracked local
  file - never stage or commit it. The only file routinely hand-edited.
- `README.md` - public doc, entirely hand-written (no generated skill list).
- `skills/architect-partner/` - largest skill; git-tracked copy, has
  sub-skills (`calculator/`, `data-architect/`, `reflection/`) and its own
  scripts.
- `skills/write-a-skill/` - single-file skill (SKILL.md only): the meta
  methodology for authoring further OMP skills.

## Runtime/Tooling Preferences

- Python >= 3.11 required (stdlib `tomllib` reads `skills.toml`); no venv, no
  dependencies, no package manager.
- `git` required (both for the repo and for tracked-file export of git-backed
  skills).
- Skill scripts may reference the author's live machine paths - they are
  documentation here, not expected to run from the mirror.
- No linter/formatter configured; no lockfile; nothing to install.

## Testing & QA

There is **no repo-level test runner**. QA is two-layered:

1. Mirror integrity (repo level): after any `sync` change, run `./sync`
   twice (must be idempotent), check `git status` for unexpected diffs, and
   confirm no private files leaked (`find skills -name 'QUOTES.md' -o -name
   'REF.md' -o -name '.git'` must be empty).
2. Per-skill self-tests (run in `~/.omp`, not from this mirror):
   - `architect-partner`: `scripts/check-links.sh` (quote-anchor
     verification); calculator gate = `calculator/scripts/check.py` +
     `check_usage.py` (+ `unwind.py` for human review).

When a skill's SKILL.md mandates running its self-tests after edits, that
mandate applies to edits in `~/.omp` - mirror commits are mechanical and
exempt.
