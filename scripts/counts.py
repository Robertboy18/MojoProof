#!/usr/bin/env python3
"""Checks the counts of the audit and of near_dups.py against their limits in scripts/counts.tsv.

    python3 scripts/counts.py <audit output> <near_dups output>

<audit output> is what `lake env lean --run scripts/Audit.lean` prints (lines `DUPDEF 0`,
`DUPTHM 0`, ...); <near_dups output> is what `python3 scripts/near_dups.py . --lib MojoProof`
prints (lines `width families N groups, ...` and `near-duplicate clusters N, ...`). For every row
`key limit` of scripts/counts.tsv it prints `  key: N (limit L)`, or `  key: N > L  GREW` when the
count exceeds its limit, or `  key: missing` when neither output has the count. Exit 1 if a count
is missing or exceeds its limit, else 0. The audit itself exits with an error only for an axiom
or a failed probe (equivalences, duplicates, instances), so this script is what enforces the
limits. Read-only; the standard library only."""
import os, re, sys

LIMITS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "counts.tsv")
# The count each key of counts.tsv reads: the audit's `KEY N` lines, near_dups.py's two summaries.
NEAR = {"near_dups": re.compile(r"^near-duplicate clusters (\d+)\b", re.M),
        "width_families": re.compile(r"^width families (\d+)\b", re.M)}


def limits(path: str = LIMITS) -> list[tuple[str, int]]:
    """The rows `key limit` of counts.tsv, in order; blank lines and `#` lines are skipped."""
    rows = []
    with open(path) as f:
        for line in f:
            if not line.strip() or line.startswith("#"):
                continue
            key, lim = line.split()
            rows.append((key, int(lim)))
    return rows


def found(key: str, audit: str, near: str) -> int | None:
    """The count `key` printed in the audit's or near_dups.py's output, or None if neither has it."""
    m = NEAR[key].search(near) if key in NEAR else re.search(rf"^{re.escape(key)} (\d+)$", audit, re.M)
    return int(m.group(1)) if m else None


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    with open(argv[1]) as f:
        audit = f.read()
    with open(argv[2]) as f:
        near = f.read()
    bad = 0
    print("counts (limit from scripts/counts.tsv):")
    for key, lim in limits():
        v = found(key, audit, near)
        if v is None:
            print(f"  {key}: missing")
            bad = 1
        elif v > lim:
            print(f"  {key}: {v} > {lim}  GREW")
            bad = 1
        else:
            print(f"  {key}: {v} (limit {lim})")
    return bad


if __name__ == "__main__":
    sys.exit(main(sys.argv))
