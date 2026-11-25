#!/usr/bin/env python3
"""Generate the layout conformance program from a seed.

Usage: gen.py [--seed N] [--out DIR]

Writes DIR/conformance.mojo, a GPU kernel that stores the values of the layout library's
functions on random static layouts into its output buffer, and DIR/cases.json, the list of
cases: for each, its kind, its parameters, the first output slot and the number of values.
The program is compiled to LLVM IR and never run: the compiler evaluates the static layout
functions, so each value is a constant in a store of the kernel's IR (extract.py reads them).
"""

import argparse
import json
import random
from math import prod


def coord(xs):
    """A static coordinate `coord[a, b, ...]`."""
    return "coord[" + ", ".join(str(x) for x in xs) + "]"


def mtree(t):
    """A static Mojo coordinate tree: an int is `Idx[v]`, a list is `Coord(...)`."""
    if isinstance(t, int):
        return f"Idx[{t}]"
    return "Coord(" + ", ".join(mtree(c) for c in t) + ")"


def leaves(t):
    """The leaves of a tree, left to right."""
    return [t] if isinstance(t, int) else [v for c in t for v in leaves(c)]


def rand_flat(rng, rank, emax=4, dmax=12):
    """A flat layout of the given rank: random extents, random or column-major strides."""
    es = [rng.randint(1, emax) for _ in range(rank)]
    if rng.random() < 0.5:
        ds, acc = [], 1
        for e in es:
            ds.append(acc)
            acc *= e
        if rng.random() < 0.5:
            rng.shuffle(ds)
    else:
        ds = [rng.randint(0, dmax) for _ in range(rank)]
    return es, ds


def gen_cases(rng):
    """The list of cases, each a dict with a kind and its parameters."""
    cases = []
    # scalar offsets and the cosize of flat layouts of rank 1 to 3
    for rank in [1, 2, 2, 3, 3, 3]:
        es, ds = rand_flat(rng, rank)
        cases.append({"kind": "call", "shape": es, "stride": ds})
    # nested layouts: shape (a, (b, c)), stride (d, (e, f))
    for _ in range(3):
        es, ds = rand_flat(rng, 3)
        cases.append({"kind": "call", "shape": [es[0], [es[1], es[2]]],
                      "stride": [ds[0], [ds[1], ds[2]]]})
    # exact coordinates of flat layouts, in bounds
    for rank in [2, 3]:
        es, ds = rand_flat(rng, rank)
        crds = [[rng.randrange(e) for e in es] for _ in range(4)]
        cases.append({"kind": "exact", "shape": es, "stride": ds, "crds": crds})
    # idx2crd of flat layouts with positive strides
    for rank in [2, 3]:
        es, ds = rand_flat(rng, rank, dmax=6)
        ds = [max(d, 1) for d in ds]
        idxs = [rng.randrange(prod(es) * max(ds)) for _ in range(4)]
        cases.append({"kind": "idx2crd", "shape": es, "stride": ds, "idxs": idxs})
    cases.append({"kind": "idx2crd", "shape": [2, 2], "stride": [3, 1], "idxs": [3]})
    # row-major layouts
    for rank in [2, 3]:
        cases.append({"kind": "rowmajor", "shape": [rng.randint(1, 4) for _ in range(rank)]})
    # coalesce, including extent-1 and mergeable modes
    for rank in [2, 3, 3]:
        es, ds = rand_flat(rng, rank)
        if rng.random() < 0.5:
            es[rng.randrange(rank)] = 1
        cases.append({"kind": "coalesce", "shape": es, "stride": ds})
    cases.append({"kind": "coalesce", "shape": [2, 1, 3], "stride": [1, 7, 2]})
    # upcast, strides multiples of the factor, not multiples, and 0
    for f in [2, 4]:
        es = [rng.randint(1, 4) for _ in range(2)]
        ds = [f * rng.randint(1, 4), rng.randint(0, 9)]
        cases.append({"kind": "upcast", "factor": f, "shape": es, "stride": ds})
    cases.append({"kind": "upcast", "factor": 2, "shape": [4], "stride": [0]})
    # zipped divide, tiles dividing the extents and not
    for _ in range(2):
        es = [rng.choice([2, 4, 6]) for _ in range(2)]
        ts = [rng.choice([1, 2, 3]) for _ in range(2)]
        _, ds = rand_flat(rng, 2)
        cases.append({"kind": "zdiv", "shape": es, "stride": ds, "tile": ts})
    cases.append({"kind": "zdiv", "shape": [5], "stride": [1], "tile": [2]})
    # blocked product
    for _ in range(2):
        b = rand_flat(rng, 2, emax=3, dmax=4)
        t = rand_flat(rng, 2, emax=2, dmax=4)
        cases.append({"kind": "bprod", "block": b, "tiler": t})
    cases.append({"kind": "bprod", "block": ([2], [2]), "tiler": ([2], [1])})
    # swizzles, both signs of shift, with and without bits <= |shift|
    for _ in range(4):
        bits, base = rng.randint(1, 3), rng.randint(0, 3)
        shift = rng.choice([-1, 1]) * rng.randint(1, 4)
        xs = [rng.randrange(256) for _ in range(6)]
        cases.append({"kind": "swizzle", "bits": bits, "base": base, "shift": shift, "xs": xs})
    cases.append({"kind": "swizzle", "bits": 2, "base": 0, "shift": 1, "xs": [6, 5]})
    # composition: B's cosize at most A's size
    cases.append({"kind": "compose", "a": ([4, 3], [1, 4]), "b": ([6], [2])})
    cases.append({"kind": "compose", "a": ([2, 4], [1, 2]), "b": ([2, 2], [1, 2])})
    cases.append({"kind": "compose", "a": ([6, 2], [1, 6]), "b": ([3], [4])})
    # composition with B of several modes: a tile of row_major[4, 8], whose modes' terms add
    # without carry against A's extents, and two whose terms carry
    cases.append({"kind": "compose", "a": ([4, 8], [8, 1]), "b": ([2, [2, 2]], [1, [8, 16]])})
    cases.append({"kind": "compose", "a": ([2, 2], [1, 10]), "b": ([2, 2], [1, 1])})
    cases.append({"kind": "compose", "a": ([6, 2], [1, 100]), "b": ([3, 2], [2, 3])})
    # upcast of strides that divide the factor: the docstring's row_major[4, 8], and an extent
    # that the factor over the stride does not divide
    cases.append({"kind": "upcast", "factor": 2, "shape": [4, 8], "stride": [8, 1]})
    cases.append({"kind": "upcast", "factor": 2, "shape": [3], "stride": [1]})
    # mixed coordinates of a nested layout: a scalar for a tuple mode, a tuple, and a leaf
    cases.append({"kind": "mixed", "shape": [2, [2, 3]], "stride": [1, [2, 4]],
                  "crds": [[1, 5], [1, [1, 2]], [0, 4], [1, 0]]})
    return cases


def layout_mojo(shape, stride):
    """A Mojo `Layout` expression with static leaves."""
    if all(isinstance(x, int) for x in shape + stride):
        return f"Layout({coord(shape)}, {coord(stride)})"
    return f"Layout(shape={mtree(shape)}, stride={mtree(stride)})"


def size_of(shape):
    return prod(leaves(shape))


def emit(cases):
    """The kernel body for the cases; sets each case's first slot and number of values."""
    body, slot = [], 0

    def put(expr):
        nonlocal slot
        body.append(f"    out_tensor[{slot}] = Int64({expr})")
        slot += 1

    for k, c in enumerate(cases):
        c["slot"] = slot
        v = f"l{k}"
        kind = c["kind"]
        if kind == "call":
            body.append(f"    var {v} = {layout_mojo(c['shape'], c['stride'])}")
            for i in range(size_of(c["shape"])):
                put(f"{v}(Idx[{i}])")
            put(f"{v}.cosize()")
        elif kind == "exact":
            body.append(f"    var {v} = {layout_mojo(c['shape'], c['stride'])}")
            for crd in c["crds"]:
                put(f"{v}({mtree(crd)})")
        elif kind == "mixed":
            body.append(f"    var {v} = {layout_mojo(c['shape'], c['stride'])}")
            for crd in c["crds"]:
                put(f"{v}({mtree(crd)})")
        elif kind == "idx2crd":
            body.append(f"    var {v} = {layout_mojo(c['shape'], c['stride'])}")
            for j, i in enumerate(c["idxs"]):
                body.append(f"    var {v}c{j} = {v}.idx2crd({i})")
                for m in range(len(c["shape"])):
                    put(f"{v}c{j}[{m}].value()")
        elif kind == "rowmajor":
            body.append(f"    var {v} = row_major[{', '.join(map(str, c['shape']))}]()")
            for i in range(size_of(c["shape"])):
                put(f"{v}(Idx[{i}])")
        elif kind == "coalesce":
            body.append(f"    var {v} = coalesce({layout_mojo(c['shape'], c['stride'])})")
            for i in range(size_of(c["shape"])):
                put(f"{v}(Idx[{i}])")
            put(f"{v}.size()")
        elif kind == "upcast":
            body.append(f"    var {v} = upcast[factor={c['factor']}]"
                        f"({layout_mojo(c['shape'], c['stride'])})")
            for m in range(len(c["shape"])):
                put(f"{v}.shape_coord()[{m}].value()")
                put(f"{v}.stride_coord()[{m}].value()")
        elif kind == "zdiv":
            body.append(f"    var {v} = zipped_divide[{coord(c['tile'])}]"
                        f"({layout_mojo(c['shape'], c['stride'])})")
            n = prod(c["tile"]) * prod(e // t for e, t in zip(c["shape"], c["tile"]))
            for i in range(n):
                put(f"{v}(Idx[{i}])")
            put(f"{v}.size()")
        elif kind == "bprod":
            (bs, bd), (ts, td) = c["block"], c["tiler"]
            body.append(f"    var {v} = blocked_product({layout_mojo(bs, bd)}, "
                        f"{layout_mojo(ts, td)})")
            for i in range(prod(bs) * prod(ts)):
                put(f"{v}(Idx[{i}])")
            put(f"{v}.size()")
        elif kind == "swizzle":
            body.append(f"    var {v} = Swizzle({c['bits']}, {c['base']}, {c['shift']})")
            for x in c["xs"]:
                put(f"{v}({x})")
        elif kind == "compose":
            (as_, ad), (bs, bd) = c["a"], c["b"]
            body.append(f"    var {v} = composition({layout_mojo(as_, ad)}, "
                        f"{layout_mojo(bs, bd)})")
            for i in range(size_of(bs)):
                put(f"{v}(Idx[{i}])")
        else:
            raise ValueError(kind)
        c["count"] = slot - c["slot"]
    return body, slot


HEADER = '''\
# Generated by tests/layout/gen.py --seed {seed}; do not edit. Compiled to LLVM IR, never run.
from max.gpu.host import DeviceContext
from layout import Idx, Coord, coord, row_major, TileTensor
from layout.layout import Layout, coalesce, composition, zipped_divide, blocked_product, upcast
from layout.swizzle import Swizzle

comptime N = {n}
comptime olayout = row_major[N]()


def kern(out_tensor: TileTensor[DType.int64, type_of(olayout), MutAnyOrigin]):
'''

FOOTER = '''

def main() raises:
    var ctx = DeviceContext()
    var buf = ctx.enqueue_create_buffer[DType.int64](N)
    var t = TileTensor(buf, olayout)
    ctx.enqueue_function[kern](t, grid_dim=1, block_dim=1)
    ctx.synchronize()
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1729)
    ap.add_argument("--out", default="tests/layout")
    a = ap.parse_args()
    rng = random.Random(a.seed)
    cases = gen_cases(rng)
    body, n = emit(cases)
    with open(f"{a.out}/conformance.mojo", "w") as f:
        f.write(HEADER.format(seed=a.seed, n=n) + "\n".join(body) + FOOTER)
    with open(f"{a.out}/cases.json", "w") as f:
        json.dump({"seed": a.seed, "slots": n, "cases": cases}, f, indent=1)
        f.write("\n")
    print(f"{len(cases)} cases, {n} values")


if __name__ == "__main__":
    main()
