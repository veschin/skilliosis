#!/usr/bin/env bash
# quotes.sh - serialized operations on a project QUOTES.md (architect-partner).
# WHY: 2-3 parallel sessions appending to one quote book collide on numbers.
# ALL QUOTES.md writes MUST go through this script: flock-serialized, atomic,
# numbering taken as max+1 (gaps are never refilled - numbers stay stable).
# After a successful add, run guard.sh approve for the project dir.
# Usage:
#   quotes.sh DIR add 'SECTION TITLE' 'quote text' ['annotation']
#   quotes.sh DIR next    # next free quote number (max + 1)
#   quotes.sh DIR check   # report: entry count, max number, duplicate numbers
# Exit codes: 0 ok, 1 usage error, 2 lock/verify failure.
set -uo pipefail

DIR="${1:-}"; OP="${2:-}"
if [ -z "$DIR" ] || [ -z "$OP" ] || [ ! -f "$DIR/QUOTES.md" ]; then
  echo "usage: quotes.sh DIR add|next|check [args]; DIR must contain QUOTES.md" >&2
  exit 1
fi
Q="$DIR/QUOTES.md"; LOCK="$DIR/.quotes.lock"

next_number() { grep -oE '^[0-9]+\.' "$Q" | tr -d '.' | sort -n | tail -1; }

case "$OP" in
next)
  exec 200>"$LOCK" || exit 2; flock -x 200 || exit 2
  echo $(( $(next_number) + 1 ))
  ;;
add)
  SECTION="${3:-}"; TEXT="${4:-}"; ANNO="${5:-}"
  if [ -z "$SECTION" ] || [ -z "$TEXT" ]; then
    echo "usage: quotes.sh DIR add 'SECTION TITLE' 'quote text' ['annotation']" >&2
    exit 1
  fi
  exec 200>"$LOCK" || exit 2; flock -x 200 || { echo "lock failed" >&2; exit 2; }
  N=$(( $(next_number) + 1 ))
  [ -n "$ANNO" ] && ENTRY="$N. ($ANNO) ${TEXT}" || ENTRY="$N. ${TEXT}"
  TMP="$(mktemp "$DIR/.quotes.XXXXXX")" || exit 2
  if grep -qxF "## $SECTION" "$Q"; then
    # insert the entry as the LAST entry of the existing section
    awk -v sec="## $SECTION" -v entry="$ENTRY" '
      { lines[NR] = $0 }
      END {
        n = NR
        while (n > 0 && lines[n] == "") n--
        insec = 0
        for (i = 1; i <= n; i++) {
          if (insec && lines[i] ~ /^## /) { print entry; print ""; insec = 0 }
          print lines[i]
          if (lines[i] == sec) insec = 1
        }
        if (insec) { print ""; print entry }
      }' "$Q" > "$TMP"
  else
    # new section at EOF (trailing blanks normalized to exactly one)
    awk '{ lines[NR] = $0 } END {
        n = NR
        while (n > 0 && lines[n] == "") n--
        for (i = 1; i <= n; i++) print lines[i]
      }' "$Q" > "$TMP"
    printf '\n## %s\n\n%s\n' "$SECTION" "$ENTRY" >> "$TMP"
  fi
  if [ "$(grep -cE "^${N}\. " "$TMP")" -ne 1 ]; then
    echo "verify failed (number ${N} not unique), nothing written" >&2; rm -f "$TMP"; exit 2
  fi
  if ! mv "$TMP" "$Q"; then echo "write failed" >&2; rm -f "$TMP"; exit 2; fi
  echo "added ${N} under '## ${SECTION}' - now run: guard.sh approve ${DIR} QUOTES.md \"ref\""
  ;;
check)
  N=$(grep -oE '^[0-9]+\.' "$Q" | tr -d '.')
  echo "entries: $(printf '%s\n' "$N" | grep -c .), max: $(printf '%s\n' "$N" | sort -n | tail -1)"
  printf '%s\n' "$N" | sort -n | uniq -d | sed 's/^/DUPLICATE: /'
  ;;
*)
  echo "unknown op: $OP" >&2; exit 1
  ;;
esac
