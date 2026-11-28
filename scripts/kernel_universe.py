"""The GPU kernels in Modular's repository, for the coverage page (roadmap/kernels/universe.tsv).

A kernel here is a Mojo function that some code in max/kernels/src, max/examples or Mojo/examples launches on a GPU
with `DeviceContext.enqueue_function` (or its `_checked`, `_experimental` and `_collective_checked` forms). Each
launch names the function directly or through a `comptime`/`alias` in the launching file; this script follows the
nearest such alias above the launch, one step, and records the function's definition in those same directories. A
dotted name (`Self._kernel`, `Kernel.run`, directly or as an alias's target) names the function by its last
component, cited at the definition `where` picks (the launching file's, else its package's, else the first). Kernels
launched only through other paths (the
`elementwise` helper, which builds a kernel from a closure, and launches behind further indirection) are not in
the list; the elementwise call sites are counted on the summary line instead.

The scanner reads every file that mentions `enqueue_function` whole, with its comments and the contents of its string
literals blanked (`mojo_code`), so a launch whose `[` and the function's name are on different lines counts, and a
launch in a comment or a docstring does not. A use of `enqueue_function` that names no function in brackets (a
compiled function passed as a value) is counted on the summary line, with the first few listed (`launches`).

Usage:
  python3 scripts/kernel_universe.py universe <modular-clone> <commit>
      writes roadmap/kernels/universe.tsv; reads the clone with `git show` and `git grep` only.
  python3 scripts/kernel_universe.py history
      writes roadmap/kernels/proved.tsv (Modular's kernel functions with a kernel theorem at the last commit of each
      day, `proved_functions`, from the day roadmap/llvm-ir/programs.tsv was first written) and
      roadmap/kernels/theorems.tsv (the `theorem` and `lemma` declarations in the source of the library and of
      MojoProofTest at the last commit of each day, `count_theorems`), from this repository's history. It needs the
      full history, so it runs on a clone, not in CI; the site adds the current tree's numbers when it is built, so
      the figure is never older than the site.
  python3 scripts/kernel_universe.py --self-test
      exits 1 unless the launch scanner and the theorem counter read the cases `self_test` lists as they should.
"""
import collections
import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import cited  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'roadmap' / 'kernels' / 'universe.tsv'
PATHS = ['max/kernels/src', 'max/examples', 'Mojo/examples']
LAUNCH = re.compile(r'\benqueue_function(?:_checked|_experimental|_collective_checked)?\[\s*([A-Za-z_][A-Za-z0-9_.]*)')
DEF = re.compile(r'^\s*(?:@[A-Za-z_][\w.]*(?:\[[^\]]*\]|\([^)]*\))?\s*)*(?:def|fn)\s+([A-Za-z_][A-Za-z0-9_]*)\s*[\[(]')
ALIAS = re.compile(r'^\s*(?:comptime|alias|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=]*)?=\s*([A-Za-z_][A-Za-z0-9_.]*)')
USE = re.compile(r'\benqueue_function(?:_checked|_experimental|_collective_checked)?\b')


def mojo_code(text: str) -> str:
    """`text` with every `#` comment and the contents of every string literal (`"…"`, `'…'`, and the triple-quoted
    forms, docstrings among them) replaced by spaces, line breaks kept, so offsets and line numbers are the text's."""
    out = list(text)

    def blank(a: int, b: int) -> None:
        for k in range(a, b):
            if out[k] != '\n':
                out[k] = ' '
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == '#':
            j = text.find('\n', i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
        elif c in '"\'':
            q = c * 3 if text.startswith(c * 3, i) else c
            j = i + len(q)
            while j < n and not text.startswith(q, j) and not (len(q) == 1 and text[j] == '\n'):
                j += 2 if text[j] == '\\' else 1
            j = min(j, n)
            blank(i + len(q), j)
            i = j + (len(q) if text.startswith(q, j) else 0)
        else:
            i += 1
    return ''.join(out)


def launches(text: str) -> tuple[list[tuple[int, str]], list[int]]:
    """The launches of a Mojo file: (line, launched name) for each `enqueue_function[` form, whose name may be on a
    later line than the bracket, and the lines of the other uses of `enqueue_function` (no bracket: a compiled
    function passed as a value), both in `mojo_code(text)`, so never in a comment or a string. A launched name with a
    dot (`Self._kernel`, `mod.kernel`) is its last component; a definition of a method named `enqueue_function`
    (a wrapper's `def enqueue_function[...]`) is no use."""
    code = mojo_code(text)
    found, other = [], []
    named = {m.start(): m for m in LAUNCH.finditer(code)}
    for u in USE.finditer(code):
        if re.search(r'\b(?:def|fn)\s+$', code[code.rfind('\n', 0, u.start()) + 1:u.start()]):
            continue
        line = code.count('\n', 0, u.start()) + 1
        if u.start() in named:
            found.append((line, named[u.start()].group(1).split('.')[-1]))
        else:
            other.append(line)
    return found, other


def resolve_in(lines: list[str], ln: int, name: str, defs) -> str | None:
    """The function a launch at line `ln` of a file (its `mojo_code` lines) names: the nearest alias of that name at
    or above the launch (files define several `comptime kernel = ...` in different scopes), else the name itself;
    `None` when that is no function of `defs` (a type parameter)."""
    for line in reversed(lines[:ln]):
        if (m := ALIAS.match(line)) and m.group(1) == name:
            target = m.group(2).split('.')[-1]
            return target if target in defs else None
    return name if name in defs else None


def git(clone: str, *args: str) -> str:
    return subprocess.run(['git', '-C', clone, *args], check=True, capture_output=True, text=True).stdout


def area(path: str) -> str:
    """The area of a definition: max/kernels/src/<area>/..., or the examples."""
    parts = path.split('/')
    if parts[:3] == ['max', 'kernels', 'src'] and len(parts) > 4:
        return parts[3]
    if parts[:3] == ['max', 'kernels', 'src']:
        return 'misc'
    return 'examples'


THEOREM = re.compile(r'^\s*(?:@\[[^\]]*\]\s*)?(?:(?:private|protected|noncomputable|nonrec)\s+)*(?:theorem|lemma)\s+(?!\$)')
LIBRARY = ['GPUProof', 'MojoProof']
TESTS = ['MojoProofTest']


def count_theorems(text: str) -> int:
    """The `theorem` and `lemma` declarations of a Lean file's text: the lines that start one once its comments
    (docstrings among them), string and char literals are blanked (cited.py's lexer, `cited.lex`), with a quoted
    declaration whose name is an antiquotation (`theorem $id`, a command's template) left out. The theorems a command
    generates (`mojo_kernel`'s `covers`, `sound` and the rest) are not in the text and are not counted."""
    spans: list[tuple[int, int]] = []
    ends: dict[int, tuple[int, bool]] = {}
    cited.lex(text, 0, spans, ends)
    chars = list(text)
    for a, b in spans + [(a, b) for b, (a, _) in ends.items()]:
        chars[a:b] = re.sub(r'[^\n]', ' ', text[a:b])
    return sum(1 for line in ''.join(chars).split('\n') if THEOREM.match(line))


def theorems_at(here: str, rev: str, cache: dict[str, int]) -> tuple[int, int]:
    """(library, tests): `count_theorems` summed over the Lean files of `LIBRARY` and `TESTS` at commit `rev`, each
    blob read once (`cache`, by its hash)."""
    blobs = [l.split(None, 3)[2:] for l in git(here, 'ls-tree', '-r', rev, '--', *LIBRARY, *TESTS).splitlines()]
    blobs = [(h, f) for h, f in blobs if f.endswith('.lean')]
    todo = sorted({h for h, _ in blobs} - cache.keys())
    if todo:
        raw = subprocess.run(['git', '-C', here, 'cat-file', '--batch'], input=('\n'.join(todo) + '\n').encode(),
                             capture_output=True, check=True).stdout
        i = 0
        for h in todo:
            head_end = raw.index(b'\n', i)
            size = int(raw[i:head_end].split()[2])
            cache[h] = count_theorems(raw[head_end + 1:head_end + 1 + size].decode('utf-8', 'replace'))
            i = head_end + 1 + size + 1
    lib = sum(cache[h] for h, f in blobs if f.split('/')[0] in LIBRARY)
    return lib, sum(cache[h] for h, f in blobs if f.split('/')[0] in TESTS)


MANIFEST_COLS = ['path', 'sha256', 'lines', 'kernel', 'arch', 'ptx', 'mojo', 'flags', 'source', 'source_sha256', 'lib']


def universe_rows(text: str) -> list[dict]:
    """The rows of universe.tsv's text: name, area, path, line, launch sites."""
    rows = []
    for line in text.split('\n'):
        if line and not line.startswith('#') and not line.startswith('name\t'):
            n, a, p, ln, s = line.split('\t')
            rows.append({'name': n, 'area': a, 'path': p, 'line': int(ln), 'sites': int(s)})
    return rows


def theorem_kinds(kinds: str) -> dict[str | tuple[str, str], str]:
    """Each theorem's kind from the text of roadmap/llvm-ir/kinds.tsv (scripts/L3Programs.lean): `correct` for a kernel
    theorem whose relation is not the trivial one, `safe` for the spec-free statement (no fault, race free, one
    observation for every schedule, with no claim about the output's values). A row `theorem, program, kind` gives the
    kind of that theorem's soundness term about that program, keyed `(theorem, program)`; a row `theorem, kind` (the
    table before it had a program column) the theorem's, keyed by its name."""
    out: dict[str | tuple[str, str], str] = {}
    for line in kinds.split('\n'):
        cols = line.split('\t')
        if cols[0] == 'theorem' or line.startswith('#'):
            continue
        if len(cols) == 3:
            out[(cols[0], cols[1])] = cols[2]
        elif len(cols) == 2:
            out[cols[0]] = cols[1]
    return out


def proved_functions(programs: str, manifest: str, rows: list[dict], kinds: str | None = None,
                     kind: str = 'correct') -> dict[tuple[str, str], list[tuple[str, str, str]]]:
    """Modular's kernel functions with a kernel theorem of kind `kind`, from the texts of roadmap/llvm-ir/programs.tsv
    (each theorem, the corpus file its program is bound to by its term, and the digest; scripts/L3Programs.lean), of
    roadmap/llvm-ir/kinds.tsv (`theorem_kinds`; None reads this tree's, so the coverage page counts only `correct`
    theorems as proved) and of tests/corpus/MANIFEST.tsv. A theorem kinds.tsv does not list is `correct` (the days
    before kinds.tsv, when programs.tsv listed only spec theorems). A file's manifest row names the Mojo file that
    defines its kernel (`lib`, or `source` when `lib` is `-`) and the kernel's name, which is the function's name
    followed by the specialization the compiler appends; the function is the one of `rows` (universe rows) defined in
    that file whose name is the kernel's name or the longest one that starts it followed by `_`. A file compiled from a
    source written for MojoProof (`repo:`), a row whose digest is not the file's manifest row's, and a program bound to
    no file count for no function. Returns {(path, name): [(theorem, file, sha256), ...]}."""
    if kinds is None:
        f = ROOT / 'roadmap' / 'llvm-ir' / 'kinds.tsv'
        kinds = f.read_text() if f.is_file() else ''
    kind_of = theorem_kinds(kinds)
    man = {}
    for line in manifest.split('\n'):
        cols = line.split('\t')
        if len(cols) == len(MANIFEST_COLS) and cols[0] != 'path':
            man['tests/corpus/' + cols[0]] = dict(zip(MANIFEST_COLS, cols))
    names_in = collections.defaultdict(list)
    for r in rows:
        names_in[r['path']].append(r['name'])
    out: dict[tuple[str, str], list[tuple[str, str, str]]] = collections.defaultdict(list)
    for line in programs.split('\n'):
        cols = line.split('\t')
        if len(cols) != 5 or cols[0] == 'theorem' or cols[3] == '-':
            continue
        thm, _, prog, f, digest = cols
        m = man.get(f)
        if kind_of.get((thm, prog), kind_of.get(thm, 'correct')) != kind:
            continue
        if not m or m['sha256'] != digest:
            continue
        for src in (m['lib'].split(',') if m['lib'] != '-' else [m['source']]):
            if src.startswith('repo:'):
                continue
            src = re.sub(r'^modular/modular@[0-9a-f]+:', '', src)
            hit = [n for n in names_in.get(src, []) if m['kernel'] == n or m['kernel'].startswith(n + '_')]
            if hit:
                out[(src, max(hit, key=len))].append((thm, f, digest))
                break
    return dict(out)


def history() -> int:
    here = str(ROOT)
    ref = 'main'   # the development line; a side branch's own first-parent history would skip main's days
    days: dict[str, str] = {}
    for line in git(here, 'log', '--first-parent', '--reverse', '--format=%H %cs', ref).split('\n'):
        if line:
            h, d = line.split()
            days[d] = h   # the last commit of the day
    rows = ['# Theorems at the last commit of each day (scripts/kernel_universe.py history): the `theorem` and `lemma`',
            '# declarations in the source of GPUProof/ and MojoProof/ (the library) and of MojoProofTest/ (kernels and test',
            '# programs), outside comments, strings and quoted templates (`count_theorems`); the theorems commands generate',
            '# are not counted.',
            'date\tlibrary\ttests']
    cache: dict[str, int] = {}
    for d, h in sorted(days.items()):
        lib, tests = theorems_at(here, h, cache)
        rows.append(f'{d}\t{lib}\t{tests}')
    (ROOT / 'roadmap' / 'kernels' / 'theorems.tsv').write_text('\n'.join(rows) + '\n')
    uni = universe_rows(OUT.read_text())
    proved = ['# Modular\'s kernel functions with a kernel theorem at the last commit of each day (scripts/kernel_universe.py',
              '# history): roadmap/llvm-ir/programs.tsv, kinds.tsv and tests/corpus/MANIFEST.tsv of that commit, read by',
              '# proved_functions against the current universe.tsv (`correct` theorems only, not the spec-free `safe`',
              '# ones), as path:name separated by `;`. The days before programs.tsv was first written are not listed.',
              'date\tfunctions']
    for d, h in sorted(days.items()):
        try:
            programs = git(here, 'show', f'{h}:roadmap/llvm-ir/programs.tsv')
            manifest = git(here, 'show', f'{h}:tests/corpus/MANIFEST.tsv')
        except subprocess.CalledProcessError:
            continue
        try:
            kinds = git(here, 'show', f'{h}:roadmap/llvm-ir/kinds.tsv')
        except subprocess.CalledProcessError:
            kinds = ''
        proved.append(f'{d}\t' + ';'.join(sorted(f'{p}:{n}' for p, n in proved_functions(programs, manifest, uni, kinds))))
    (ROOT / 'roadmap' / 'kernels' / 'proved.tsv').write_text('\n'.join(proved) + '\n')
    print(f'{len(rows) - 5} days of theorem counts, {len(proved) - 5} days of proved functions')
    return 0


# Mojo texts and what `launches` reads in them: the launched names with their lines, and the lines of the other uses.
LAUNCH_CASES = [
    ('ctx.enqueue_function[k1, k1](grid_dim=1)\n', [(1, 'k1')], []),
    ('ctx.enqueue_function[\n    _qk_kernel[dtype], _qk_kernel[dtype]\n](a)\n', [(1, '_qk_kernel')], []),
    ('ctx.enqueue_function_checked[k2, k2](x)\nctx.enqueue_function_experimental[k3](y)\n',
     [(1, 'k2'), (2, 'k3')], []),
    ('# ctx.enqueue_function[gone, gone]()\nx = 1  # enqueue_function[gone2]\n', [], []),
    ('def f():\n    """Launch with `ctx.enqueue_function[doc, doc]`.\n    enqueue_function[doc2]\n    """\n'
     '    ctx.enqueue_function[real, real]()\n', [(5, 'real')], []),
    ('s = "a # b"\nctx.enqueue_function[after_hash](s)\n', [(2, 'after_hash')], []),
    ("s = 'it\\'s'\nctx.enqueue_function[after_quote]()\n", [(2, 'after_quote')], []),
    ('ctx.enqueue_function(compiled, grid_dim=1)\n', [], [1]),
    ('ctx.enqueue_function[\n    Self._planes_kernel[N=N]\n]()\n', [(1, '_planes_kernel')], []),
    ('    @inline\n    def enqueue_function[\n        declared: TypeList,\n    ](self):\n', [], []),
]
# Lean texts and `count_theorems` of each.
THEOREM_CASES = [
    ('theorem a : True := trivial\nlemma b : True := trivial\n', 2),
    ('@[simp] theorem c : True := trivial\nprivate theorem d : True := trivial\n', 2),
    ('/-- Docstring:\ntheorem not_one : True := trivial -/\ntheorem e : True := trivial\n', 1),
    ('/- outer /- nested -/\ntheorem not_two : True := trivial -/\n', 0),
    ('-- theorem not_three : True := trivial\n', 0),
    ('elab_rules : command\n  | `(x) => elabCommand (← `(command|\n    theorem $id : True := trivial))\n', 0),
    ('def s : String := "x\ntheorem not_four : True := trivial\n"\ntheorem f : True := trivial\n', 1),
]


# A universe, a manifest, a programs table and a kinds table, and what `proved_functions` reads in them: the naive
# kernel's file is bound to `matmul_kernel_naive` (not the shorter `matmul_kernel`, which also starts its name); the
# file compiled from a repo: source, the theorem with no file, and the row whose digest is not its file's count for no
# function; the `safe` theorem counts only for `kind='safe'`, and `V.sound`, which kinds.tsv does not list, is `correct`.
PROVED_ROWS = [{'name': 'matmul_kernel', 'path': 'a/mm.mojo'}, {'name': 'matmul_kernel_naive', 'path': 'a/mm.mojo'},
               {'name': 'vector_addition', 'path': 'ex/vadd.mojo'}]
PROVED_MANIFEST = '\n'.join([
    '\t'.join(MANIFEST_COLS),
    'mm/naive_f32.ll\t11\t9\tmatmul_kernel_naive_float32_True_16_abc\tsm_80\tptx81\tv\t-\tmodular/modular@bbc1:a/t.mojo\tx\ta/mm.mojo',
    'vadd/v.ll\t22\t9\tvector_addition_6A6A_def\tsm_80\tptx81\tv\t-\tmodular/modular@bbc1:ex/vadd.mojo\tx\t-',
    'own/w.ll\t33\t9\tvector_addition_6A6A_ghi\tsm_80\tptx81\tv\t-\trepo:own/w.mojo\tx\t-'])
PROVED_PROGRAMS = '\n'.join([
    'theorem\tmodule\tprogram\tfile\tsha256',
    'N.correct\tN\tN.prog\ttests/corpus/mm/naive_f32.ll\t11',
    'V.sound\tV\tV.prog\ttests/corpus/vadd/v.ll\t22',
    'V.stale\tV\tV.prog\ttests/corpus/vadd/v.ll\t99',
    'W.sound\tW\tW.prog\ttests/corpus/own/w.ll\t33',
    'X.sound\tX\tX.term\t-\t-',
    'V.safe\tV\tV.prog\ttests/corpus/vadd/v.ll\t22'])
PROVED_KINDS = 'theorem\tkind\nN.correct\tcorrect\nV.safe\tsafe\n'
# The same in the table's three-column form: one row per theorem and program.
PROVED_KINDS3 = 'theorem\tprogram\tkind\nN.correct\tN.prog\tcorrect\nV.safe\tV.prog\tsafe\n'
PROVED_WANT = {('a/mm.mojo', 'matmul_kernel_naive'): [('N.correct', 'tests/corpus/mm/naive_f32.ll', '11')],
               ('ex/vadd.mojo', 'vector_addition'): [('V.sound', 'tests/corpus/vadd/v.ll', '22')]}
SAFE_WANT = {('ex/vadd.mojo', 'vector_addition'): [('V.safe', 'tests/corpus/vadd/v.ll', '22')]}


def self_test() -> int:
    """Check `launches` on `LAUNCH_CASES`, `resolve_in` on an alias, `count_theorems` on `THEOREM_CASES` and
    `proved_functions` on `PROVED_*` at both kinds; print each failure and return 1 if there is one."""
    bad = []
    for text, want, other in LAUNCH_CASES:
        if (got := launches(text)) != (want, other):
            bad.append(f'launches({text!r}) is {got!r}, not {(want, other)!r}')
    lines = mojo_code('comptime kernel = mod.real_kernel\nctx.enqueue_function[kernel, kernel]()\n').split('\n')
    if (got := resolve_in(lines, 2, 'kernel', {'real_kernel': []})) != 'real_kernel':
        bad.append(f'resolve_in at an alias is {got!r}')
    for text, want in THEOREM_CASES:
        if (got := count_theorems(text)) != want:
            bad.append(f'count_theorems({text!r}) is {got}, not {want}')
    for kinds in (PROVED_KINDS, PROVED_KINDS3):
        for kind, want in (('correct', PROVED_WANT), ('safe', SAFE_WANT)):
            if (got := proved_functions(PROVED_PROGRAMS, PROVED_MANIFEST, PROVED_ROWS, kinds, kind)) != want:
                bad.append(f'proved_functions on PROVED_* at {kind} ({kinds.split(chr(10))[0]}) is {got!r}, '
                           f'not {want!r}')
    print('\n'.join(bad) or f'self-test: {len(LAUNCH_CASES) + 3 + len(THEOREM_CASES)} cases pass')
    return 1 if bad else 0


def main(argv: list[str]) -> int:
    if argv[1:2] == ['history']:
        return history()
    if argv[1:2] == ['--self-test']:
        return self_test()
    if argv[1:2] != ['universe'] or len(argv) != 4:
        print(__doc__)
        return 2
    clone, commit = argv[2], argv[3]
    date = git(clone, 'log', '-1', '--format=%cs', commit).strip()
    files: dict[str, list[str]] = {}   # path -> lines of mojo_code
    sites, others = [], []   # (launch path, line, launched name); (path, line) of the other uses
    for path in git(clone, 'grep', '-I', '-l', '-E', 'enqueue_function', commit, '--', *PATHS).splitlines():
        path = path.split(':', 1)[1]
        text = git(clone, 'show', f'{commit}:{path}')
        files[path] = mojo_code(text).split('\n')
        found, other = launches(text)
        sites += [(path, ln, name) for ln, name in found]
        others += [(path, ln) for ln in other]
    defs = collections.defaultdict(list)   # function name -> [(path, line)]
    for line in git(clone, 'grep', '-I', '-n', '-E', r'(def|fn)\s+[A-Za-z_]', commit, '--', *PATHS).splitlines():
        if line.count(':') < 3:
            continue
        _, path, ln, text = line.split(':', 3)
        if path.endswith('.mojo') and (m := DEF.match(text)):
            defs[m.group(1)].append((path, int(ln)))

    def resolve(path: str, ln: int, name: str) -> str | None:
        return resolve_in(files[path], ln, name, defs)

    def where(name: str, launch_path: str) -> tuple[str, int]:
        """The definition to cite: one in the launching file, else in the launching package, else the first."""
        cands = defs[name]
        for pred in (lambda p: p == launch_path,
                     lambda p: p.split('/')[:4] == launch_path.split('/')[:4],
                     lambda p: True):
            hit = [c for c in cands if pred(c[0])]
            if hit:
                return sorted(hit)[0]
        raise KeyError(name)

    kernels: dict[tuple[str, str, int], set] = collections.defaultdict(set)
    unresolved = set()
    for path, ln, name in sites:
        target = resolve(path, ln, name)
        if target is None:
            unresolved.add(name)
            continue
        dpath, dline = where(target, path)
        kernels[(target, dpath, dline)].add((path, ln))
    elementwise = sum(int(l.rsplit(':', 1)[1]) for l in
                      git(clone, 'grep', '-c', '-E', r'\belementwise\[', commit, '--', 'max/kernels/src').splitlines())
    rows = sorted(kernels.items(), key=lambda kv: (area(kv[0][1]), kv[0][0], kv[0][1]))
    out = [f'# Modular GPU kernels at modular/modular@{commit} ({date}), written by scripts/kernel_universe.py.',
           f'# {len(rows)} kernels launched with enqueue_function from {len(sites)} launch sites; '
           f'{len(unresolved)} launched names are type parameters, not functions ({", ".join(sorted(unresolved))}); '
           f'{len(others)} uses of enqueue_function name no function in brackets (a compiled function passed as a value) '
           f'and are not listed ({", ".join(f"{p}:{l}" for p, l in sorted(others)[:3])}{", ..." if len(others) > 3 else ""}); '
           f'{elementwise} elementwise call sites in max/kernels/src build further kernels from closures and are not listed.',
           'name\tarea\tpath\tline\tlaunch_sites']
    out += [f'{n}\t{area(p)}\t{p}\t{l}\t{len(s)}' for (n, p, l), s in rows]
    OUT.write_text('\n'.join(out) + '\n')
    by_area = collections.Counter(area(p) for (n, p, l), _ in rows)
    print(f'{len(rows)} kernels, {len(sites)} launch sites, {len(unresolved)} unresolved, {len(others)} other uses, '
          f'{elementwise} elementwise; '
          + ', '.join(f'{a} {c}' for a, c in by_area.most_common()))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
