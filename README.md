# skilliosis

Agent skills for AI coding harnesses that load the open `SKILL.md` format
(a skill directory with a `SKILL.md` plus supporting scripts): Claude Code,
OpenAI Codex, DeepSeek Harness, opencode, OMP. Every skill here is mirrored
from the author's live working setup and is in daily use.

Installing is copying the skill directories into the folder your harness
scans. One command covers every harness - only the target folder changes.

## Install - Linux and macOS

Default target is `~/.claude/skills` (Claude Code reads it; opencode reads it
too):

```sh
DEST="${DEST:-$HOME/.claude/skills}"; mkdir -p "$DEST"; curl -fsSL https://github.com/veschin/skilliosis/archive/refs/heads/main.tar.gz | tar -xz --strip-components=2 -C "$DEST" skilliosis-main/skills
```

Any other harness: pick its folder from the table below and set `DEST` to it.
Example for Codex:

```sh
DEST="$HOME/.codex/skills"; mkdir -p "$DEST"; curl -fsSL https://github.com/veschin/skilliosis/archive/refs/heads/main.tar.gz | tar -xz --strip-components=2 -C "$DEST" skilliosis-main/skills
```

## Install - Windows (PowerShell)

Default target is `%USERPROFILE%\.claude\skills`:

```powershell
$dest="$env:USERPROFILE/.claude/skills"; New-Item -ItemType Directory -Force -Path $dest | Out-Null; $t="$env:TEMP/skilliosis.tar.gz"; Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/veschin/skilliosis/archive/refs/heads/main.tar.gz" -OutFile $t; tar -xzf $t -C $dest --strip-components=2 skilliosis-main/skills; Remove-Item $t
```

Requires `tar.exe`, built into Windows 10 (1803+) and 11. For another harness
replace the path after `$dest=` with the Windows form of the folder from the
table below (`~` becomes `%USERPROFILE%`).

## Where each harness looks for skills

| Harness | Personal (all projects) | Per project (in a repo) |
| --- | --- | --- |
| Claude Code | `~/.claude/skills` | `.claude/skills` |
| OpenAI Codex | `~/.codex/skills` | not supported - run with `CODEX_HOME` pointed at the project if needed |
| DeepSeek Harness | `~/.agents/skills` (also `~/.dsh/skills`) | `.agents/skills` (also `.dsh/skills`) |
| opencode | `~/.config/opencode/skills` | `.opencode/skills` |
| OMP | `~/.omp/agent/managed-skills` | `.omp/skills` |

Notes:

- Claude Code and opencode both read `.claude/skills`, and opencode,
  DeepSeek Harness and recent Codex builds all read `.agents/skills` - one
  install can cover several harnesses. Prefer `.claude/skills` or
  `.agents/skills` when you use more than one tool from the same group.
- Codex picks up new skills after a restart.
- opencode also loads `.claude/skills` and `.agents/skills` next to
  `.opencode/skills`, in a project and in your home directory.

## Install one skill

Append the skill name to the archive path in the command.

Linux and macOS (write-a-skill into the default target):

```sh
DEST="${DEST:-$HOME/.claude/skills}"; mkdir -p "$DEST"; curl -fsSL https://github.com/veschin/skilliosis/archive/refs/heads/main.tar.gz | tar -xz --strip-components=2 -C "$DEST" skilliosis-main/skills/write-a-skill
```

Windows (PowerShell):

```powershell
$dest="$env:USERPROFILE\.claude\skills"; New-Item -ItemType Directory -Force -Path $dest | Out-Null; $t="$env:TEMP\skilliosis.tar.gz"; Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/veschin/skilliosis/archive/refs/heads/main.tar.gz" -OutFile $t; tar -xzf $t -C $dest --strip-components=2 skilliosis-main/skills/write-a-skill; Remove-Item $t
```

## Update

Re-run the install command - files are overwritten in place. Ask your
assistant to use a skill by name; it reads the `SKILL.md` from the installed
directory.

## Skills

<!-- skills:start -->
- [architect-partner](skills/architect-partner/) - Use when the user wants to design or research a subsystem, storage, or data flow inside an existing system ("спроектируй хранение", "design the storage", "сделай исследование", "run a research") and demands no-fabrication discipline....
- [write-a-skill](skills/write-a-skill/) - Use when asked to create, improve, or audit an OMP skill - managed/global or local/project. Picks the right install location so a project skill never lands in the global root.
<!-- skills:end -->

The skills encode their author's machine (paths, versions, local quirks).
Expect to adjust those to your own setup.
