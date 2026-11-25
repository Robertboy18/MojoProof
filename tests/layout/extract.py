#!/usr/bin/env python3
"""Read the values of the layout conformance program from its LLVM IR and write the Lean test.

Usage: extract.py CASES_JSON KERNEL_LL OUT_LEAN [--mojo VERSION]

KERNEL_LL is the kernel's device IR (the `*.nvptx.ll` file that mojoc.sh writes next to the
host IR). The compiler folds every static layout function, so the kernel body is a list of
stores of constants into the output buffer: `store i64 C, ptr %p` with `%p` the buffer or a
`getelementptr inbounds i64, ptr %buf, i32 k` of it. The script maps each slot to its value,
fails if a slot is stored twice, never, or through a pointer it cannot read, and writes one Lean
`example` per case: the model's values for the case, computed from the model's definitions,
equal the list read from the IR, by `decide`.
"""

import argparse
import json
import re
import sys
import textwrap
from math import prod


def die(msg):
    sys.exit(f"extract.py: {msg}")


def read_slots(path):
    """The map from slot to stored value of the kernel in the IR file."""
    text = open(path).read()
    kernels = re.findall(r"define [^\n]*ptx_kernel[^\n]*\{\n(.*?)\n\}", text, re.S)
    if len(kernels) != 1:
        die(f"{path}: expected one kernel, found {len(kernels)}")
    body = kernels[0].splitlines()
    base = None
    ptrs = {}
    slots = {}
    for line in body:
        line = line.strip()
        m = re.match(r"(%\d+) = extractvalue \{ ptr,.*\} %\d+, 0$", line)
        if m:
            if base is not None:
                die("two buffer pointers")
            base = m.group(1)
            ptrs[base] = 0
            continue
        m = re.match(r"(%\d+) = getelementptr inbounds (i64|i8), ptr (%\d+), i(?:32|64) (-?\d+)$",
                     line)
        if m:
            name, ty, src, k = m.group(1), m.group(2), m.group(3), int(m.group(4))
            if src not in ptrs:
                die(f"GEP of an unknown pointer: {line}")
            off = k if ty == "i64" else k / 8
            if off != int(off):
                die(f"unaligned GEP: {line}")
            ptrs[name] = ptrs[src] + int(off)
            continue
        m = re.match(r"store i64 (-?\d+), ptr (%\d+), align \d+$", line)
        if m:
            vals, p = [int(m.group(1))], m.group(2)
        else:
            m = re.match(r"store <(\d+) x i64> <(.*)>, ptr (%\d+), align \d+$", line)
            if m:
                vals = [int(v.split()[1]) for v in m.group(2).split(",")]
                if len(vals) != int(m.group(1)):
                    die(f"bad vector store: {line}")
                p = m.group(3)
            elif line.startswith("store"):
                die(f"store the script cannot read: {line}")
            else:
                continue
        if p not in ptrs:
            die(f"store through an unknown pointer: {line}")
        for j, v in enumerate(vals):
            s = ptrs[p] + j
            if s in slots:
                die(f"slot {s} stored twice")
            slots[s] = v
    return slots


def tree(t):
    """A Lean `Tup` with static leaves."""
    if isinstance(t, int):
        return f"leaf{NBSP}{t}{NBSP}true"
    return "tup [" + ", ".join(tree(c) for c in t) + "]"


def lay(shape, stride):
    """A Lean `Lay`: `Lay.flat` of the pairs for a flat layout, the anonymous structure else."""
    if all(isinstance(x, int) for x in shape + stride):
        return "(Lay.flat [" + ", ".join(f"({e},{NBSP}{d})" for e, d in zip(shape, stride)) + "])"
    return ("(⟨[" + ", ".join(tree(s) for s in shape) + "], [" +
            ", ".join(tree(d) for d in stride) + "]⟩ : Lay)")


def nats(xs):
    return "[" + ", ".join(str(x) for x in xs) + "]"


def leaves(t):
    return [t] if isinstance(t, int) else [v for c in t for v in leaves(c)]


def model(c):
    """The Lean expression of the model's values for case `c`, and a one-line description."""
    k = c["kind"]
    if k == "call":
        L = lay(c["shape"], c["stride"])
        n = prod(leaves(c["shape"]))
        return (f"(List.range {n}).map (fun i => {L}.call (leaf i true)) ++ [{L}.cosize]",
                f"the offsets of the scalars below the size of {fmt(c['shape'], c['stride'])}, "
                "then its cosize")
    if k == "exact":
        L = lay(c["shape"], c["stride"])
        crds = "[" + ", ".join(nats(x) for x in c["crds"]) + "]"
        return (f"{crds}.map (fun x => {L}.call (tup (x.map (leaf · true))))",
                f"the offsets of the coordinates {crds} in {fmt(c['shape'], c['stride'])}")
    if k == "mixed":
        L = lay(c["shape"], c["stride"])
        crds = "[" + ", ".join(tree(x) for x in c["crds"]) + "]"
        return (f"{crds}.map {L}.call",
                f"the offsets of the mixed coordinates "
                f"{', '.join(fmtc(x) for x in c['crds'])} in {fmt(c['shape'], c['stride'])}")
    if k == "idx2crd":
        L = lay(c["shape"], c["stride"])
        return (f"{nats(c['idxs'])}.flatMap (fun k => "
                f"(idx2crd k (tup {L}.shape) (tup {L}.stride)).leaves)",
                f"idx2crd of {nats(c['idxs'])} in {fmt(c['shape'], c['stride'])}")
    if k == "rowmajor":
        L = f"(Lay.flat (rowMajor {nats(c['shape'])}))"
        return (f"(List.range {prod(c['shape'])}).map (fun i => {L}.call (leaf i true))",
                f"the offsets of the scalars of row_major{tuple(c['shape'])}")
    if k == "coalesce":
        L = f"{lay(c['shape'], c['stride'])}.coalesce"
        n = prod(c["shape"])
        return (f"(List.range {n}).map (fun i => {L}.call (leaf i true)) ++ [{L}.size]",
                f"the offsets and the size of coalesce({fmt(c['shape'], c['stride'])})")
    if k == "upcast":
        L = f"(Lay.upcast {c['factor']} {lay(c['shape'], c['stride'])})"
        return (f"{L}.modes.flatMap (fun m => [m.1, m.2])",
                f"the (extent, stride) modes of upcast[{c['factor']}]"
                f"({fmt(c['shape'], c['stride'])})")
    if k == "zdiv":
        L = f"({lay(c['shape'], c['stride'])}.zippedDivide {nats(c['tile'])})"
        n = prod(c["tile"]) * prod(e // t for e, t in zip(c["shape"], c["tile"]))
        return (f"(List.range {n}).map (fun i => {L}.call (leaf i true)) ++ [{L}.size]",
                f"the offsets and the size of zipped_divide[{tuple(c['tile'])}]"
                f"({fmt(c['shape'], c['stride'])})")
    if k == "bprod":
        (bs, bd), (ts, td) = c["block"], c["tiler"]
        L = f"(Lay.blockedProduct {lay(bs, bd)} {lay(ts, td)})"
        n = prod(bs) * prod(ts)
        return (f"(List.range {n}).map (fun i => {L}.call (leaf i true)) ++ [{L}.size]",
                f"the offsets and the size of blocked_product({fmt(bs, bd)}, {fmt(ts, td)})")
    if k == "swizzle":
        S = f"(⟨{c['bits']}, {c['base']}, {c['shift']}⟩ : Swizzle)"
        return (f"{nats(c['xs'])}.map {S}.call",
                f"Swizzle({c['bits']}, {c['base']}, {c['shift']}) at {nats(c['xs'])}")
    if k == "compose":
        (as_, ad), (bs, bd) = c["a"], c["b"]
        L = f"({lay(as_, ad)}.compose {lay(bs, bd)})"
        return (f"(List.range {prod(leaves(bs))}).map (fun i => {L}.call (leaf i true))",
                f"the offsets of composition({fmt(as_, ad)}, {fmt(bs, bd)})")
    die(f"unknown kind {k}")


def fmtc(x):
    """A coordinate tree as Mojo prints it: an int, or a parenthesized tuple."""
    return str(x) if isinstance(x, int) else "(" + ", ".join(fmtc(y) for y in x) + ")"


def fmt(shape, stride):
    def t(x):
        if isinstance(x, int):
            return str(x)
        return "(" + ", ".join(t(y) for y in x) + ")"
    return f"{t(shape)}:{t(stride)}"


HEADER = """\
import MojoProof.Layout.Algebra

/-!
# The layout model against Mojo's compiler: generated conformance test

Generated by tests/layout/extract.py from tests/layout/cases.json (seed {seed}) and the LLVM IR
that Mojo {mojo} emits for tests/layout/conformance.mojo; do not edit. Each example states that
the values the model of MojoProof/Layout computes for one case equal the constants that the
compiler folded into the kernel's stores, by `decide`. This is a test, not a proof: it covers
these {ncases} cases ({nvals} values) on static layouts, compiled for sm_80 and never run, and
says nothing about other shapes or about layouts with runtime leaves. tests/layout/record.txt
records the run.
-/

namespace MojoProofTest.LayoutConformance

open MojoProof.Layout MojoProof.Layout.Tup
"""


NBSP = "\u00a0"


def wrap(text, first, width=100, indent="    "):
    """`text` split at spaces into lines of at most `width` columns, after a first line that
    starts with `first`; later lines start with `indent`. Spaces written as `NBSP` do not break
    and become plain spaces."""
    lines, cur = [], first
    for w in text.split(" "):
        if len(cur) + 1 + len(w) > width and cur.strip() != first.strip():
            lines.append(cur)
            cur = indent + w
        else:
            cur = cur + " " + w if cur and cur != indent else cur + w
    lines.append(cur)
    return "\n".join(lines).replace(NBSP, " ")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cases")
    ap.add_argument("ir")
    ap.add_argument("out")
    ap.add_argument("--mojo", default="(unrecorded version)")
    a = ap.parse_args()
    spec = json.load(open(a.cases))
    slots = read_slots(a.ir)
    if sorted(slots) != list(range(spec["slots"])):
        missing = sorted(set(range(spec["slots"])) - set(slots))
        extra = sorted(set(slots) - set(range(spec["slots"])))
        die(f"slots missing {missing[:10]} extra {extra[:10]}")
    head = HEADER.format(seed=spec["seed"], mojo=a.mojo, ncases=len(spec["cases"]),
                         nvals=spec["slots"])
    pre, rest = head.split("\n\n", 2)[:2], head.split("\n\n", 2)[2]
    para, post = rest.split("\n-/", 1)
    para = textwrap.fill(" ".join(para.split()), width=100, break_on_hyphens=False)
    out = ["\n\n".join(pre) + "\n\n" + para + "\n-/" + post]
    for i, c in enumerate(spec["cases"]):
        vals = [slots[s] for s in range(c["slot"], c["slot"] + c["count"])]
        if any(v < 0 for v in vals):
            die(f"case {i}: a negative value {vals}")
        expr, desc = model(c)
        out.append(f"\n{wrap(desc, f'-- case {i}, ' + c['kind'] + ':', indent='--   ')}\n"
                   f"{wrap(expr + ' = ' + nats(vals) + ' := by decide', 'example :')}\n")
    out.append("\nend MojoProofTest.LayoutConformance\n")
    with open(a.out, "w") as f:
        f.write("".join(out))
    print(f"{len(spec['cases'])} cases, {spec['slots']} values")


if __name__ == "__main__":
    main()
