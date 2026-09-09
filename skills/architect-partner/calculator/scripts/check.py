#!/usr/bin/env python3
"""Verify an architectural calculator workbook: resolve references, evaluate every formula
recursively, fail on any error value; optional column-width freeze comparison.
Usage: check.py WORKBOOK.xlsx [widths.json]"""
import json
import math
import re
import sys
from pathlib import Path

import openpyxl

PATH = sys.argv[1] if len(sys.argv) > 1 else "artefacts/calculator.xlsx"
WIDTHS = sys.argv[2] if len(sys.argv) > 2 else None

w = openpyxl.load_workbook(PATH).active
formulas = {c.coordinate: c.value for row in w.iter_rows() for c in row
            if isinstance(c.value, str) and c.value.startswith("=")}
memo = {}
ru = lambda x: math.ceil(x * 100) / 100
AMP, PLUS = chr(38), chr(43)


def cell_value(ref):
    ref = ref.replace("$", "")
    if ref in memo:
        return memo[ref]
    v = w[ref].value
    if v is None:
        raise AssertionError(f"dangling reference {ref}")
    if isinstance(v, str) and v.startswith("="):
        v = evaluate(v)
    memo[ref] = v
    return v


def evaluate(formula):
    s = formula[1:]

    def vl(m):
        key_expr, rng = m.group(1), m.group(2)
        key = eval(re.sub(r'(?<![A-Z0-9$:"])(\$?[A-Z]{1,3}\d+)',
                          lambda mm: repr(w[mm.group(1).replace("$", "")].value),
                          key_expr.replace(AMP, PLUS)))
        c1, c2 = rng.split(":")
        col, r1 = re.match(r"([A-Z]+)(\d+)", c1).groups()
        r2 = int(re.match(r"[A-Z]+(\d+)", c2).group(1))
        col2 = chr(ord(col) + 1)
        for r in range(int(r1), r2 + 1):
            if str(w[f"{col}{r}"].value) == str(key):
                return str(w[f"{col2}{r}"].value)
        raise AssertionError(f"#N/A: key {key!r} not found in {rng}")

    s = re.sub(r"VLOOKUP\((.+),([A-Z]\d+:[A-Z]\d+),2,0\)", vl, s)
    s = re.sub(r"(?<![A-Z0-9:])(\$?[A-Z]{1,3}\d+)",
               lambda m: repr(cell_value(m.group(1))), s)
    s = resolve_ifs(s)
    s = re.sub(r"ROUNDUP\((.+),\s*2\)", lambda m: f"__ru({m.group(1)})", s)
    s = re.sub(r"POWER\((.+?),\s*(.+?)\)", lambda m: f"({m.group(1)})**({m.group(2)})", s)
    return eval(s, {"__ru": ru})


def resolve_ifs(s):
    while "IF(" in s:
        i = s.index("IF(")
        args, cur, depth, j = [], [], 1, i + 3
        while depth:
            ch = s[j]
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    break
            elif ch == "," and depth == 1:
                args.append("".join(cur)); cur = []; j += 1; continue
            cur.append(ch); j += 1
        args.append("".join(cur))
        cond, a, b = args[0], args[1], args[2]
        cond = cond.replace("<>", "!=")
        cond = re.sub(r"(?<![<>=!])=(?!=)", "==", cond)
        repl = a if eval(cond) else b
        s = s[:i] + resolve_ifs(repl) + s[j + 1:]
    return s


errors = {}
for coord in list(formulas):
    try:
        formulas[coord] = evaluate(formulas[coord])
    except AssertionError as e:
        errors[coord] = f"ERROR: {e}"
if errors:
    print("WORKBOOK HAS ERRORS:")
    for k, v in sorted(errors.items()):
        print(" ", k, v)
    sys.exit(1)

widths = {k: round(v.width, 2) for k, v in w.column_dimensions.items() if v.width}
if WIDTHS:
    frozen = json.loads(Path(WIDTHS).read_text())
    if widths != frozen:
        print("WIDTHS CHANGED:")
        for k in sorted(set(widths) | set(frozen)):
            if widths.get(k) != frozen.get(k):
                print(" ", k, frozen.get(k), "->", widths.get(k))
        sys.exit(1)

print(f"OK: {len(formulas)} formula cells evaluated, no errors; widths: {widths}")
