#!/bin/sh
# architect-partner ref.sh -- the claims graph over SQLite (REF.sqlite per project).
# The authoritative, approval-gated claims graph: claim cards with a status
# lifecycle (pending -> approved -> superseded), typed edges between nodes,
# supersession instead of deletion. REF.sqlite is canonical; REF.md is a
# rendered view (ref.sh render). Legacy markdown REF projects migrate via
# ref.sh import DIR.
# Node types: O (origin, verbatim TZ locator), U (user quote by QUOTES.md
# number), D (derivative), C (claim), DEC (decision), ISSUE (open question).
# Edge types: supports, contradicts, supersedes, questions, implements.
# Path grammar ("[A]->[B]-[C]"): brackets/spaces are stripped, tokens are
# TYPE:ID, junction separators -> and - are ignored; each token must match
# ^(O|U|D|C|DEC|ISSUE):[A-Za-z0-9_-]+$.
# Exit codes: 0 ok, 1 violations / state errors, 2 usage.
set -u
command -v sqlite3 >/dev/null || { echo "ref: sqlite3 required" >&2; exit 2; }

usage() {
  cat >&2 <<'EOF'
usage: ref.sh COMMAND DIR [args]
  init DIR                                  apply schema (idempotent)
  node DIR TYPE ID [TEXT...]                add node (U: numeric quote no., no text)
  link DIR "PATH" [--type T] [--ref R] [--note N]
                                            PATH: [A]->[B]; auto-creates missing nodes;
                                            --ref mandatory when last token is D/C/DEC/ISSUE
  approve DIR LINE_ID "ref"                 set approved_ref on a link line
  approve-node DIR NODE_ID "ref"            node status pending -> approved
  supersede DIR OLD_ID NEW_ID "ref"         NEW (approved) supersedes OLD
  check DIR [--no-tz]                       violations -> exit 1
  traverse DIR NODE [--up]                  BFS: outgoing edges (default) / incoming (--up)
  orphans DIR                               origins without outgoing / claims without
                                            incoming supports / superseded still referenced
  render DIR                                regenerate REF.md from REF.sqlite
  import DIR [--dry-run]                    legacy markdown REF.md -> fresh REF.sqlite
  stats DIR                                 counts per node type x status
  query DIR "SELECT ..."                    read-only SQL
  dot DIR                                   graphviz to stdout
EOF
  exit 2
}

CMD="${1:-}"
[ -n "$CMD" ] || usage
DIR="${2:-.}"
DB="$DIR/REF.sqlite"
if [ "$#" -ge 2 ]; then shift 2; else shift 1; fi

sql_escape() { printf '%s' "$1" | sed "s/'/''/g"; }
sql() { sqlite3 -batch "$DB" "$1"; }
now() { date -Iseconds; }
today() { date -I; }
require_db() {
  [ -f "$DB" ] || { echo "ref: no REF.sqlite in $DIR - run: ref.sh init $DIR" >&2; exit 2; }
}
log_action() {
  sql "INSERT INTO reflog(ts,action,detail) VALUES('$(sql_escape "$(now)")','$(sql_escape "$1")','$(sql_escape "$2")');"
}
apply_schema() {
  sqlite3 -batch "$DB" <<'SQL'
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS nodes(
  id TEXT PRIMARY KEY,            -- 'O:sla', 'U:7', 'D:rule', 'C:h3-point', 'DEC:drop-latlon', 'ISSUE:retention'
  type TEXT NOT NULL CHECK(type IN ('O','U','D','C','DEC','ISSUE')),
  text TEXT NOT NULL DEFAULT '',  -- O: locator (verbatim TZ text); others: thesis/description; U: ''
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','superseded')),
  valid_from TEXT NOT NULL,       -- ISO date, = created_at date
  valid_until TEXT,               -- set on supersede
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS link_lines(
  line_id INTEGER PRIMARY KEY,
  type TEXT NOT NULL DEFAULT 'supports',   -- one of: supports, contradicts, supersedes, questions, implements
  approved_ref TEXT NOT NULL DEFAULT '',
  note TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS edges(
  edge_id INTEGER PRIMARY KEY,
  line_id INTEGER NOT NULL REFERENCES link_lines(line_id),
  src TEXT NOT NULL REFERENCES nodes(id),
  dst TEXT NOT NULL REFERENCES nodes(id)
);
CREATE TABLE IF NOT EXISTS reflog(
  ts TEXT NOT NULL, action TEXT NOT NULL, detail TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS idx_edges_src ON edges(src);
CREATE INDEX IF NOT EXISTS idx_edges_dst ON edges(dst);
SQL
}
# tokenize PATH -> tokens one per line on stdout; rc 3 on garbage (message on stderr)
tokenize() {
  printf '%s\n' "$1" | awk '
    { s = $0 }
    END {
      n = 0
      while (length(s) > 0) {
        c = substr(s, 1, 1)
        if (index("[]<>- \t", c) > 0) { s = substr(s, 2); continue }
        if (match(s, /^(DEC|O|U|D|C|ISSUE):[A-Za-z0-9_-]+/)) {
          print substr(s, RSTART, RLENGTH)
          n++
          s = substr(s, RLENGTH + 1)
        } else {
          print "ref: bad path (token): " $0 > "/dev/stderr"
          exit 3
        }
      }
      if (n < 1) { print "ref: bad path (no nodes): " $0 > "/dev/stderr"; exit 3 }
    }'
}

case "$CMD" in
init)
  [ -d "$DIR" ] || mkdir -p "$DIR" || exit 2
  apply_schema
  log_action init "schema applied"
  echo "ref: initialized $DB"
  ;;
node)
  require_db
  TYPE="${1:-}"; ID="${2:-}"
  [ -n "$TYPE" ] && [ -n "$ID" ] || { echo "ref: usage: node DIR TYPE ID [TEXT...]" >&2; exit 2; }
  case "$TYPE" in O|U|D|C|DEC|ISSUE) ;; *) echo "ref: bad node type: $TYPE" >&2; exit 2 ;; esac
  case "$ID" in *[!A-Za-z0-9_-]*) echo "ref: bad node id: $ID" >&2; exit 2 ;; esac
  shift 2
  TEXT=""
  if [ "$TYPE" = "U" ]; then
    case "$ID" in *[!0-9]*) echo "ref: U node id must be a quote number: $ID" >&2; exit 2 ;; esac
    [ "$#" -eq 0 ] || { echo "ref: U node takes no text" >&2; exit 2; }
  else
    for w in "$@"; do TEXT="${TEXT:+$TEXT }$w"; done
  fi
  NID="$TYPE:$ID"
  dup=$(sql "SELECT COUNT(*) FROM nodes WHERE id='$(sql_escape "$NID")';")
  [ "$dup" = "0" ] || { echo "ref: node exists: $NID" >&2; exit 1; }
  case "$TYPE" in O|U) ST=approved ;; *) ST=pending ;; esac
  sql "INSERT INTO nodes(id,type,text,status,valid_from,created_at) VALUES('$(sql_escape "$NID")','$TYPE','$(sql_escape "$TEXT")','$ST','$(today)','$(now)');"
  log_action node "$NID"
  echo "ref: node added: $NID"
  ;;
link)
  require_db
  PATH_ARG="${1:-}"
  [ -n "$PATH_ARG" ] || { echo 'ref: usage: link DIR "PATH" [--type T] [--ref R] [--note N]' >&2; exit 2; }
  shift
  TYPE=supports; REF=""; NOTE=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --type) [ "$#" -ge 2 ] || { echo "ref: --type needs a value" >&2; exit 2; }; TYPE=$2; shift 2 ;;
      --ref)  [ "$#" -ge 2 ] || { echo "ref: --ref needs a value" >&2; exit 2; }; REF=$2; shift 2 ;;
      --note) [ "$#" -ge 2 ] || { echo "ref: --note needs a value" >&2; exit 2; }; NOTE=$2; shift 2 ;;
      *) echo "ref: unknown option: $1" >&2; exit 2 ;;
    esac
  done
  case "$TYPE" in supports|contradicts|supersedes|questions|implements) ;; *) echo "ref: bad edge type: $TYPE" >&2; exit 2 ;; esac
  TOKENS=$(tokenize "$PATH_ARG") || exit 2
  [ -n "$TOKENS" ] || { echo "ref: bad path (no nodes): $PATH_ARG" >&2; exit 2; }
  NTOK=$(printf '%s\n' "$TOKENS" | grep -c .)
  [ "$NTOK" -ge 2 ] || { echo "ref: path needs at least two nodes: $PATH_ARG" >&2; exit 2; }
  LAST=$(printf '%s\n' "$TOKENS" | tail -n 1)
  case "${LAST%%:*}" in
    D|C|DEC|ISSUE)
      [ -n "$REF" ] || { echo "ref: --ref is mandatory when linking to ${LAST%%:*} nodes (target: $LAST)" >&2; exit 2; }
      ;;
  esac
  NOWTS="$(now)"; TODAY="$(today)"
  for tok in $TOKENS; do
    t=${tok%%:*}
    case "$t" in O|U) ST=approved ;; *) ST=pending ;; esac
    sql "INSERT OR IGNORE INTO nodes(id,type,text,status,valid_from,created_at) VALUES('$(sql_escape "$tok")','$t','','$ST','$TODAY','$NOWTS');"
  done
  LID=$(sql "INSERT INTO link_lines(type,approved_ref,note,created_at) VALUES('$TYPE','$(sql_escape "$REF")','$(sql_escape "$NOTE")','$NOWTS'); SELECT last_insert_rowid();")
  PAIRS=""
  prev=""
  for tok in $TOKENS; do
    if [ -n "$prev" ]; then
      PAIRS="${PAIRS}INSERT INTO edges(line_id,src,dst) VALUES($LID,'$(sql_escape "$prev")','$(sql_escape "$tok")');"
    fi
    prev=$tok
  done
  sql "$PAIRS"
  log_action link "line $LID: $PATH_ARG type=$TYPE ref=$REF"
  echo "$LID"
  ;;
approve)
  require_db
  LID="${1:-}"; REF="${2:-}"
  case "$LID" in ''|*[!0-9]*) echo "ref: line id must be numeric: $LID" >&2; exit 2 ;; esac
  [ -n "$REF" ] || { echo 'ref: usage: approve DIR LINE_ID "ref" (ref is mandatory)' >&2; exit 2; }
  n=$(sql "UPDATE link_lines SET approved_ref='$(sql_escape "$REF")' WHERE line_id=$LID; SELECT changes();")
  [ "$n" = "1" ] || { echo "ref: no such line: $LID" >&2; exit 1; }
  log_action approve "line $LID ref: $REF"
  echo "ref: line $LID approved: $REF"
  ;;
approve-node)
  require_db
  NID="${1:-}"; REF="${2:-}"
  [ -n "$NID" ] && [ -n "$REF" ] || { echo 'ref: usage: approve-node DIR NODE_ID "ref"' >&2; exit 2; }
  ex=$(sql "SELECT COUNT(*) FROM nodes WHERE id='$(sql_escape "$NID")';")
  [ "$ex" != "0" ] || { echo "ref: no such node: $NID" >&2; exit 1; }
  st=$(sql "SELECT status FROM nodes WHERE id='$(sql_escape "$NID")';")
  [ "$st" = "pending" ] || { echo "ref: node not pending: $NID (status=$st)" >&2; exit 1; }
  sql "UPDATE nodes SET status='approved' WHERE id='$(sql_escape "$NID")';"
  log_action approve-node "node $NID ref: $REF"
  echo "ref: node approved: $NID (ref: $REF)"
  ;;
supersede)
  require_db
  OLD="${1:-}"; NEW="${2:-}"; REF="${3:-}"
  [ -n "$OLD" ] && [ -n "$NEW" ] && [ -n "$REF" ] || { echo 'ref: usage: supersede DIR OLD_ID NEW_ID "ref"' >&2; exit 2; }
  for x in "$OLD" "$NEW"; do
    ex=$(sql "SELECT COUNT(*) FROM nodes WHERE id='$(sql_escape "$x")';")
    [ "$ex" != "0" ] || { echo "ref: no such node: $x" >&2; exit 1; }
  done
  nst=$(sql "SELECT status FROM nodes WHERE id='$(sql_escape "$NEW")';")
  [ "$nst" = "approved" ] || { echo "ref: new node not approved: $NEW (status=$nst)" >&2; exit 1; }
  ost=$(sql "SELECT status FROM nodes WHERE id='$(sql_escape "$OLD")';")
  [ "$ost" != "superseded" ] || { echo "ref: already superseded: $OLD" >&2; exit 1; }
  sql "INSERT INTO link_lines(type,approved_ref,note,created_at) VALUES('supersedes','$(sql_escape "$REF")','','$(now)'); INSERT INTO edges(line_id,src,dst) VALUES(last_insert_rowid(),'$(sql_escape "$NEW")','$(sql_escape "$OLD")'); UPDATE nodes SET status='superseded', valid_until='$(today)' WHERE id='$(sql_escape "$OLD")';"
  log_action supersede "$OLD -> $NEW ref: $REF"
  echo "ref: superseded: $OLD by $NEW (ref: $REF)"
  ;;
check)
  require_db
  NOTZ=0
  if [ "${1:-}" = "--no-tz" ]; then NOTZ=1; shift; fi
  [ "$#" -eq 0 ] || { echo "ref: usage: check DIR [--no-tz]" >&2; exit 2; }
  fail=0
  UCOUNT=$(sql "SELECT COUNT(*) FROM nodes WHERE type='U';")
  if [ "$UCOUNT" -gt 0 ]; then
    if [ ! -f "$DIR/QUOTES.md" ]; then
      echo "ref: FAIL no QUOTES.md in $DIR (U nodes unverifiable)"; fail=1
    else
      for u in $(sql "SELECT id FROM nodes WHERE type='U' ORDER BY id;"); do
        qn=${u#U:}
        grep -q "^$qn\. " "$DIR/QUOTES.md" || { echo "ref: FAIL quote $qn ($u) referenced but absent in QUOTES.md"; fail=1; }
      done
    fi
  fi
  TZFILE=""
  for c in TZ.md SCENARIO.org; do
    if [ -f "$DIR/$c" ]; then TZFILE="$DIR/$c"; break; fi
  done
  for o in $(sql "SELECT id FROM nodes WHERE type='O' ORDER BY id;"); do
    otext=$(sql "SELECT text FROM nodes WHERE id='$(sql_escape "$o")';")
    if [ -z "$otext" ]; then
      echo "ref: FAIL origin without locator: $o"; fail=1
      continue
    fi
    if [ "$NOTZ" -eq 0 ]; then
      if [ -z "$TZFILE" ]; then
        echo "ref: FAIL no TZ file (TZ.md / SCENARIO.org) in $DIR: $o"; fail=1
        continue
      fi
      grep -qF -- "$otext" "$TZFILE" || { echo "ref: FAIL $o locator not found verbatim in $TZFILE: $otext"; fail=1; }
    fi
  done
  for r in $(sql "SELECT DISTINCT l.line_id||'|'||n.id FROM link_lines l JOIN edges e ON e.line_id=l.line_id JOIN nodes n ON n.id=e.dst WHERE n.type IN ('D','C','DEC','ISSUE') AND l.approved_ref='' ORDER BY l.line_id;"); do
    echo "ref: FAIL line ${r%%|*}: link to ${r#*|} without approved ref"; fail=1
  done
  for r in $(sql "SELECT DISTINCT e.src||'|'||MIN(e.line_id) FROM edges e JOIN nodes n ON n.id=e.src WHERE n.status='pending' AND n.type IN ('C','DEC') GROUP BY e.src ORDER BY e.src;"); do
    echo "ref: FAIL pending claim used as grounding: ${r%%|*} (line ${r#*|})"; fail=1
  done
  for r in $(sql "SELECT id FROM nodes n WHERE status='superseded' AND NOT EXISTS (SELECT 1 FROM edges e JOIN link_lines l ON e.line_id=l.line_id WHERE e.dst=n.id AND l.type='supersedes') ORDER BY id;"); do
    echo "ref: FAIL superseded without supersedes edge: $r"; fail=1
  done
  for r in $(sql "SELECT DISTINCT n.id FROM nodes n JOIN edges e ON e.dst=n.id JOIN link_lines l ON e.line_id=l.line_id WHERE n.status='superseded' AND l.type<>'supersedes' ORDER BY n.id;"); do
    echo "ref: WARN superseded node still referenced: $r"
  done
  if [ "$fail" -eq 0 ]; then
    echo "ref: OK - $(sql "SELECT COUNT(*) FROM nodes;") nodes, $(sql "SELECT COUNT(*) FROM link_lines;") lines verified"
  fi
  exit "$fail"
  ;;
traverse)
  require_db
  NID="${1:-}"
  [ -n "$NID" ] || { echo "ref: usage: traverse DIR NODE [--up]" >&2; exit 2; }
  UP=0
  if [ "${2:-}" = "--up" ]; then UP=1; shift; fi
  [ "$#" -eq 1 ] || { echo "ref: usage: traverse DIR NODE [--up]" >&2; exit 2; }
  ex=$(sql "SELECT COUNT(*) FROM nodes WHERE id='$(sql_escape "$NID")';")
  [ "$ex" != "0" ] || { echo "ref: no such node: $NID" >&2; exit 1; }
  {
    sql "SELECT 'N '||id||'|'||status FROM nodes ORDER BY id;"
    sql "SELECT 'E '||e.src||'|'||e.dst||'|'||l.type FROM edges e JOIN link_lines l ON e.line_id=l.line_id ORDER BY e.edge_id;"
  } | awk -v root="$NID" -v up="$UP" '
    $1 == "N" { split($2, a, "|"); st[a[1]] = a[2] }
    $1 == "E" { split($2, a, "|")
                if (up) adj[a[2]] = adj[a[2]] " " a[1] "," a[3]
                else    adj[a[1]] = adj[a[1]] " " a[2] "," a[3] }
    END {
      print "0\t-\t" root "\t" st[root]
      vis[root] = 1; nf = 1; fr[1] = root; depth = 0
      while (nf >= 1) {
        depth++; nn = 0
        for (i = 1; i <= nf; i++) {
          cur = fr[i]
          m = split(adj[cur], ps, " ")
          for (j = 1; j <= m; j++) {
            if (ps[j] == "") continue
            split(ps[j], pd, ",")
            nb = pd[1]
            if (nb in vis) continue
            vis[nb] = 1
            print depth "\t" pd[2] "\t" nb "\t" st[nb]
            nn++; nx[nn] = nb
          }
        }
        for (i = 1; i <= nn; i++) fr[i] = nx[i]
        nf = nn
      }
    }'
  ;;
orphans)
  require_db
  echo "origins without outgoing edges:"
  r=$(sql "SELECT id FROM nodes n WHERE type='O' AND NOT EXISTS (SELECT 1 FROM edges WHERE src=n.id) ORDER BY id;")
  [ -n "$r" ] && printf '%s\n' "$r" || echo "none"
  echo "claims/decisions without incoming supports:"
  r=$(sql "SELECT id FROM nodes n WHERE type IN ('C','DEC','ISSUE') AND NOT EXISTS (SELECT 1 FROM edges e JOIN link_lines l ON e.line_id=l.line_id WHERE e.dst=n.id AND l.type='supports') ORDER BY id;")
  [ -n "$r" ] && printf '%s\n' "$r" || echo "none"
  echo "superseded still referenced:"
  r=$(sql "SELECT DISTINCT n.id FROM nodes n JOIN edges e ON e.dst=n.id JOIN link_lines l ON e.line_id=l.line_id WHERE n.status='superseded' AND l.type<>'supersedes' ORDER BY n.id;")
  [ -n "$r" ] && printf '%s\n' "$r" || echo "none"
  ;;
render)
  require_db
  {
    echo "# REF.md - rendered view of REF.sqlite (edit the graph via ref.sh, not this file)"
    echo
    echo "## Nodes"
    echo
    sql "SELECT id||'|'||text FROM nodes WHERE type<>'U' ORDER BY id;" | while IFS= read -r l; do
      rid=${l%%|*}; rtext=${l#*|}
      if [ -n "$rtext" ]; then echo "[$rid] $rtext"; else echo "[$rid]"; fi
    done
    UC=$(sql "SELECT COUNT(*) FROM nodes WHERE type='U';")
    [ "$UC" -gt 0 ] && echo "[U:*] live in QUOTES.md by number"
    echo
    echo "## Links"
    echo
    sql "SELECT line_id FROM link_lines ORDER BY line_id;" | while IFS= read -r lid; do
      lref=$(sql "SELECT approved_ref FROM link_lines WHERE line_id=$lid;")
      lnote=$(sql "SELECT note FROM link_lines WHERE line_id=$lid;")
      SEQ=$( { sql "SELECT src FROM edges WHERE line_id=$lid ORDER BY edge_id;"; sql "SELECT dst FROM edges WHERE line_id=$lid ORDER BY edge_id;"; } )
      line=""; i=0; ntok=0
      for t in $SEQ; do ntok=$((ntok + 1)); done
      for t in $SEQ; do
        i=$((i + 1))
        if [ "$i" -eq 1 ]; then line="[$t]"
        elif [ "$i" -eq "$ntok" ]; then line="$line->[$t]"
        else line="$line-[$t]"
        fi
      done
      out="- $line approved=\"$lref\""
      if [ -n "$lnote" ]; then out="$out - $lnote"; fi
      echo "$out"
    done
  } > "$DIR/REF.md"
  log_action render "REF.md regenerated"
  echo "ref: rendered $DIR/REF.md"
  ;;
import)
  DRY=0
  if [ "${1:-}" = "--dry-run" ]; then DRY=1; shift; fi
  [ "$#" -eq 0 ] || { echo "ref: usage: import DIR [--dry-run]" >&2; exit 2; }
  [ -f "$DIR/REF.md" ] || { echo "ref: no REF.md in $DIR" >&2; exit 2; }
  if [ -f "$DB" ]; then
    EXN=$(sql "SELECT COUNT(*) FROM nodes;" 2>/dev/null) || EXN=0
    if [ "${EXN:-0}" != "0" ] && [ "$DRY" -eq 0 ]; then
      echo "ref: REF.sqlite already has $EXN nodes - import refused (fresh DB required; --dry-run previews)" >&2
      exit 1
    fi
  fi
  BASE=0
  if [ "$DRY" -eq 0 ]; then
    apply_schema
    BASE=$(sql "SELECT COALESCE(MAX(line_id),0) FROM link_lines;")
  fi
  OUT=$(awk -v base="$BASE" -v tday="$(today)" -v q="'" '
    function es(s) { gsub(q, q q, s); return s }
    function badpath() { print "ref: import skipped line " NR ": " $0 > "/dev/stderr"; skips++ }
    function addnode(id, ty, txt) {
      if (id in seen) return
      seen[id] = 1; ord[++on] = id; ntype[id] = ty; ntext[id] = txt
    }
    function tokenize(str, t,    s, c, n) {
      s = str; n = 0
      while (length(s) > 0) {
        c = substr(s, 1, 1)
        if (index("[]<>- \t", c) > 0) { s = substr(s, 2); continue }
        if (match(s, /^(DEC|O|U|D|C|ISSUE):[A-Za-z0-9_-]+/)) {
          n++; t[n] = substr(s, RSTART, RLENGTH); s = substr(s, RLENGTH + 1)
        } else { badtok = 1; return n }
      }
      return n
    }
    BEGIN { on = 0; lines = 0; skips = 0; sec = "" }
    /^## / { if ($0 ~ /^## Nodes$/) sec = "nodes"; else if ($0 ~ /^## Links$/) sec = "links"; else sec = "other"; next }
    /^#/ { next }
    /^[ \t]*$/ { next }
    sec == "nodes" && match($0, /^\[(O|D|C|DEC|ISSUE):[A-Za-z0-9_-]+\] /) {
      head = substr($0, 2, RLENGTH - 3)
      p = index(head, ":")
      addnode(head, substr(head, 1, p - 1), substr($0, RLENGTH + 1))
      next
    }
    sec == "links" && /^- /{
      s = substr($0, 3); ref = ""; note = ""
      idx = index(s, " approved=\"")
      if (idx > 0) {
        path = substr(s, 1, idx - 1)
        rest = substr(s, idx + 11)
        cq = index(rest, "\"")
        if (cq > 1) ref = substr(rest, 1, cq - 1)
        if (cq > 0) { rest = substr(rest, cq + 1); sub(/^[ -]+/, "", rest); note = rest }
      } else {
        sep = index(s, " - ")
        if (sep > 0) { path = substr(s, 1, sep - 1); note = substr(s, sep + 3) }
        else path = s
      }
      badtok = 0
      n = tokenize(path, tk)
      if (badtok || n < 2) { badpath(); next }
      lines++
      lid = base + lines
      print "SQLINSERT INTO link_lines(line_id,type,approved_ref,note,created_at) VALUES(" lid "," q "supports" q "," q es(ref) q "," q es(note) q "," q tday q ");"
      for (i = 1; i < n; i++) {
        a = tk[i]; b = tk[i + 1]
        pa = index(a, ":"); pb = index(b, ":")
        addnode(a, substr(a, 1, pa - 1), "")
        addnode(b, substr(b, 1, pb - 1), "")
        print "SQLINSERT INTO edges(line_id,src,dst) VALUES(" lid "," q a q "," q b q ");"
        if (ref != "") {
          bt = substr(b, 1, pb - 1)
          if (bt == "D" || bt == "C" || bt == "DEC" || bt == "ISSUE") gotref[b] = 1
        }
      }
      next
    }
    { badpath() }
    END {
      for (i = 1; i <= on; i++) {
        id = ord[i]; ty = ntype[id]
        st = "pending"
        if (ty == "O" || ty == "U" || (id in gotref)) st = "approved"
        print "SQLINSERT OR IGNORE INTO nodes(id,type,text,status,valid_from,created_at) VALUES(" q es(id) q "," q ty q "," q es(ntext[id]) q "," q st q "," q tday q "," q tday q ");"
      }
      print "COUNTS " on " " lines " " skips
    }' "$DIR/REF.md")
  if [ "$DRY" -eq 1 ]; then
    COUNTS=$(printf '%s\n' "$OUT" | grep '^COUNTS ')
    set -- $COUNTS
    echo "ref: import (dry-run) nodes=$2 lines=$3 skipped_prose=$4"
    exit 0
  fi
  if ! printf '%s\n' "$OUT" | grep '^SQL' | sed 's/^SQL//' | sqlite3 -batch "$DB"; then
    echo "ref: import failed (SQL error)" >&2
    exit 1
  fi
  COUNTS=$(printf '%s\n' "$OUT" | grep '^COUNTS ')
  set -- $COUNTS
  log_action import "nodes=$2 lines=$3 skipped_prose=$4"
  echo "ref: import nodes=$2 lines=$3 skipped_prose=$4"
  ;;
stats)
  require_db
  sql "SELECT type, status, COUNT(*) FROM nodes GROUP BY type, status ORDER BY type, status;"
  ;;
query)
  Q="${1:-}"
  [ -n "$Q" ] || { echo 'ref: usage: query DIR "SELECT ..."' >&2; exit 2; }
  printf '%s' "$Q" | grep -iqE '^[[:space:]]*(select|with)([[:space:];(]|$)' || { echo "ref: query must start with SELECT or WITH" >&2; exit 2; }
  require_db
  sql "$Q"
  ;;
dot)
  require_db
  echo "digraph REF {"
  sql "SELECT id||'|'||status||'|'||text FROM nodes ORDER BY id;" | while IFS= read -r l; do
    nid=${l%%|*}; rest=${l#*|}; nst=${rest%%|*}; ntext=${rest#*|}
    ntext=$(printf '%s' "$ntext" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g' | cut -c1-30)
    case "$nst" in
      pending)    echo "  \"$nid\" [label=\"$nid|$ntext\", fillcolor=\"#fee\", style=filled];" ;;
      superseded) echo "  \"$nid\" [label=\"$nid|$ntext\", fillcolor=\"#ddd\", style=filled];" ;;
      *)          echo "  \"$nid\" [label=\"$nid|$ntext\"];" ;;
    esac
  done
  sql "SELECT e.src||'|'||e.dst||'|'||l.type FROM edges e JOIN link_lines l ON e.line_id=l.line_id ORDER BY e.edge_id;" | while IFS= read -r l; do
    src=${l%%|*}; rest=${l#*|}; dst=${rest%%|*}; ty=${rest##*|}
    echo "  \"$src\" -> \"$dst\" [label=\"$ty\"];"
  done
  echo "}"
  ;;
*)
  usage
  ;;
esac
