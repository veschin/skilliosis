<p align="center">
  <img src="images/logo.webp" alt="skilliosis" width="540">
</p>

A colony of agent skills, cultured in the author's daily `~/.omp` and spoken
in the open `SKILL.md` language. Any harness - Claude Code, Codex, DeepSeek
Harness, opencode, OMP - can graft them in. Prognosis: benign.

## Install

One command, one target folder: the directory your harness scans for skills.
Default is `~/.claude/skills` (Claude Code reads it; opencode reads it too).

Linux, macOS:

```sh
DEST="${DEST:-$HOME/.claude/skills}"; mkdir -p "$DEST"; curl -fsSL https://github.com/veschin/skilliosis/archive/refs/heads/main.tar.gz | tar -xz --strip-components=2 -C "$DEST" skilliosis-main/skills
```

Windows (PowerShell; needs `tar.exe`, built in since 10 1803):

```powershell
$dest="$env:USERPROFILE/.claude/skills"; New-Item -ItemType Directory -Force -Path $dest | Out-Null; $t="$env:TEMP/skilliosis.tar.gz"; Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/veschin/skilliosis/archive/refs/heads/main.tar.gz" -OutFile $t; tar -xzf $t -C $dest --strip-components=2 skilliosis-main/skills; Remove-Item $t
```

Point `DEST` (Windows: the path after `$dest=`) at your harness's folder;
`~` becomes `%USERPROFILE%` there:

| Harness | Personal | Per project |
| --- | --- | --- |
| Claude Code | `~/.claude/skills` | `.claude/skills` |
| OpenAI Codex | `~/.codex/skills` | no native support - set `CODEX_HOME` per project |
| DeepSeek Harness | `~/.agents/skills` (or `~/.dsh/skills`) | `.agents/skills` (or `.dsh/skills`) |
| opencode | `~/.config/opencode/skills` | `.opencode/skills` |
| OMP | `~/.omp/agent/managed-skills` | `.omp/skills` |

`.claude/skills` feeds Claude Code and opencode; `.agents/skills` feeds
DeepSeek Harness, opencode and recent Codex builds. One install can feed
several. Restart Codex afterwards.

Install a single skill by appending its name to the archive path:

```sh
DEST="${DEST:-$HOME/.claude/skills}"; mkdir -p "$DEST"; curl -fsSL https://github.com/veschin/skilliosis/archive/refs/heads/main.tar.gz | tar -xz --strip-components=2 -C "$DEST" skilliosis-main/skills/write-a-skill
```

Re-run the command to update, then name the skill to your assistant - it
reads `SKILL.md` from the installed folder.

## Skills

### architect-partner

<p align="center">
  <img src="images/architect.webp" alt="architect-partner" width="500">
</p>

A design partner for architecture work: subsystems, storage, data flow.
One contract at a time - a spec file agreed with you first. Every decision
is locked with you before any action; every claim is anchored to a verbatim
quote. No quote, no statement.

Grows three sub-skills: calculator (sizing workbooks), data-architect
(data-systems mentoring), reflection (post-mortems and the quote book).

### write-a-skill

<p align="center">
  <img src="images/writeaskill.webp" alt="write-a-skill" width="500">
</p>

The methodology this colony is grown with: what makes a skill deterministic,
where to plant it - global or per project - and how to audit it afterwards.

Every skill carries its host's quirks (paths, versions, local workflows).
Expect to adapt those to your setup.
