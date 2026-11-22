#!/usr/bin/env python3
"""Corpus manifest for tests/corpus.

  corpus.py import <study-ir-dir>   copy every *.nvptx.ll of the study into tests/corpus/<family>/ and
                                    write tests/corpus/MANIFEST.tsv
  corpus.py check                   recompute every sha256 and line count and compare with the manifest
  corpus.py add [--mojo VERSION] <family> <src.mojo> <modular-path> <flags> <file.nvptx.ll>...
                                    add files compiled with `mojo build --emit llvm` to the
                                    manifest; a <modular-path> of the form repo:<path> records a
                                    source written for this repository, at <path> in it; VERSION
                                    is the Mojo version recorded in the rows (default: the pinned
                                    version MOJO); a file whose name is already listed is refused
                                    before anything is copied

Columns: path, sha256, lines, kernel (the one `ptx_kernel` define), arch and PTX version (from the
"target-cpu"/"target-features" attributes), Mojo version, flags passed to `mojo build`, the Mojo source
(path in modular/modular at the recorded commit, or repo:<path> for a source written for this
repository, whose sha256 `check` also compares) and that source's sha256.
"""
import hashlib, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORPUS = os.path.join(ROOT, "tests", "corpus")
MANIFEST = os.path.join(CORPUS, "MANIFEST.tsv")
MOJO = "1.3.0.dev2026111705 (298d4f45)"
MODULAR = "modular/modular@bbc13a71"
COLS = ["path", "sha256", "lines", "kernel", "arch", "ptx", "mojo", "flags", "source", "source_sha256"]
# Study families: directory -> Mojo source path in modular/modular.
SOURCES = {
    "vadd": "max/examples/gpu-functions/vector_addition.mojo",
    "tiled_matmul": "max/examples/gpu-block-and-warp/tiled_matmul.mojo",
    "reduction": "max/examples/gpu-functions/reduction.mojo",
    "layernorm": "max/kernels/test/gpu/nn/test_layer_norm.mojo",
    "mma": "max/kernels/test/gpu/layout/test_layout_mma.mojo",
    "mgemm": "max/kernels/test/gpu/linalg/test_multistage_gemm_kernel.mojo",
}


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def describe(path):
    text = open(path, encoding="utf-8").read()
    kernels = re.findall(r"^define [^@]*ptx_kernel [^@]*@([\w.$-]+)\(", text, re.M)
    if len(kernels) != 1:
        sys.exit(f"{path}: expected one ptx_kernel define, found {len(kernels)}")
    cpu = set(re.findall(r'"target-cpu"="([^"]*)"', text))
    feat = set(re.findall(r'"target-features"="([^"]*)"', text))
    if len(cpu) != 1 or len(feat) != 1:
        sys.exit(f"{path}: expected one target-cpu and one target-features, found {cpu} {feat}")
    ptx = [f for f in feat.pop().split(",") if f.startswith("+ptx")]
    return kernels[0], cpu.pop(), ptx[0][1:] if ptx else "-", text.count("\n")


def read():
    rows = []
    with open(MANIFEST, encoding="utf-8") as f:
        header = f.readline().rstrip("\n").split("\t")
        assert header == COLS, header
        for line in f:
            rows.append(dict(zip(COLS, line.rstrip("\n").split("\t"))))
    return rows


def write(rows):
    rows = sorted(rows, key=lambda r: r["path"])
    with open(MANIFEST, "w", encoding="utf-8") as f:
        f.write("\t".join(COLS) + "\n")
        for r in rows:
            f.write("\t".join(r[c] for c in COLS) + "\n")


def row(rel, flags, source, source_sha, mojo=MOJO):
    kernel, arch, ptx, lines = describe(os.path.join(CORPUS, rel))
    return dict(path=rel, sha256=sha(os.path.join(CORPUS, rel)), lines=str(lines), kernel=kernel,
                arch=arch, ptx=ptx, mojo=mojo, flags=flags,
                source=source if source.startswith("repo:") else f"{MODULAR}:{source}",
                source_sha256=source_sha)


def cmd_import(study):
    import shutil
    rows = []
    for fam, src in SOURCES.items():
        d = os.path.join(study, fam)
        src_sha = sha(os.path.join(d, os.path.basename(src)))
        os.makedirs(os.path.join(CORPUS, fam), exist_ok=True)
        for name in sorted(os.listdir(d)):
            if name.endswith(".nvptx.ll"):
                shutil.copyfile(os.path.join(d, name), os.path.join(CORPUS, fam, name))
                rows.append(row(f"{fam}/{name}", "--emit llvm --target-accelerator " +
                                describe(os.path.join(d, name))[1], src, src_sha))
    write(rows)
    print(f"{len(rows)} files")


def cmd_add(fam, src_file, src_path, flags, files, mojo=MOJO):
    import shutil
    if not mojo or any(c in mojo for c in "\t\n\r"):
        sys.exit(f"bad Mojo version {mojo!r}")
    rows = read()
    known = {r["path"] for r in rows}
    rels = [f"{fam}/{os.path.basename(p)}" for p in files]
    for rel in rels:
        if rel in known or rels.count(rel) > 1:
            sys.exit(f"{rel} is already in the manifest or given twice")
    os.makedirs(os.path.join(CORPUS, fam), exist_ok=True)
    for p, rel in zip(files, rels):
        shutil.copyfile(p, os.path.join(CORPUS, rel))
        rows.append(row(rel, flags, src_path, sha(src_file), mojo))
    write(rows)


def cmd_check():
    rows = read()
    bad = 0
    on_disk = {os.path.relpath(os.path.join(dp, n), CORPUS)
               for dp, _, ns in os.walk(CORPUS) for n in ns if n.endswith(".ll")}
    for r in rows:
        p = os.path.join(CORPUS, r["path"])
        if not os.path.exists(p):
            print(f"MISSING {r['path']}"); bad += 1; continue
        kernel, arch, ptx, lines = describe(p)
        got = dict(sha256=sha(p), lines=str(lines), kernel=kernel, arch=arch, ptx=ptx)
        if r["source"].startswith("repo:"):
            got["source_sha256"] = sha(os.path.join(ROOT, r["source"][len("repo:"):]))
        for k, v in got.items():
            if r[k] != v:
                print(f"MISMATCH {r['path']} {k}: manifest {r[k]}, file {v}"); bad += 1
    for extra in sorted(on_disk - {r["path"] for r in rows}):
        print(f"UNLISTED {extra}"); bad += 1
    print(f"corpus: {len(rows)} files, {bad} problems")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["import"] and len(a) == 2:
        cmd_import(a[1])
    elif a[:1] == ["check"]:
        cmd_check()
    elif a[:1] == ["add"]:
        mojo, a = MOJO, a[1:]
        if a[:1] == ["--mojo"] and len(a) >= 2:
            mojo, a = a[1], a[2:]
        elif a[:1] and a[0].startswith("--mojo="):
            mojo, a = a[0][len("--mojo="):], a[1:]
        if len(a) < 5:
            sys.exit(__doc__)
        cmd_add(a[0], a[1], a[2], a[3], a[4:], mojo)
    else:
        sys.exit(__doc__)
