#!/bin/sh
# architect-partner guard -- freeze user artifacts (TZ / QUOTES / REF).
# A change to a protected file is valid ONLY with an approve entry (logged with a reference).
# Usage:
#   guard.sh init DIR FILE...             start protection, record checksums
#   guard.sh check DIR                    verify (exit 0 intact / 1 violation)
#   guard.sh approve DIR FILE "ref"       re-record FILE after an approved change; ref is mandatory
set -u
CMD="${1:-help}"; DIR="${2:-.}"
G="$DIR/.arch-guard"; MAN="$G/manifest"; LOG="$G/approvals.log"

case "$CMD" in
init)
  [ "$#" -ge 3 ] || { echo 'guard: usage: init DIR FILE...' >&2; exit 2; }
  mkdir -p "$G"; : >"$MAN"; shift 2
  for f in "$@"; do
    [ -f "$DIR/$f" ] || { echo "guard: no such file: $DIR/$f" >&2; exit 2; }
    sha256sum "$DIR/$f" | awk -v f="$f" '{print $1 "  " f}' >>"$MAN"
  done
  echo "guard: protected $(wc -l <"$MAN") file(s); manifest: $MAN"
  ;;
check)
  [ -f "$MAN" ] || { echo "guard: FAIL - no manifest, run: guard.sh init DIR FILE..." >&2; exit 1; }
  fail=0
  while IFS= read -r line; do
    h=${line%% *}; f=${line#*  }
    if [ ! -f "$DIR/$f" ]; then echo "guard: FAIL missing: $f"; fail=1; continue; fi
    cur=$(sha256sum "$DIR/$f"); cur=${cur%% *}
    [ "$cur" = "$h" ] || { echo "guard: FAIL changed without approval: $f (manifest $h, current $cur)"; fail=1; }
  done <"$MAN"
  [ "$fail" = 0 ] && echo "guard: OK - $(wc -l <"$MAN") file(s) intact"
  exit "$fail"
  ;;
approve)
  [ "$#" -eq 4 ] && [ -n "$4" ] || { echo 'guard: usage: approve DIR FILE "ref" (ref is mandatory)' >&2; exit 2; }
  f="$3"; ref="$4"
  [ -f "$MAN" ] || { echo "guard: no manifest, run init first" >&2; exit 2; }
  [ -f "$DIR/$f" ] || { echo "guard: no such file: $DIR/$f" >&2; exit 2; }
  old=$(awk -v f="$f" '$2==f{print $1}' "$MAN")
  new=$(sha256sum "$DIR/$f"); new=${new%% *}
  printf '%s\t%s\t%s -> %s\tref: %s\n' "$(date -Iseconds)" "$f" "${old:-NEW}" "$new" "$ref" >>"$LOG"
  grep -v "  $f\$" "$MAN" >"$MAN.tmp" || true
  sha256sum "$DIR/$f" | awk -v f="$f" '{print $1 "  " f}' >>"$MAN.tmp"
  mv "$MAN.tmp" "$MAN"
  echo "guard: approved $f (${old:-NEW} -> $new) ref: $ref"
  ;;
*)
  echo 'usage: guard.sh init DIR FILE... | check DIR | approve DIR FILE "ref"' >&2
  ;;
esac
