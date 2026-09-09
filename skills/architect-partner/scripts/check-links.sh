#!/bin/sh
# architect-partner check-links -- verify REF.md links by literal quote search.
# Checks:
#   1) every [U:n] used in Links exists in QUOTES.md (numbered quote n);
#   2) every [O:x] used in Links is defined in Nodes and its locator text is found
#      verbatim in the TZ file (first existing of: TZ.md, SCENARIO.org);
#   3) every link line targeting [D:*] carries approved="..." (non-empty).
# Usage: check-links.sh DIR   (DIR holds REF.md, QUOTES.md and the TZ file)
set -u
DIR="${1:-.}"
REF="$DIR/REF.md"; Q="$DIR/QUOTES.md"
TZ=""
for c in TZ.md SCENARIO.org; do [ -f "$DIR/$c" ] && TZ="$DIR/$c" && break; done
[ -f "$REF" ] || { echo "check-links: FAIL no REF.md in $DIR" >&2; exit 1; }
[ -f "$Q" ]   || { echo "check-links: FAIL no QUOTES.md in $DIR" >&2; exit 1; }
[ -n "$TZ" ]  || { echo "check-links: FAIL no TZ file (TZ.md / SCENARIO.org) in $DIR" >&2; exit 1; }

links=$(awk '/^## Links/{flag=1;next} /^## /{flag=0} flag' "$REF")
fail=0

# 1) quote references
for n in $(printf '%s\n' "$links" | grep -o '\[U:[0-9][0-9]*\]' | tr -d '[]U:' | sort -un); do
  grep -q "^$n\. " "$Q" || { echo "check-links: FAIL quote $n referenced in Links but absent in QUOTES.md"; fail=1; }
done

# 2) origin nodes: defined + locator verbatim in TZ
for x in $(printf '%s\n' "$links" | grep -o '\[O:[A-Za-z0-9_][A-Za-z0-9_]*\]' | sed 's/^\[O://; s/\]$//' | sort -u); do
  loc=$(awk -v id="[O:$x]" 'index($0, id)==1 {
      rest = substr($0, length(id)+1)
      if (rest == "" || substr(rest,1,1) == " ") { $1 = ""; sub(/^ +/, ""); print; exit }
    }' "$REF")
  if [ -z "$loc" ]; then
    echo "check-links: FAIL [O:$x] used in Links but not defined in Nodes"; fail=1
  else
    grep -qF -- "$loc" "$TZ" || { echo "check-links: FAIL [O:$x] locator not found verbatim in $TZ: $loc"; fail=1; }
  fi
done

# 3) derivative targets need an approval marker on the same link line
bad3=$(printf '%s\n' "$links" | awk '/\[D:/ && $0 !~ /approved="[^"]+"/ { print }')
if [ -n "$bad3" ]; then
  printf 'check-links: FAIL link(s) to [D:*] without approved="...":\n%s\n' "$bad3"; fail=1
fi

[ "$fail" = 0 ] && echo "check-links: OK - Links verified against QUOTES.md and $TZ"
exit "$fail"
