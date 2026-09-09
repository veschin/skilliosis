<#
.SYNOPSIS
    skilliosis installer - detects coding harnesses on this machine and grafts
    the skill colony into the folder your harness scans for SKILL.md files.

.DESCRIPTION
    Detects Claude Code, Codex, DeepSeek Harness, opencode and OMP by their
    config folders or CLI commands, then installs the skills into the folder
    you pick. Works in Windows PowerShell 5.1 and pwsh.

.PARAMETER Dest
    Install into this folder (skips the picker).

.PARAMETER Skill
    Install a single skill (architect-partner, write-a-skill).

.PARAMETER Yes
    Install into every detected harness (no picker).

.PARAMETER List
    List detected harnesses and exit.

.EXAMPLE
    .\install.ps1
.EXAMPLE
    .\install.ps1 -Dest "$env:USERPROFILE\.claude\skills" -Skill write-a-skill
.EXAMPLE
    .\install.ps1 -List
#>
param(
    [string]$Dest = "",
    [string]$Skill = "",
    [switch]$Yes,
    [switch]$List
)

$ErrorActionPreference = "Stop"

$TarballUrl = if ($env:SKILLIOSIS_TAR_URL) { $env:SKILLIOSIS_TAR_URL } else {
    "https://github.com/veschin/skilliosis/archive/refs/heads/main.tar.gz"
}
$ArchiveRoot = "skilliosis-main/skills"

function Get-Harnesses {
    $found = @()
    $probes = @(
        @{ Label = "Claude Code";      Dir = "$HOME/.claude/skills";            Cmd = "claude" },
        @{ Label = "OpenAI Codex";     Dir = "$HOME/.codex/skills";             Cmd = "codex" },
        @{ Label = "DeepSeek Harness"; Dir = "$HOME/.agents/skills";            Cmd = "dsh" },
        @{ Label = "opencode";         Dir = "$HOME/.config/opencode/skills";   Cmd = "opencode" },
        @{ Label = "OMP";              Dir = "$HOME/.omp/agent/managed-skills"; Cmd = "omp" }
    )
    foreach ($p in $probes) {
        $cmdOk = $false
        if ($p.Cmd) { $cmdOk = [bool](Get-Command $p.Cmd -ErrorAction SilentlyContinue) }
        if ((Test-Path -LiteralPath $p.Dir) -or (Test-Path -LiteralPath (Split-Path -Parent $p.Dir)) -or $cmdOk) {
            $found += [pscustomobject]@{ Label = $p.Label; Dir = $p.Dir }
        }
    }
    return $found
}

function Install-To([string]$destDir) {
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "skilliosis-install.tar.gz"
    Write-Host "Fetching skills..."
    Invoke-WebRequest -UseBasicParsing -Uri $TarballUrl -OutFile $tmp
    $member = $ArchiveRoot
    if ($Skill) {
        $member = "$ArchiveRoot/$Skill"
        $listing = @(& tar -tzf $tmp)
        if (-not ($listing | Select-String -SimpleMatch "$member/")) {
            Write-Host "No such skill: $Skill" -ForegroundColor Red
            $avail = $listing | ForEach-Object {
                if ($_ -match "^$([regex]::Escape($ArchiveRoot))/([^/]+)/") { $matches[1] }
            } | Sort-Object -Unique
            Write-Host "Available: $($avail -join ', ')"
            Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
            exit 1
        }
    }
    & tar -xzf $tmp -C $destDir --strip-components=2 $member
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    Write-Host "Installed into: $destDir"
}

function Choose-Target($harnesses) {
    Write-Host "Where should the skills go?"
    $i = 1
    foreach ($h in $harnesses) {
        Write-Host ("  [{0}] {1,-20} {2}" -f $i, $h.Label, $h.Dir)
        $i++
    }
    Write-Host ("  [{0}] {1,-20}" -f $i, "Custom path")
    $pick = Read-Host "Pick a destination [1-$i, q to quit]"
    if ($pick -match '^(q|Q)$') { exit 0 }
    $n = 0
    if ([int]::TryParse($pick, [ref]$n) -and $n -ge 1 -and $n -le $i) {
        if ($n -eq $i) {
            $custom = Read-Host "Full path"
            if (-not $custom) { Write-Host "No path given." -ForegroundColor Red; exit 2 }
            return $custom
        }
        return $harnesses[$n - 1].Dir
    }
    Write-Host "Invalid choice: $pick" -ForegroundColor Red
    exit 2
}

$harnesses = @(Get-Harnesses)

if ($List) {
    if ($harnesses.Count -eq 0) {
        Write-Host "No harnesses detected. Pass -Dest to install anyway."
    } else {
        Write-Host "Detected harnesses:"
        foreach ($h in $harnesses) {
            Write-Host ("  {0,-20} {1}" -f $h.Label, $h.Dir)
        }
    }
    exit 0
}

$targets = @()
if ($Dest) {
    $targets += $Dest
} elseif ($Yes) {
    if ($harnesses.Count -eq 0) {
        Write-Host "No harnesses detected. Pass -Dest to install anyway." -ForegroundColor Red
        exit 2
    }
    foreach ($h in $harnesses) { $targets += $h.Dir }
} elseif ($harnesses.Count -gt 0) {
    $targets += Choose-Target $harnesses
} else {
    Write-Host "No harnesses detected."
    $custom = Read-Host "Full path to install into (q to quit)"
    if ($custom -match '^(q|Q)$' -or -not $custom) { exit 0 }
    $targets += $custom
}

foreach ($t in $targets) { Install-To $t }

Write-Host ""
Write-Host "Done. Name a skill to your assistant - it reads SKILL.md from the installed folder."
if (Get-Command codex -ErrorAction SilentlyContinue) {
    Write-Host "Restart Codex to pick up the new skills."
}
exit 0
