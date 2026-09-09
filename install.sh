#!/usr/bin/env bash
#
# skilliosis installer - detects coding harnesses on this machine and grafts
# the skill colony into the folder your harness scans for SKILL.md files.
#
# Usage:
#   install.sh                 interactive picker over detected harnesses
#   install.sh --dest DIR      non-interactive install into DIR
#   install.sh --skill NAME    install a single skill (with --dest or -y)
#   install.sh -y              install into every detected harness
#   install.sh --list          list detected harnesses and exit
#   install.sh -h, --help      show this help
#
# Set SKILLIOSIS_TAR_URL to override the tarball location (mirrors, testing).

set -euo pipefail

TARBALL_URL="${SKILLIOSIS_TAR_URL:-https://github.com/veschin/skilliosis/archive/refs/heads/main.tar.gz}"
ARCHIVE_ROOT="skilliosis-main/skills"

DEST=""
SKILL=""
LIST=0
ALL=0

usage() {
  cat <<'USAGE'
Usage: install.sh [options]

Detects the coding harnesses on this machine and installs the skilliosis
skills into the folder your harness scans for SKILL.md files.

Options:
  --dest DIR      install into DIR (skips the picker)
  --skill NAME    install a single skill (architect-partner, write-a-skill)
  -y              install into every detected harness (no picker)
  --list          list detected harnesses and exit
  -h, --help      show this help

Without --dest the script asks where to install.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dest)
      [ $# -ge 2 ] || { echo "--dest needs a path" >&2; exit 2; }
      DEST="$2"; shift 2 ;;
    --skill)
      [ $# -ge 2 ] || { echo "--skill needs a name" >&2; exit 2; }
      SKILL="$2"; shift 2 ;;
    -y) ALL=1; shift ;;
    --list) LIST=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# --- detect harnesses -------------------------------------------------------

DETECTED=() # "label|install path"

add_candidate() { # label install-path cli-name
  local label="$1" path="$2" cmd="$3"
  if [ -d "$path" ] || [ -d "$(dirname "$path")" ] \
     || { [ -n "$cmd" ] && command -v "$cmd" >/dev/null 2>&1; }; then
    DETECTED+=("$label|$path")
  fi
}

add_candidate "Claude Code"      "$HOME/.claude/skills"            claude
add_candidate "OpenAI Codex"     "$HOME/.codex/skills"             codex
add_candidate "DeepSeek Harness" "$HOME/.agents/skills"            dsh
add_candidate "opencode"         "$HOME/.config/opencode/skills"   opencode
add_candidate "OMP"              "$HOME/.omp/agent/managed-skills" omp

if [ "$LIST" -eq 1 ]; then
  if [ "${#DETECTED[@]}" -eq 0 ]; then
    echo "No harnesses detected. Pass --dest DIR to install anyway."
    exit 0
  fi
  echo "Detected harnesses:"
  for c in "${DETECTED[@]}"; do
    printf '  %-20s %s\n' "${c%%|*}" "${c#*|}"
  done
  exit 0
fi

# --- interactive picker -----------------------------------------------------

choose_target() {
  local n=1 c
  echo "Where should the skills go?"
  for c in "${DETECTED[@]}"; do
    printf '  [%d] %-20s %s\n' "$n" "${c%%|*}" "${c#*|}"
    n=$((n + 1))
  done
  printf '  [%d] %-20s\n' "$n" "Custom path"
  local pick
  read -r -p "Pick a destination [1-$n, q to quit]: " pick || true
  case "$pick" in
    q|Q|"") exit 0 ;;
  esac
  if [ "$pick" -ge 1 ] 2>/dev/null && [ "$pick" -le "$n" ]; then
    if [ "$pick" -eq "$n" ]; then
      read -r -p "Full path: " custom || true
      [ -n "$custom" ] || { echo "No path given." >&2; exit 2; }
      TARGET="$custom"
    else
      TARGET="${DETECTED[$((pick - 1))]#*|}"
    fi
  else
    echo "Invalid choice: $pick" >&2
    exit 2
  fi
}

# --- install ----------------------------------------------------------------

install_to() { # dest dir
  local dest="$1" tmp member
  mkdir -p "$dest"
  tmp="$(mktemp)"
  echo "Fetching skills..."
  if ! curl -fsSL "$TARBALL_URL" -o "$tmp"; then
    echo "Download failed: $TARBALL_URL" >&2
    rm -f "$tmp"
    return 1
  fi
  member="$ARCHIVE_ROOT"
  if [ -n "$SKILL" ]; then
    member="$ARCHIVE_ROOT/$SKILL"
    if ! tar -tzf "$tmp" | grep -qx "$member/"; then
      echo "No such skill: $SKILL" >&2
      echo "Available: $(tar -tzf "$tmp" | sed -n "s#^$ARCHIVE_ROOT/\([^/]*\)/.*#\1#p" | sort -u | tr '\n' ' ')"
      rm -f "$tmp"
      return 1
    fi
  fi
  tar -xzf "$tmp" -C "$dest" --strip-components=2 "$member"
  rm -f "$tmp"
  echo "Installed into: $dest"
}

TARGET=""
targets=()
if [ -n "$DEST" ]; then
  targets+=("$DEST")
elif [ "$ALL" -eq 1 ]; then
  if [ "${#DETECTED[@]}" -eq 0 ]; then
    echo "No harnesses detected. Pass --dest DIR to install anyway." >&2
    exit 2
  fi
  for c in "${DETECTED[@]}"; do targets+=("${c#*|}"); done
elif [ "${#DETECTED[@]}" -gt 0 ]; then
  choose_target
  targets+=("$TARGET")
else
  echo "No harnesses detected."
  read -r -p "Full path to install into (q to quit): " custom || true
  case "$custom" in
    q|Q|"") exit 0 ;;
  esac
  targets+=("$custom")
fi

failed=0
for t in "${targets[@]}"; do
  install_to "$t" || failed=1
done

if [ "$failed" -eq 0 ]; then
  echo
  echo "Done. Name a skill to your assistant - it reads SKILL.md from the installed folder."
  command -v codex >/dev/null 2>&1 && echo "Restart Codex to pick up the new skills."
fi
exit "$failed"
