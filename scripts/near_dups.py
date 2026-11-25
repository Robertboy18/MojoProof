#!/usr/bin/env python3
"""Counts of near-duplicate theorems in a Lean library: the `width_families` and `near_dups` rows of
scripts/counts.tsv.

    python3 scripts/near_dups.py <tree> [--lib DIR ...] [--list N]

--lib names the library directories under <tree> to scan (default: every top-level directory with .lean files,
except .lake, lake-packages, tests, test, scratch, attic and build). This repository's check is
`python3 scripts/near_dups.py . --lib GPUProof --lib MojoProof --list 5`.

Prints three counts and, with --list, the N largest clusters:
- width families: theorems whose text is identical once widths, types and chunk names are replaced
  (UInt8/16/32/64, USize, Float, Mint*, byte/word/half, bare 8/16/32/64);
- framed twins: a theorem `X` next to a theorem `framedX`;
- near-duplicate clusters: theorems of 15+ lines sharing at least 70% of their 5-token shingles
  (Jaccard similarity of the shingle sets, computed exactly for every pair of such theorems, so no
  pair is missed), with the lines beyond one theorem per cluster; clusters are the connected
  components of the pairs at or above the threshold.
Read-only; the standard library only."""
import collections, glob, os, re, sys

START = re.compile(r"^(?:@\[[^\]]*\]\s*)?(?:(?:private|protected|nonrec|noncomputable|partial|unsafe)\s+)*"
                   r"(theorem|lemma|def|abbrev|instance|structure|inductive)\b", re.M)
HEAD = re.compile(r"(?:@\[[^\]]*\]\s*)?(?:(?:private|protected|nonrec|noncomputable)\s+)*(theorem|lemma)\s+(\S+)")
WIDTH = re.compile(r"(U?Int(8|16|32|64)|USize|ISize|Float32|Float64|Float|Bool|Mint(8|16|32|64)(signed|unsigned)?|"
                   r"Many(32|64)|Mfloat(32|64)|(?<![A-Za-z0-9])(8|16|32|64)(?![0-9])|Byte|Word|Half|byte|word|half|"
                   r"uint(8|16|32|64)(_t)?|int(8|16|32|64)(_t)?)")


SKIP = {".lake", "lake-packages", "tests", "test", "scratch", "attic", "build", ".git"}


def library_dirs(tree, wanted):
    if wanted:
        return wanted
    return sorted(d for d in os.listdir(tree) if d not in SKIP and os.path.isdir(os.path.join(tree, d))
                  and glob.glob(os.path.join(tree, d, "**", "*.lean"), recursive=True))


def theorems(tree, libs):
    paths = [p for d in libs for p in glob.glob(f"{tree}/{d}/**/*.lean", recursive=True)]
    for p in sorted(paths):
        t = open(p, encoding="utf-8").read()
        st = [m.start() for m in START.finditer(t)] + [len(t)]
        for a, b in zip(st, st[1:]):
            m = HEAD.match(t[a:b])
            if m:
                clean = re.sub(r"--[^\n]*", "", re.sub(r"/-.*?-/", "", t[a:b], flags=re.S))
                yield m.group(2), p[len(tree) + 1:], clean.count("\n"), clean


def main():
    tree = sys.argv[1].rstrip("/")
    show = int(sys.argv[sys.argv.index("--list") + 1]) if "--list" in sys.argv else 0
    wanted = [sys.argv[i + 1] for i, a in enumerate(sys.argv) if a == "--lib"]
    libs = library_dirs(tree, wanted)
    print("libraries:", " ".join(libs))
    items = list(theorems(tree, libs))
    fam = collections.defaultdict(list)
    for name, path, n, clean in items:
        fam[WIDTH.sub("W", re.sub(r"\s+", " ", clean)).strip()].append((name, path, n))
    fam = [g for g in fam.values() if len(g) > 1]
    names = {n.split(".")[-1] for n, *_ in items}
    twins = sorted(n for n in names if "framed" + n[:1].upper() + n[1:] in names)
    big = [(n, p, k, re.findall(r"[A-Za-z_][A-Za-z0-9_.']*|\S", c)) for n, p, k, c in items if k >= 15]
    shingles = [{" ".join(toks[i:i + 5]) for i in range(max(1, len(toks) - 4))} for *_, toks in big]
    parent = list(range(len(big)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for a in range(len(big)):
        for b in range(a + 1, len(big)):
            sa, sb = shingles[a], shingles[b]
            # |A ∩ B| / |A ∪ B| ≥ 0.7 needs min/max ≥ 0.7 first; skip the set operations otherwise.
            if min(len(sa), len(sb)) < 0.7 * max(len(sa), len(sb)):
                continue
            inter = len(sa & sb)
            if inter >= 0.7 * (len(sa) + len(sb) - inter):
                parent[find(a)] = find(b)
    cl = collections.defaultdict(list)
    for i in range(len(big)):
        cl[find(i)].append(i)
    cl = sorted((c for c in cl.values() if len(c) > 1), key=lambda c: -sum(big[i][2] for i in c))
    extra = sum(sum(big[i][2] for i in c) - max(big[i][2] for i in c) for c in cl)
    print(f"theorems {len(items)}")
    print(f"width families {len(fam)} groups, {sum(len(g) for g in fam)} theorems, "
          f"{sum(sum(x[2] for x in g[1:]) for g in fam)} repeated lines")
    print(f"framed twins {len(twins)}")
    print(f"near-duplicate clusters {len(cl)}, {sum(len(c) for c in cl)} theorems, {extra} lines beyond one per cluster")
    for c in cl[:show]:
        print(f"  {len(c)} theorems, {sum(big[i][2] for i in c)} lines: "
              + ", ".join(f"{big[i][0].split('.')[-1]} ({big[i][1]})" for i in c[:4]))


if __name__ == "__main__":
    main()
