#!/usr/bin/env python3
"""The sweep of Modular's GPU tests for the spec-free theorem `MojoProof.Sem.Kernel.Safe`
(docs/proofs/safe.md): compile, keep, classify.

The sweep works in a state directory outside the repository (`<state>`), one file at a time, so
that every step can stop and resume:

  safe_sweep.py order <src-root> <state>
      lists the `.mojo` files under <src-root>/max/kernels/test/gpu and <src-root>/max/examples
      (an export of modular/modular at one commit) in compile order (`order`): first the files that
      launch a function of roadmap/kernels/universe.tsv by name in an `enqueue_function[...]`
      (`universe_launches`: not a function the file defines itself), then the others; within each
      group, the smaller files first.
      Writes <state>/order.tsv (`rank, path, bytes, arch, universe launches`), the target each file
      is compiled for (`arch_of`) included.
  safe_sweep.py compile <src-root> <state> --mojoc <mojoc.sh> --budget <seconds> [--cores <list>]
      compiles the files of order.tsv that <state>/compile.tsv does not list yet, in order, one at
      a time, until the budget is spent: before each, it reads `free -g` and `mpstat 5 1`, and waits
      (polling every 60 s, within the budget) while the available memory is under 400 GB or the box
      is more than 75% busy. Each compile runs `<mojoc.sh> <state>/out/<rank> <file> <arch>` (the
      Mojo binary from the environment's MOJO) under `taskset -c <cores>` and `/usr/bin/time -v`,
      and appends to compile.tsv: `path, arch, exit, seconds, peak_rss_kb, avail_gb, busy_pct,
      kernels, when`, `kernels` being the per-kernel `.nvptx.ll` files it emitted. A failed compile
      leaves its log in the output directory (`compile.log`).
  safe_sweep.py keep <src-root> <state> <dest>
      copies to <dest> every emitted per-kernel file whose one `ptx_kernel` is a specialization of a
      universe function (`universe_fn`: the kernel's name is the function's name, or starts with it
      followed by `_`; the longest such name) that the compiled file does not define itself
      (`local_defs`), one file per digest (the first in compile order), and
      writes <state>/kept.tsv (`file, source, function, kernel, sha256, arch`).
  safe_sweep.py corpus <src-root> <state> <modular-commit> <nightly>
      adds to the sweep's corpus tests/sweep/<modular-commit>/ (`scripts/corpus.py add --root
      tests/sweep`, its own MANIFEST.tsv) the smallest kept file of each (universe function, test
      file) pair (`corpus_pick`), source `modular/modular@<modular-commit>:<path>`, Mojo version
      <nightly>, lib the file of the universe function the test refers to (`fn_path`; `-` if
      <src-root> has no such file); files already in the manifest are skipped.
  safe_sweep.py revision
      prints the checker revision (`revision`: a digest of `scripts/SafeSweep.lean` and the
      repository modules it imports, transitively, with the toolchain and the manifest), the third
      argument of `lake env lean --run scripts/SafeSweep.lean <state> <files> <revision>`, which
      writes <state>/attempts.tsv (`file, sha256, revision, outcome, reason`) and attempts again
      every kept file with no row at its digest and that revision.
  safe_sweep.py table <src-root> <state> <modular-commit> <nightly> <round>
      writes roadmap/kernels/sweep.tsv (`table`) from order.tsv, compile.tsv, kept.tsv and
      attempts.tsv, each kept file by its attempt at its digest and the current revision, each
      universe function keyed by (source path, name): a test file's launch or specialization of a
      name is of the function `fn_path` resolves from the file's imports under <src-root>.
  safe_sweep.py --self-test
      exits 1 unless `universe_fn`, `arch_of`, `order`, `universe_rows`, `fn_path`, `table` and
      `revision` give the expected results on the cases `self_test` lists.

The outcome of a (universe function, its path, file, specialization, digest) row of sweep.tsv is
one of:
`proved` (a `mojo_safe n := x.prog x.fn_0 at …` of a test module MojoProofTest/Safe*.lean or
MojoProofTest/Sweep*.lean, at the file `x` imports from tests/sweep/ with that digest, not under
`#guard_msgs`, proves `Kernel.Safe` and the witness `n.obs`: `proofs`; the row names that
theorem), `importer refusal` (the importer's
message), `automation failure` (where the automation stopped), `counterexample` (a race, an
out-of-bounds access, a deadlock or a nontermination the checker found), and for a file with no
kept specialization of that function `not compiled` (the round's budget ended before it, the
target is not NVIDIA, or the file built and emitted no specialization of it), `the file does not
build` (the compile's exit and first error line); a
universe function that no compiled file specializes gets one row with `no test launches it` when
no listed file launches it by name, else the outcome of those files.
"""
import collections
import hashlib
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import kernel_universe  # noqa: E402  (read only: its launch scanner)

ROOT = pathlib.Path(__file__).resolve().parent.parent
UNIVERSE = ROOT / 'roadmap' / 'kernels' / 'universe.tsv'
SWEEP = ROOT / 'roadmap' / 'kernels' / 'sweep.tsv'
DIRS = ['max/kernels/test/gpu', 'max/examples']
KERNEL = re.compile(r'^define [^@]*ptx_kernel [^@]*@([\w.$-]+)\(', re.M)
MIN_AVAIL_GB = 400
MAX_BUSY = 75.0
COMPILE_COLS = ['path', 'arch', 'exit', 'seconds', 'peak_rss_kb', 'avail_gb', 'busy_pct', 'kernels',
                'when']
OUTCOMES = ['proved', 'importer refusal', 'automation failure', 'counterexample', 'not compiled',
            'no test launches it', 'the file does not build']


def universe_rows(text: str) -> list[tuple[str, str]]:
    """The functions of universe.tsv's text, each keyed by (source path, name) (its `path` and
    `name` columns, comment lines skipped), in the file's order, without repetition: two functions
    of one name in two files are two rows."""
    out = []
    for line in text.split('\n'):
        cols = line.split('\t')
        if line.startswith('#') or len(cols) < 5 or cols[0] == 'name':
            continue
        if (cols[2], cols[0]) not in out:
            out.append((cols[2], cols[0]))
    return out


def universe_names(text: str) -> list[str]:
    """The function names of universe.tsv's text (`universe_rows`' names), sorted, without
    repetition: the names a test launches or a kernel specializes."""
    return sorted({n for _, n in universe_rows(text)})


IMPORT = re.compile(r'^\s*from\s+([\w.]+)\s+import\s+(\([^)]*\)|[^\n]*)'
                    r'|^\s*import\s+([\w.]+)', re.M)


def imports(text: str) -> list[tuple[str, set[str] | None]]:
    """The modules a Mojo file imports, outside comments and strings: (module, the names `from
    module import ...` brings, `as` renamings by their original name, `*` kept) for a `from`
    import, (module, None) for `import module`."""
    out = []
    for m in IMPORT.finditer(kernel_universe.mojo_code(text)):
        if m.group(3):
            out.append((m.group(3), None))
            continue
        names = {w.split()[0] for w in re.sub(r'[()]', ' ', m.group(2)).split(',') if w.split()}
        out.append((m.group(1), names))
    return out


def module_matches(path: str, module: str) -> bool:
    """Whether the Mojo file at `path` is the module `module` (`a.b.c`): the path, without
    `.mojo` and a final `/__init__`, ends with `/a/b/c` or is `a/b/c`."""
    stem = re.sub(r'(/__init__)?\.mojo$', '', path)
    tail = module.replace('.', '/')
    return stem == tail or stem.endswith('/' + tail)


def fn_path(name: str, text: str, paths: list[str]) -> str | None:
    """The universe function of name `name` that a Mojo file with text `text` refers to, given the
    source paths of the universe's functions of that name (`paths`): the one path when there is
    one, else the one path among them of a module the file imports `name` from (or imports whole),
    else None (the file's imports do not say which)."""
    if len(paths) == 1:
        return paths[0]
    hit = {p for p in paths for mod, ns in imports(text)
           if module_matches(p, mod) and (ns is None or name in ns or '*' in ns)}
    return hit.pop() if len(hit) == 1 else None


def revision(root: pathlib.Path, script: str = 'scripts/SafeSweep.lean') -> str:
    """The checker revision the attempt runs at: the first 16 hexadecimal digits of the SHA-256
    digest of the lines `path<TAB>sha256(file)` (sorted by path, each ending in a line break) of
    `script`, of every repository module it imports, transitively (`import A.B` is the file
    `A/B.lean` under `root` when it exists: the importer, the block checker and the spec-free
    mode, with everything they import), and of `lean-toolchain` and `lake-manifest.json` (the
    Lean release and the dependencies' commits). A digest of the sources, not a commit: a change
    to any of those files, committed or not, is a new revision."""
    todo, seen = [script], set()
    while todo:
        f = todo.pop()
        if f in seen:
            continue
        seen.add(f)
        for m in re.finditer(r'^import\s+([\w.]+)', (root / f).read_text(), re.M):
            g = m.group(1).replace('.', '/') + '.lean'
            if (root / g).is_file():
                todo.append(g)
    seen |= {f for f in ('lean-toolchain', 'lake-manifest.json') if (root / f).is_file()}
    lines = ''.join(f'{f}\t{hashlib.sha256((root / f).read_bytes()).hexdigest()}\n'
                    for f in sorted(seen))
    return hashlib.sha256(lines.encode()).hexdigest()[:16]


def universe_fn(kernel: str, names: list[str]) -> str | None:
    """The universe function kernel `kernel` specializes: the longest name `n` of `names` with
    `kernel == n` or `kernel` starting with `n + '_'` (kernel_universe.proved_functions' rule), or
    None."""
    hit = [n for n in names if kernel == n or kernel.startswith(n + '_')]
    return max(hit, key=len) if hit else None


ARCH_RULES = [
    (re.compile(r'amd|mi300|mi355|rdna|cdna|apple|metal|hip_', re.I), None),
    (re.compile(r'sm100|sm_100|blackwell|b200|tcgen05|umma|sm120|gb10|rtx5090', re.I), 'sm_100a'),
    (re.compile(r'sm90|sm_90|hopper|h100|wgmma|tma|cluster|multistage', re.I), 'sm_90a'),
]


def arch_of(path: str) -> str | None:
    """The target a test file is compiled for, from its path: None (not compiled: an AMD or Apple
    test) for a path naming those targets, `sm_100a` for one naming Blackwell, `sm_90a` for one
    naming Hopper, its TMA or clusters, or the multistage GEMM (as the corpus's rows were),
    `sm_80` otherwise."""
    for pat, arch in ARCH_RULES:
        if pat.search(path):
            return arch
    return 'sm_80'


def local_defs(text: str) -> set[str]:
    """The names of the functions a Mojo file defines itself (`kernel_universe.DEF`, outside
    comments and strings)."""
    lines = kernel_universe.mojo_code(text).split('\n')
    return {m.group(1) for line in lines if (m := kernel_universe.DEF.match(line))}


def universe_launches(text: str, names: list[str]) -> list[str]:
    """The universe functions a Mojo file launches by name: each `enqueue_function[...]` name,
    through the nearest alias above it (`kernel_universe.resolve_in`), that is a universe name and
    not a function the file defines itself (a test's own `kernel`), sorted, without repetition."""
    own = local_defs(text)
    known = set(names) | own
    lines = kernel_universe.mojo_code(text).split('\n')
    out = set()
    for ln, n in kernel_universe.launches(text)[0]:
        t = kernel_universe.resolve_in(lines, ln, n, known)
        if t is not None and t not in own and t in names:
            out.add(t)
    return sorted(out)


def order(files: dict[str, str], names: list[str]) -> list[tuple[str, int, list[str]]]:
    """The compile order of `files` (path -> text): (path, bytes, the universe functions it
    launches by name), the files that launch one first, the smaller files first within each group,
    then by path."""
    rows = []
    for p, text in files.items():
        rows.append((p, len(text.encode()), universe_launches(text, names)))
    return sorted(rows, key=lambda r: (not r[2], r[1], r[0]))


def read_tsv(path: pathlib.Path) -> list[dict]:
    """The rows of a TSV file with a header line, as dicts; [] if the file is missing."""
    if not path.exists():
        return []
    lines = path.read_text().split('\n')
    head = lines[0].split('\t')
    return [dict(zip(head, l.split('\t'))) for l in lines[1:] if l and not l.startswith('#')]


def cmd_order(src: pathlib.Path, state: pathlib.Path) -> int:
    files = {}
    for d in DIRS:
        for p in sorted((src / d).rglob('*.mojo')):
            files[str(p.relative_to(src))] = p.read_text(errors='replace')
    names = universe_names(UNIVERSE.read_text())
    state.mkdir(parents=True, exist_ok=True)
    out = ['rank\tpath\tbytes\tarch\tlaunches']
    for i, (p, n, hits) in enumerate(order(files, names)):
        out.append(f'{i}\t{p}\t{n}\t{arch_of(p) or "-"}\t{",".join(hits) or "-"}')
    (state / 'order.tsv').write_text('\n'.join(out) + '\n')
    hits = sum(1 for line in out[1:] if not line.endswith('\t-'))
    print(f'{len(files)} files, {hits} launch a universe function by name')
    return 0


def box() -> tuple[int, float]:
    """The available memory in GB (`free -g`) and the busy percentage (100 minus mpstat's idle over
    5 s)."""
    free = subprocess.run(['free', '-g'], capture_output=True, text=True).stdout
    mp = subprocess.run(['mpstat', '5', '1'], capture_output=True, text=True).stdout
    free, mp = free.split('\n')[1].split(), mp.strip().split('\n')[-1]
    return int(free[6]), round(100.0 - float(mp.split()[-1]), 1)


def cmd_compile(src: pathlib.Path, state: pathlib.Path, mojoc: str, budget: float,
                cores: str) -> int:
    start = time.time()
    done = {r['path'] for r in read_tsv(state / 'compile.tsv')}
    todo = [r for r in read_tsv(state / 'order.tsv') if r['path'] not in done and r['arch'] != '-']
    log = state / 'compile.tsv'
    if not log.exists():
        log.write_text('\t'.join(COMPILE_COLS) + '\n')
    n = 0
    for r in todo:
        while True:
            avail, busy = box()
            if avail >= MIN_AVAIL_GB and busy <= MAX_BUSY:
                break
            print(f'waiting: {avail} GB available, {busy}% busy', flush=True)
            if time.time() - start + 60 > budget:
                return 0
            time.sleep(60)
        if time.time() - start > budget:
            break
        out = state / 'out' / r['rank']
        if out.exists():
            shutil.rmtree(out)
        out.mkdir(parents=True)
        t0 = time.time()
        p = subprocess.run(['taskset', '-c', cores, '/usr/bin/time', '-v', mojoc, str(out),
                            str(src / r['path']), r['arch']], capture_output=True, text=True)
        secs = round(time.time() - t0, 1)
        text = p.stdout + p.stderr
        (out / 'compile.log').write_text(text)
        rss = re.search(r'Maximum resident set size \(kbytes\): (\d+)', text)
        ks = sorted(f.name for f in out.glob('*.nvptx.ll'))
        # mojoc.sh's exit is that of its last command: the compile failed when it emitted no `.ll`.
        ok = (out / (pathlib.Path(r['path']).stem + '.ll')).exists()
        with log.open('a') as f:
            f.write('\t'.join([r['path'], r['arch'], '0' if ok else '1', str(secs),
                               rss.group(1) if rss else '-', str(avail), str(busy),
                               ','.join(ks) or '-',
                               time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())]) + '\n')
        for f in out.glob('*.mojo'):
            f.unlink()
        n += 1
        print(f'{r["rank"]} {r["path"]} {r["arch"]}: {"ok" if ok else "FAILED"} {secs}s '
              f'{rss.group(1) if rss else "-"} kB, {len(ks)} kernels', flush=True)
    print(f'compiled {n} files in {round(time.time() - start)} s')
    return 0


def kernel_of(text: str) -> str | None:
    """The one `ptx_kernel` of a per-kernel file's text, or None."""
    ks = KERNEL.findall(text)
    return ks[0] if len(ks) == 1 else None


def cmd_keep(src_root: pathlib.Path, state: pathlib.Path, dest: pathlib.Path) -> int:
    names = universe_names(UNIVERSE.read_text())
    own: dict[str, set[str]] = {}
    ranks = {r['path']: r['rank'] for r in read_tsv(state / 'order.tsv')}
    seen = set()
    rows = ['file\tsource\tfunction\tkernel\tsha256\tarch']
    dest.mkdir(parents=True, exist_ok=True)
    for c in sorted(read_tsv(state / 'compile.tsv'), key=lambda c: int(ranks[c['path']])):
        if c['kernels'] == '-':
            continue
        for k in c['kernels'].split(','):
            f = state / 'out' / ranks[c['path']] / k
            text = f.read_text()
            kern = kernel_of(text)
            fn = universe_fn(kern, names) if kern else None
            if fn is not None and fn in own.setdefault(c['path'], local_defs(
                    (src_root / c['path']).read_text(errors='replace') if src_root else '')):
                fn = None
            digest = hashlib.sha256(f.read_bytes()).hexdigest()
            if fn is None or digest in seen:
                continue
            seen.add(digest)
            shutil.copyfile(f, dest / k)
            rows.append(f'{k}\t{c["path"]}\t{fn}\t{kern}\t{digest}\t{c["arch"]}')
    (state / 'kept.tsv').write_text('\n'.join(rows) + '\n')
    print(f'kept {len(rows) - 1} files')
    return 0


def corpus_pick(kept: list[dict], sizes: dict[str, int]) -> list[dict]:
    """The kept rows the sweep's corpus holds: for each (function, source) pair, the row of the
    smallest file (`sizes`: file name -> bytes), the first in `kept`'s order among equals."""
    best: dict[tuple[str, str], dict] = {}
    for k in kept:
        key = (k['function'], k['source'])
        if key not in best or sizes[k['file']] < sizes[best[key]['file']]:
            best[key] = k
    return sorted(best.values(), key=lambda k: k['file'])


def cmd_corpus(src: pathlib.Path, state: pathlib.Path, commit: str, nightly: str) -> int:
    kept = read_tsv(state / 'kept.tsv')
    files = state / 'kept'
    sizes = {k['file']: (files / k['file']).stat().st_size for k in kept}
    where = where_in(src, universe_rows(UNIVERSE.read_text()))
    root = ROOT / 'tests' / 'sweep'
    have = {r['path'] for r in read_tsv(root / 'MANIFEST.tsv')}
    n = size = 0
    for k in corpus_pick(kept, sizes):
        size += sizes[k['file']]
        if f'{commit}/{k["file"]}' in have:
            continue
        lp = where(k['function'], k['source']) or '-'
        p = subprocess.run([sys.executable, str(ROOT / 'scripts' / 'corpus.py'), 'add', '--root',
                            'tests/sweep', '--mojo', nightly,
                            '--lib', lp if (src / lp).is_file() else '-', commit,
                            str(src / k['source']), f'modular/modular@{commit}:{k["source"]}',
                            f'--emit llvm --target-accelerator {k["arch"]}',
                            str(files / k['file'])],
                           capture_output=True, text=True)
        if p.returncode != 0:
            print(f'{k["file"]}: corpus.py add failed: {(p.stdout + p.stderr).strip()}')
            return 1
        n += 1
    print(f'added {n} files; the sweep corpus holds {size} bytes of kept files')
    return 0


def first_error(log: str) -> str:
    """The first line of a compile log that says `error`, shortened, or `exit` and nothing else."""
    for line in log.split('\n'):
        if 'error' in line.lower():
            return re.sub(r'\s+', ' ', line.split('error:', 1)[-1]).strip()[:160]
    return 'no error line'


PROOF_IMPORT = re.compile(r'set_option mojo_import\.root "tests/sweep" in\s*\n'
                          r'mojo_import "([^"]+)" as (\w+)')
PROOF_SAFE = re.compile(r'^(#guard_msgs.*\n)?mojo_safe (\w+) := (\w+)\.prog \3\.fn_0\s+at\b', re.M)


def proofs(texts: dict[str, str], digest) -> dict[str, str]:
    """The `proved` rows' theorems, by digest: in each test module's text (`texts`, by module
    path), each `mojo_safe n := x.prog x.fn_0 at …` that no `#guard_msgs` line precedes (a refused
    twin), where `x` is a `mojo_import "<p>" as x` under `set_option mojo_import.root
    "tests/sweep"`, gives `digest(<p>)` (the SHA-256 of tests/sweep/<p>) the theorem `<ns>.n.obs`
    (`ns` the module's first `namespace`)."""
    out = {}
    for _, t in sorted(texts.items()):
        ns = re.search(r'^namespace (\S+)', t, re.M)
        imps = {x: f for f, x in PROOF_IMPORT.findall(t)}
        for g, n, x in PROOF_SAFE.findall(t):
            if not g and x in imps:
                out.setdefault(digest(imps[x]), (ns.group(1) + '.' if ns else '') + n + '.obs')
    return out


def table(fns: list[tuple[str, str]], where, order_rows: list[dict], compiled: list[dict],
          kept: list[dict], attempts: list[dict], rev: str, logs: dict[str, str],
          header: str, proved: dict[str, str] | None = None) -> str:
    """sweep.tsv's text (the module docstring's outcomes), its functions keyed by (source path,
    name) (`fns`, `universe_rows`), `where(name, test file)` naming the path of the function a test
    file refers to by that name (`fn_path`, `-` when its imports do not say which): a row per kept
    file, by the outcome of its attempt at its digest and the checker revision `rev` (`automation
    failure` with reason `not attempted at revision <rev>` when attempts.tsv has no row with that
    digest and revision: an attempt at another revision or at another digest is not reused), per
    (function, compiled file with no kept specialization of it) when the file launches the
    function by name, per (function, file not compiled or failed) for the files that launch it by
    name, and one row per universe function with none of those. A kept file whose digest has a
    theorem in `proved` (`proofs`) is `proved`, with that theorem."""
    rows = []
    proved = proved or {}
    by_key = {(a['sha256'], a['revision']): a for a in attempts}
    comp = {c['path']: c for c in compiled}
    has = collections.defaultdict(list)
    none = {'outcome': 'automation failure', 'reason': f'not attempted at revision {rev}'}
    for k in kept:
        a = by_key.get((k['sha256'], rev), none)
        if k['sha256'] in proved:
            a = {'outcome': 'proved', 'reason': f'{proved[k["sha256"]]} (mojo_safe, with '
                 f'Kernel.Safe at the admission Kernel.Admits for every launch)'}
        fp = where(k['function'], k['source']) or '-'
        rows.append((k['function'], fp, k['source'], k['kernel'], k['sha256'], a['outcome'],
                     a['reason']))
        has[fp, k['function']].append(k['source'])
    launched = collections.defaultdict(list)
    for r in order_rows:
        for n in (r['launches'].split(',') if r['launches'] != '-' else []):
            launched[where(n, r['path']) or '-', n].append(r)
    names = {n for _, n in fns}
    for fp, n in sorted(set(fns) | {(fp, n) for fp, n in launched if fp == '-' and n in names}):
        for r in launched.get((fp, n), []):
            if r['path'] in has[fp, n]:
                continue
            c = comp.get(r['path'])
            if r['arch'] == '-':
                out, why = 'not compiled', 'an AMD or Apple test'
            elif c is None:
                out, why = 'not compiled', 'not reached this round'
            elif c['exit'] != '0':
                out, why = 'the file does not build', first_error(logs.get(r['path'], ''))
            else:
                out = 'not compiled'
                why = f'the file built at {c["arch"]} and emitted no specialization of it'
            rows.append((n, fp, r['path'], '-', '-', out, why))
        if fp != '-' and not has[fp, n] and not launched.get((fp, n)):
            why = ('no listed file launches it by name' if not any(
                m == n for _, m in launched) else 'the files that launch its name launch '
                'another function of that name, or do not say which')
            rows.append((n, fp, '-', '-', '-', 'no test launches it', why))
    rows.sort()
    return header + '\nfunction\tpath\tfile\tspecialization\tsha256\toutcome\treason\n' + \
        ''.join('\t'.join(r) + '\n' for r in rows)


def where_in(src: pathlib.Path, fns: list[tuple[str, str]]):
    """`fn_path` at the test files under `src` (read once each): the path of the universe function
    of a name that a test file refers to, or None."""
    paths = collections.defaultdict(list)
    for fp, n in fns:
        paths[n].append(fp)
    texts: dict[str, str] = {}

    def where(name: str, test: str) -> str | None:
        if test not in texts:
            f = src / test
            texts[test] = f.read_text(errors='replace') if f.is_file() else ''
        return fn_path(name, texts[test], paths.get(name, []))
    return where


def cmd_table(src: pathlib.Path, state: pathlib.Path, commit: str, nightly: str, rnd: str) -> int:
    fns = universe_rows(UNIVERSE.read_text())
    order_rows = read_tsv(state / 'order.tsv')
    ranks = {r['path']: r['rank'] for r in order_rows}
    compiled = read_tsv(state / 'compile.tsv')
    logs = {}
    for c in compiled:
        lf = state / 'out' / ranks[c['path']] / 'compile.log'
        logs[c['path']] = lf.read_text() if lf.exists() else ''
    rev = revision(ROOT)
    header = (f'# The breadth sweep at modular/modular@{commit}, Mojo {nightly}, round {rnd}, '
              f'checker revision {rev}, written by scripts/safe_sweep.py table: '
              f'{len(order_rows)} test files, {len(compiled)} compiled this round.')
    tests = {str(f.relative_to(ROOT)): f.read_text() for pat in ('Safe*.lean', 'Sweep*.lean')
             for f in (ROOT / 'MojoProofTest').glob(pat)}
    proved = proofs(tests, lambda p: hashlib.sha256((ROOT / 'tests' / 'sweep' / p).read_bytes())
                    .hexdigest())
    text = table(fns, where_in(src, fns), order_rows, compiled, read_tsv(state / 'kept.tsv'),
                 read_tsv(state / 'attempts.tsv'), rev, logs, header, proved)
    SWEEP.write_text(text)
    counts = collections.Counter(l.split('\t')[5] for l in text.split('\n')[2:] if l)
    print(', '.join(f'{o} {counts[o]}' for o in OUTCOMES))
    return 0


def self_test() -> int:
    bad = 0

    def check(what, got, want):
        nonlocal bad
        if got != want:
            print(f'FAIL {what}: got {got!r}, want {want!r}')
            bad += 1
    names = ['gemv_kernel', 'gemv_kernel_vector', 'vector_addition', 'k']
    check('universe_fn exact', universe_fn('vector_addition', names), 'vector_addition')
    check('universe_fn longest', universe_fn('gemv_kernel_vector_float32_7', names),
          'gemv_kernel_vector')
    check('universe_fn prefix needs _', universe_fn('gemv_kernelx', names), None)
    check('arch amd', arch_of('max/kernels/test/gpu/linalg/test_amd_matmul_asm.mojo'), None)
    sm100 = 'max/kernels/test/gpu/linalg/test_matmul_sm100_bf16.mojo'
    check('arch sm100', arch_of(sm100), 'sm_100a')
    check('arch tma', arch_of('max/kernels/test/gpu/layout/tma/test_tma_load.mojo'), 'sm_90a')
    check('arch default', arch_of('max/examples/gpu-functions/vector_addition.mojo'), 'sm_80')
    own = 'def k():\n    pass\nctx.enqueue_function[k, k]()\n'
    check('own kernel', universe_launches(own, names), [])
    alias = 'comptime kk = mod.gemv_kernel\nctx.enqueue_function[kk, kk]()\n'
    check('alias', universe_launches(alias, names), ['gemv_kernel'])
    files = {'b.mojo': 'x' * 50 + '\nctx.enqueue_function[k, k]()\n', 'a.mojo': 'x' * 10,
             'c.mojo': '# ctx.enqueue_function[k, k]()\n',
             'd.mojo': 'ctx.enqueue_function[k, k]()\n'}
    check('order', [p for p, _, _ in order(files, names)], ['d.mojo', 'b.mojo', 'a.mojo', 'c.mojo'])
    orows = [dict(rank='0', path='d.mojo', bytes='1', arch='sm_80', launches='k'),
             dict(rank='1', path='b.mojo', bytes='2', arch='sm_80', launches='k'),
             dict(rank='2', path='e.mojo', bytes='3', arch='-', launches='vector_addition')]
    orows.append(dict(rank='3', path='f.mojo', bytes='4', arch='sm_80', launches='k'))
    comp = [dict(path='d.mojo', arch='sm_80', exit='0', kernels='d_k_1.nvptx.ll'),
            dict(path='b.mojo', arch='sm_80', exit='1', kernels='-'),
            dict(path='f.mojo', arch='sm_80', exit='0', kernels='f_other_1.nvptx.ll')]
    kept = [dict(file='d_k_1.nvptx.ll', source='d.mojo', function='k', kernel='k_1', sha256='aa',
                 arch='sm_80'),
            dict(file='d_k_2.nvptx.ll', source='d.mojo', function='k', kernel='k_2', sha256='bb',
                 arch='sm_80'),
            dict(file='d_k_3.nvptx.ll', source='d.mojo', function='k', kernel='k_3', sha256='cc',
                 arch='sm_80')]
    # the attempt at k_1 is at the current revision `r1`; k_2's at an older one; the row at k_3's
    # file name is of another digest: neither is reused
    att = [dict(file='d_k_1.nvptx.ll', sha256='aa', revision='r1', outcome='proved', reason='-'),
           dict(file='d_k_2.nvptx.ll', sha256='bb', revision='r0', outcome='proved', reason='-'),
           dict(file='d_k_3.nvptx.ll', sha256='dd', revision='r1', outcome='proved', reason='-')]
    fns = [('g.mojo', n) for n in names]
    lib = 'max/kernels/src/nn/attention/gpu/'
    fns += [(lib + 'mha.mojo', '_bmm0_bs'), (lib + 'mha_cross.mojo', '_bmm0_bs')]
    check('universe_rows', universe_rows(
        'name\tarea\tpath\tline\tlaunch_sites\n# c\n'
        f'_bmm0_bs\tnn\t{lib}mha.mojo\t6273\t1\n_bmm0_bs\tnn\t{lib}mha_cross.mojo\t47\t1\n'),
          [(lib + 'mha.mojo', '_bmm0_bs'), (lib + 'mha_cross.mojo', '_bmm0_bs')])
    bmm = 'from nn.attention.gpu.mha import (\n    _bmm0_bs,\n    _bmm1_bs as b1,\n)\n'
    two = [lib + 'mha.mojo', lib + 'mha_cross.mojo']
    check('fn_path by import', fn_path('_bmm0_bs', bmm, two), lib + 'mha.mojo')
    check('fn_path renamed', fn_path('_bmm1_bs', bmm, two), lib + 'mha.mojo')
    check('fn_path whole module', fn_path('_bmm0_bs', 'import nn.attention.gpu.mha_cross\n', two),
          lib + 'mha_cross.mojo')
    check('fn_path unsaid', fn_path('_bmm0_bs', '# from nn.attention.gpu.mha import _bmm0_bs\n',
                                    two), None)
    orows.append(dict(rank='4', path='h.mojo', bytes='5', arch='-', launches='_bmm0_bs'))
    texts = {'h.mojo': bmm}
    paths = collections.defaultdict(list)
    for fp, n in fns:
        paths[n].append(fp)
    got = table(fns, lambda n, t: fn_path(n, texts.get(t, ''), paths[n]), orows, comp, kept, att,
                'r1', {'b.mojo': 'mojo: error: no such module\n'}, '# h')
    want = ('# h\nfunction\tpath\tfile\tspecialization\tsha256\toutcome\treason\n'
            f'_bmm0_bs\t{lib}mha.mojo\th.mojo\t-\t-\tnot compiled\tan AMD or Apple test\n'
            f'_bmm0_bs\t{lib}mha_cross.mojo\t-\t-\t-\tno test launches it\tthe files that '
            'launch its name launch another function of that name, or do not say which\n'
            'gemv_kernel\tg.mojo\t-\t-\t-\tno test launches it\tno listed file launches it by '
            'name\n'
            'gemv_kernel_vector\tg.mojo\t-\t-\t-\tno test launches it\tno listed file launches '
            'it by name\n'
            'k\tg.mojo\tb.mojo\t-\t-\tthe file does not build\tno such module\n'
            'k\tg.mojo\td.mojo\tk_1\taa\tproved\t-\n'
            'k\tg.mojo\td.mojo\tk_2\tbb\tautomation failure\tnot attempted at revision r1\n'
            'k\tg.mojo\td.mojo\tk_3\tcc\tautomation failure\tnot attempted at revision r1\n'
            'k\tg.mojo\tf.mojo\t-\t-\tnot compiled\t'
            'the file built at sm_80 and emitted no specialization of it\n'
            'vector_addition\tg.mojo\te.mojo\t-\t-\tnot compiled\tan AMD or Apple test\n')
    check('table', got, want)
    lean = ('namespace T\nset_option mojo_import.root "tests/sweep" in\n'
            'mojo_import "c/a.ll" as a\nmojo_import "c/b.ll" as b\n'
            'mojo_safe n := a.prog a.fn_0\n  at L args m ch ω hm\n'
            '#guard_msgs in\nmojo_safe tw := a.prog a.fn_0\n  at L args m ch ω hm\n'
            'mojo_safe u := b.prog b.fn_0\n  at L args m ch ω hm\nmojo_safe v := a.prog a.fn_0\n')
    check('proofs', proofs({'M.lean': lean}, lambda p: p.upper()), {'C/A.LL': 'T.n.obs'})
    got = table(fns, lambda n, t: fn_path(n, texts.get(t, ''), paths[n]), orows, comp, kept, att,
                'r1', {'b.mojo': 'mojo: error: no such module\n'}, '# h', {'cc': 'T.n.obs'})
    check('table proved', [l.split('\t')[5:] for l in got.split('\n') if '\tcc\t' in l],
          [['proved', 'T.n.obs (mojo_safe, with Kernel.Safe at the admission Kernel.Admits for '
            'every launch)']])
    with tempfile.TemporaryDirectory() as d:
        r = pathlib.Path(d)
        (r / 'scripts').mkdir()
        (r / 'A').mkdir()
        (r / 'scripts' / 'SafeSweep.lean').write_text('import A.B\nimport Lean\n')
        (r / 'A' / 'B.lean').write_text('import A.C\n')
        (r / 'A' / 'C.lean').write_text('def c := 1\n')
        (r / 'A' / 'D.lean').write_text('def d := 1\n')
        r0 = revision(r)
        (r / 'A' / 'D.lean').write_text('def d := 2\n')
        check('revision: a file not imported', revision(r), r0)
        (r / 'A' / 'C.lean').write_text('def c := 2\n')
        check('revision: an imported file changed', revision(r) != r0, True)
    picks = corpus_pick([dict(file='x1', function='f', source='s'),
                         dict(file='x2', function='f', source='s'),
                         dict(file='x3', function='f', source='t')], {'x1': 9, 'x2': 4, 'x3': 7})
    check('corpus_pick', [k['file'] for k in picks], ['x2', 'x3'])
    print(f'self-test: {bad} failures')
    return 1 if bad else 0


def main(argv: list[str]) -> int:
    a = argv[1:]
    if a == ['--self-test']:
        return self_test()
    if a[:1] == ['order'] and len(a) == 3:
        return cmd_order(pathlib.Path(a[1]), pathlib.Path(a[2]))
    if a[:1] == ['compile'] and len(a) >= 3:
        opts = dict(zip(a[3::2], a[4::2]))
        if '--mojoc' not in opts or '--budget' not in opts:
            print(__doc__)
            return 2
        return cmd_compile(pathlib.Path(a[1]), pathlib.Path(a[2]), opts['--mojoc'],
                           float(opts['--budget']), opts.get('--cores', '48-55'))
    if a[:1] == ['keep'] and len(a) == 4:
        return cmd_keep(pathlib.Path(a[1]), pathlib.Path(a[2]), pathlib.Path(a[3]))
    if a[:1] == ['corpus'] and len(a) == 5:
        return cmd_corpus(pathlib.Path(a[1]), pathlib.Path(a[2]), a[3], a[4])
    if a[:1] == ['table'] and len(a) == 6:
        return cmd_table(pathlib.Path(a[1]), pathlib.Path(a[2]), a[3], a[4], a[5])
    if a == ['revision']:
        print(revision(ROOT))
        return 0
    print(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
