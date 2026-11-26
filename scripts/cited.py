#!/usr/bin/env python3
"""cited.py: every name a module docstring or a roadmap card cites is declared where it can mean it.

A module docstring (`/-! ... -/`) in GPUProof/, MojoProof/ or MojoProofTest/ that cites in backticks a name
whose last component is snake_case (`addr_twin`, `Mem.load_skel`) must name a declaration `N.name`
where `N` is a namespace the name can resolve in from the citing file: a namespace the file
declares or opens, one that a file the docstring names (by path, `MojoProofTest/Skeleton.lean`, or
module, `MojoProofTest.Skeleton`) declares, or an enclosing namespace of one of these, the root
included (`_root_.name` resolves only there). A structure or class field `f` of `S` is the
declaration `S.f`, and a bare name (no dot) that is a field of the library or its tests needs
nothing more, so `Confluent.bad_step` resolves but `Ghost.bad_step` does not (a field's name does not stand
in for every qualified name ending in it). A name in
OTHER (file, kernel and keyword names, which are not Lean) or PLANNED needs nothing. A command
`mojo_kernel N := …` names the test `N`, and when it is not under `#guard_msgs` (a refusal) it
declares `N.sound_of`, and with a `loop` clause also `N.sound_loop` (which the command adds only
when it also adds `N.args`; cited.py does not check that condition); with a `mat` clause it
declares `N.names`, `N.starts`, `N.out` and `N.sound_mat` and not `N.sound_of`, and with `inv`
at the end of the `mat` clause's line also `N.runInv`, `N.kept` and `N.sound_inv`; with a `map2`
clause also `N.argTy`, `N.argTail`, `N.ret` and `N.correct`. A command `mojo_family F := …`
declares `F.prog`, `F.fn` and `F.prog_corpus` when it is not under `#guard_msgs`, a command
`sym_summary_family n (x₁ … xₖ) := …` declares `n` and `n_eq` when it is not under `#guard_msgs`,
a command `tile_map2 k …` declares `k_tile`, and a command
`import_spec imp p₁ … pₖ : Src (σ : Sz) where | op … | op' …` declares `Src`, `Src.SIn`,
`Src.SOut`, `Src.denote`, `Src.translate`, `readIn`, `readOut` and, at each operation `op` (a line
of the command beginning with `| op`), `Src.op`, `readIn_op` and `readOut_op`, and the importer
`imp` when it is not under `#guard_msgs` (a refusal; cited.py does not check that every `eq` case
closes). The scan reads code only: it first blanks every comment, a block comment up to the `-/`
that closes it past the block comments nested in it (Lean's comments nest), so an example in a
docstring declares nothing; a `/-` or `--` in a string literal (an interpolated one's terms
included), a raw string, a char literal or a `«…»` name opens no comment. A command is under `#guard_msgs` when the last non-blank line before it, comments blanked,
is `#guard_msgs in` with or without options (`#guard_msgs (whitespace := lax) in`); `CHECKS` (run
before the scan) pins the refusals of `mojo_kernel`, `mojo_family` and `sym_summary_family` under
both forms, that a docstring's example declares nothing and that a comment delimiter in each kind
of literal opens nothing, and `DOCS` that a docstring ends past its nested comments and is found
after a string holding `/-`. A tactic or command declared by `elab`, `syntax`
or `macro` with a quoted name (`elab "kernel_check" : tactic`, with or without a trailing space
inside the quotes, after an optional `(name := …)` and an optional `docComment`, `(docComment)?`
or `d:docComment`, and with `: tactic` or `: command` on the same line or an indented line below)
is a declaration of that name at the root. So a library lemma `Mem.load_skel` does not stand in for a deleted test
`load_skel`. A name that none of our files declares at those namespaces may be a dependency's: it
resolves if a Lean file of a package under `.lake/packages/` declares it at one of them (the
packages are read, by the same scan, at the first such name), so a docstring can cite Mathlib's
`Fin.ofFn_take_eq_take_ofFn`. Lean's own library (`Init`, `Std`, `Lean`) is not read, so a name
declared only there is reported.

The body of every roadmap card (`roadmap/**/cards/*.md`, after the front matter between its
first two `---` lines) is checked too, against the same declarations: every backticked span that
begins with a fully qualified name (`GPUProof.`, `MojoProof.` or `MojoProofTest.` and one or more components,
`MojoProofTest.NaiveOff.correct`, or the head of a term, `MojoProof.Sem.deliver r n`) must begin
with a declaration (a structure field or a name a command above generates included) or a module
of the library or its tests (`MojoProofTest.NaiveStart`). Short names in card bodies are not
checked: a card opens no namespace, so they are ambiguous.

Prints each failed self-check, each missing name and the count; exits 1 if any check fails or
any name is missing.

With `--deleted REV` it checks instead the names that the commit `REV` declares (by the same
scan of its `GPUProof/`, `MojoProof/` and `MojoProofTest/` files, read with `git show`) and the
working tree no longer declares. Every suffix of such a name, of one or more components
(`warpBound`, `Sem.warpBound`, `MojoProof.Sem.warpBound`), that is no suffix of a declaration of
ours or of a package and no field name must not begin a backticked span (the whole span, or its
head before a space) in a docstring or comment of our Lean files or in a tracked Markdown file,
fenced code included. docs/BUGS.md, docs/found-bugs.md and docs/UPSTREAM.md are skipped: they
record deleted names on purpose. This covers the names a change deletes in whatever case they
are written (the default check reads only snake_case names in module docstrings, and only
qualified names in cards), so it is run on the commits since the last check.
"""
import functools
import pathlib
import re
import subprocess
import sys

# Names cited in module docstrings that are not Lean declarations.
OTHER = {
    'n.sound_of',       # what `mojo_kernel n` adds, schematic in n (MojoProof/Sym/KernelCmd.lean)
    'n.loop',           # what `mojo_kernel n` adds with a loop clause: the thread's run
    'n.sound_loop',     # and the kernel theorem through the loop (MojoProof/Sym/KernelCmd.lean)
    'n.sound_mat',      # what `mojo_kernel n` adds with the mat clause (MojoProof/Sym/KernelCmd.lean)
    'n.sound_inv',      # and with `mat … inv` (MojoProof/Sym/KernelCmd.lean)
    'matmul_kernel_naive_float32_float32_float32_True_16_16826c8c',  # corpus kernels
    'tiled_matmul',     # corpus kernels
    'vector_addition',
    'vector_multiply',
    'seq_cst',          # an LLVM ordering keyword
    'mojo_import.root', # the importer's root directory (MojoProof/LLVM/Quote.lean)
    'readIn_op',        # what `import_spec` adds at each operation `op`, schematic in op
    'readOut_op',       # (MojoProof/Import/Command.lean)
}

# Theorems the docs name as not yet proved.
PLANNED: set[str] = set()

DECL = re.compile(
    r'^\s*(?:@\[[^\]]*\]\s*)?(?:(?:private|protected|noncomputable|unsafe|partial)\s+)*'
    r'(theorem|lemma|def|abbrev|structure|inductive|instance|class|opaque)\s+([^\s:({\[]+)')
SCOPE = re.compile(r'^\s*(?:noncomputable\s+)?(namespace|section|mutual|end|open)\b\s*(.*)$')
FIELD = re.compile(r'^  ([a-z][A-Za-z0-9_\']*) :')
KERNEL = re.compile(r'^mojo_kernel\s+([^\s:]+)\s+:=')
LOOP = re.compile(r'^\s+loop\s+\d+\s*:=')
MAT = re.compile(r'(?:^|\s)mat\s')
INV = re.compile(r'\sinv\s*$')
MAP2 = re.compile(r'(?:^|\s)map2\s')
FAMILY = re.compile(r'^\s*mojo_family\s+([^\s:]+)\s+:=')
TILE = re.compile(r'^\s*tile_map2\s+([^\s:]+)\s')
SUMFAM = re.compile(r'^\s*sym_summary_family\s+([^\s:(]+)\s+\(')
IMPSPEC = re.compile(r'^import_spec\s+([^\s:]+)[^:]*:\s*([A-Za-z_][A-Za-z0-9_\']*)\s*\(')
IMPOP = re.compile(r'^\s+\|\s*([A-Za-z_][A-Za-z0-9_\']*)\s')
TACTIC = re.compile(
    r'^\s*(?:(?:local|scoped)\s+)?(?:elab|syntax|macro)(?:\s+\(name\s*:=\s*[^)]*\))?'
    r'(?:\s+(?:\(docComment\)\??|(?:[A-Za-z_]+:)?docComment))?\s+"([a-z][A-Za-z0-9_]*) ?"(.*)$')
CATEGORY = re.compile(r':\s*(?:tactic|command)\b')
GUARD = re.compile(r'^#guard_msgs(?:\s*\([^)]*\))*\s+in$')
# The tokens that open a comment or a literal, for `comments`: a raw string `r#"…"#` (its `r` not
# the end of a name), a string, a char literal (its `'` not a name's prime), a `«…»` name; in an
# interpolated string's term, also the braces.
LEX = re.compile(r'/-|--|(?<![\w\'.!?])r#*"|"|(?<![\w\'])\'(?:\\(?:x[0-9a-fA-F]{2}|u[0-9a-fA-F]{4}|.)|[^\\\'\n])\'|«[^»]*»')
TERM = re.compile(LEX.pattern + r'|[{}]')
NEST = re.compile(r'/-|-/')
TICK = re.compile(r"`((?:[A-Za-z_][A-Za-z0-9_'₂]*\.)*[a-z][A-Za-z0-9'₂]*(?:_[A-Za-z0-9'₂]+)+)`")
PATH = re.compile(r'\b((?:GPUProof|MojoProof(?:Test)?)/[A-Za-z0-9_/]+\.lean)\b')
MODULE = re.compile(r'\b((?:GPUProof|MojoProof(?:Test)?)(?:\.[A-Z][A-Za-z0-9_]*)+)\b')
FRONT = re.compile(r'\A---\n.*?\n---\n', re.S)
SPAN = re.compile(r'`([^`]*)`')
QUAL = re.compile(r"((?:GPUProof|MojoProof(?:Test)?)(?:\.[\w'!?]+)+)(?![\w'!?.])")


def ancestors(ns: str) -> list[str]:
    """`ns` and its enclosing namespaces, the root `''` last."""
    parts = ns.split('.') if ns else []
    return ['.'.join(parts[:i]) for i in range(len(parts), -1, -1)]


def scan(text: str) -> tuple[set[str], set[str], set[str], set[str]]:
    """The full names a file declares (structure fields `S.f` included), the namespaces it declares,
    those it opens, and its field names."""
    decls, spaces, opens, fields = set(), set(), set(), set()
    stack: list[tuple[str, str]] = []   # (kind, namespace segment or '')
    struct = None   # the full name of the structure or class whose fields follow
    text = blank(text)
    prev = ''   # the last non-blank line
    kernel = None   # the full name of the unrefused `mojo_kernel` command whose clauses follow
    impspec = None  # the namespace and `Src` of the `import_spec` command whose operations follow
    lines = text.split('\n')
    for i, line in enumerate(lines):
        cur = '.'.join(s for _, s in stack if s)
        if kernel and line[:1].strip():
            kernel = None
        if impspec and line[:1].strip():
            impspec = None
        if impspec and (m := IMPOP.match(line)):
            pre = f'{impspec[0]}.' if impspec[0] else ''
            decls.update((f'{pre}{impspec[1]}.{m.group(1)}', f'{pre}readIn_{m.group(1)}',
                          f'{pre}readOut_{m.group(1)}'))
        if m := IMPSPEC.match(line):
            pre = f'{cur}.' if cur else ''
            src = f'{pre}{m.group(2)}'
            decls.update((src, f'{src}.SIn', f'{src}.SOut', f'{src}.denote', f'{src}.translate',
                          f'{pre}readIn', f'{pre}readOut'))
            if not GUARD.match(prev.strip()):
                decls.add(f'{pre}{m.group(1)}')
            impspec = (cur, m.group(2))
        if kernel and LOOP.match(line):
            decls.add(f'{kernel}.sound_loop')
        if m := KERNEL.match(line):
            full = f'{cur}.{m.group(1)}' if cur else m.group(1)
            decls.add(full)
            if not GUARD.match(prev.strip()):
                decls.add(f'{full}.sound_of')
                kernel = full
        if kernel and MAT.search(line):
            decls.discard(f'{kernel}.sound_of')
            decls.update(f'{kernel}.{x}' for x in ('names', 'starts', 'out', 'sound_mat'))
            if INV.search(line):
                decls.update(f'{kernel}.{x}' for x in ('runInv', 'kept', 'sound_inv'))
        if kernel and MAP2.search(line):
            decls.update(f'{kernel}.{x}' for x in ('argTy', 'argTail', 'ret', 'correct'))
        if (m := FAMILY.match(line)) and not GUARD.match(prev.strip()):
            full = f'{cur}.{m.group(1)}' if cur else m.group(1)
            decls.update(f'{full}.{x}' for x in ('prog', 'fn', 'prog_corpus'))
        if (m := SUMFAM.match(line)) and not GUARD.match(prev.strip()):
            full = f'{cur}.{m.group(1)}' if cur else m.group(1)
            decls.update((full, f'{full}_eq'))
        if m := TILE.match(line):
            decls.add(f'{cur}.{m.group(1)}_tile' if cur else f'{m.group(1)}_tile')
        if m := TACTIC.match(line):
            # the rest of the line and the indented lines that continue the declaration
            rest = [m.group(2)]
            for nxt in lines[i + 1:i + 6]:
                if not nxt[:1].isspace() or not nxt.strip():
                    break
                rest.append(nxt)
            if any(CATEGORY.search(r) for r in rest):
                decls.add(m.group(1))
        if line.strip():
            prev = line
        if struct and line[:1].strip():
            struct = None
        if struct and (m := FIELD.match(line)):
            decls.add(f'{struct}.{m.group(1)}')
            fields.add(m.group(1))
            continue
        if m := SCOPE.match(line):
            kind, rest = m.group(1), m.group(2).split()
            if kind == 'namespace':
                stack.append(('namespace', rest[0]))
                spaces.add('.'.join(s for _, s in stack if s))
            elif kind in ('section', 'mutual'):
                stack.append((kind, ''))
            elif kind == 'end' and stack:
                stack.pop()
            elif kind == 'open':
                # a top-level `open` continues on the indented lines after it
                if not line[:1].isspace():
                    for nxt in lines[i + 1:]:
                        if not nxt[:1].isspace() or not nxt.strip():
                            break
                        rest += nxt.split()
                for o in rest:
                    if o in ('in', 'hiding', 'renaming') or not o[:1].isupper():
                        break
                    opens.update(f'{a}.{o}' if a else o for a in ancestors(cur))
            continue
        if m := DECL.match(line):
            kind, name = m.group(1), m.group(2)
            full = name.removeprefix('_root_.') if name.startswith('_root_.') else (
                f'{cur}.{name}' if cur else name)
            decls.add(full)
            struct = full if kind in ('structure', 'class') else None
    return decls, spaces, opens, fields


@functools.cache
def package_decls() -> frozenset[str]:
    """The full names that the Lean files of the packages under `.lake/packages/` declare (`scan`),
    each package's own `.lake` directory skipped: the dependencies' declarations."""
    decls: set[str] = set()
    for pkg in sorted((pathlib.Path('.lake') / 'packages').glob('*')):
        for p in sorted(pkg.rglob('*.lean')):
            if '.lake' not in p.relative_to(pkg).parts:
                decls |= scan(p.read_text(errors='replace'))[0]
    return frozenset(decls)


def card_names(text: str):
    """The line and the fully qualified name of every backticked span of a card's body (after its
    front matter) that begins with one."""
    front = FRONT.match(text)
    start = front.end() if front else 0
    line = text.count('\n', 0, start) + 1
    pos = start
    for s in SPAN.finditer(text, start):
        line += text.count('\n', pos, s.start())
        pos = s.start()
        if q := QUAL.match(s.group(1)):
            yield line, q.group(1)


# Self-checks of `scan`: a source text, names it must declare, and names it must not declare.
# The second is the refusal test of MojoProofTest/NaiveFamRun.lean (`missingF`).
CHECKS = [
    ('sym_summary_family f (sA sB sC) := prog fn 0 0\n', {'f', 'f_eq'}, set()),
    ('/--\nerror: sym_summary_family: block 1000000 of fn from position 0 is outside the checker\'s '
     'fragment\n-/\n#guard_msgs (whitespace := lax) in\n'
     'sym_summary_family missingF (sA sB sC) := prog fn 1000000 0\n',
     set(), {'missingF', 'missingF_eq'}),
    ('#guard_msgs in\nsym_summary_family g (n) := prog fn 1 0\n', set(), {'g', 'g_eq'}),
    ('mojo_family F := prog\n', {'F.prog', 'F.fn', 'F.prog_corpus'}, set()),
    ('#guard_msgs (whitespace := lax) in\nmojo_family G := prog\n', set(), {'G.prog', 'G.fn'}),
    ('mojo_kernel k := vadd\n', {'k', 'k.sound_of'}, set()),
    ('#guard_msgs (drop info) in\nmojo_kernel r := vadd\n', {'r'}, {'r.sound_of'}),
    ('#guard_msgs in\nmojo_kernel q := vadd\n', {'q'}, {'q.sound_of'}),
    ('import_spec imp g mono : Src (n : ℕ) where\n  /-- op -/\n  | sum (v : Fin n → ℝ) → (y : ℝ) :=\n'
     '      ∑ i, v i\n    ↦ S g\n    from v\n    at fun _ => y\n',
     {'imp', 'Src', 'Src.SIn', 'Src.SOut', 'Src.denote', 'Src.translate', 'Src.sum', 'readIn',
      'readOut', 'readIn_sum', 'readOut_sum'}, set()),
    ('/--\nwarning: import_spec: `bad` is not declared\n-/\n#guard_msgs in\n/-- d -/\n'
     'import_spec bad g : Op (n : ℕ) where\n  | two (v : ℝ) → (y : ℝ) := 2 * v\n    ↦ S g\n'
     '    from v\n    at y\n', {'Op', 'Op.two', 'readIn_two'}, {'bad'}),
    ('/-! d\n/-- c -/\nimport_spec imp g : Src (n : ℕ) where\n  | op (v : ℝ) → (y : ℝ) := v\n'
     'namespace holds one importer.\n-/\ndef f_g := 1\n',
     {'f_g'}, {'imp', 'Src', 'Src.op', 'readIn_op', 'holds.f_g'}),
    # comment delimiters in literals open nothing: a string, one after an
    # escaped quote, a raw string with a quote in it, a char literal `'"'`, an interpolated
    # string's term, a `«…»` name; a quote in a comment opens no string; names' primes
    ('def marker : String := "/-"\n/-! `deleted_fact` -/\ntheorem after_marker : True := trivial\n',
     {'marker', 'after_marker'}, set()),
    ('def s : String := "--" /- c\ntheorem hidden : True := trivial -/\ntheorem t1 : True := trivial\n',
     {'s', 't1'}, {'hidden'}),
    ('def e : String := "\\"/-"\ntheorem t2 : True := trivial\n', {'e', 't2'}, set()),
    ('def r1 : String := r#"a"/-"#\ntheorem t3 : True := trivial\n', {'r1', 't3'}, set()),
    ('def c1 : Char := \'"\'\ndef c2 : String := "/-"\ntheorem t4 : True := trivial\n',
     {'c1', 'c2', 't4'}, set()),
    ('def m1 : String := s!"{"/-" ++ "}"}"\ntheorem t5 : True := trivial\n', {'m1', 't5'}, set()),
    ('def «a/-b» := 1\ntheorem t6 : True := trivial\n', {'t6'}, set()),
    ('-- "\ntheorem t7 : True := trivial\n/- " -/\ntheorem t8 : True := trivial\n', {'t7', 't8'}, set()),
    ("theorem h' (x' : Nat) : x' = x' := rfl\n/- theorem gone' : True := trivial -/\n",
     {"h'"}, {"gone'"}),
]

# Texts and their module docstrings, as `docs` reads them: the first past its nested comment, and
# one after a string holding `/-`.
DOCS = [('/-! `a_b`\n```\n/-- c -/\n```\n`d_e` -/\n/-! `f_g` -/\n',
         [' `a_b`\n```\n/-- c -/\n```\n`d_e` ', ' `f_g` ']),
        ('def marker : String := "/-"\n/-! `deleted_fact` -/\n', [' `deleted_fact` '])]


def comments(text: str) -> list[tuple[int, int]]:
    """The spans of the comments of `text`: `--` to the end of its line, and `/-` to the `-/` that
    closes it, counting the block comments nested in it (Lean's comments nest). Outside comments,
    string literals (with their escapes, and an interpolated one's terms in braces), raw strings,
    char literals and `«…»` names are skipped, so a `/-` or `--` in one opens nothing; inside a
    block comment, as in Lean, only `/-` and `-/` count."""
    out: list[tuple[int, int]] = []
    lex(text, 0, out)
    return out


def lex(text: str, i: int, out: list[tuple[int, int]], term: bool = False) -> int:
    """Scan `text` from `i`, appending the spans of its comments to `out`; in an interpolated
    string's term (`term`), stop past the `}` that closes it. The end of the scan."""
    depth = 0
    while m := (TERM if term else LEX).search(text, i):
        i, t = m.start(), m.group()
        if t == '--':
            j = text.find('\n', i)
            j = len(text) if j < 0 else j
            out.append((i, j))
        elif t == '/-':
            j, d = i + 2, 1
            while d and (n := NEST.search(text, j)):
                d, j = d + (1 if n.group() == '/-' else -1), n.end()
            j = j if d == 0 else len(text)
            out.append((i, j))
        elif t == '{':
            depth, j = depth + 1, m.end()
        elif t == '}':
            if not depth:
                return m.end()
            depth, j = depth - 1, m.end()
        elif t == '"':
            j = string_end(text, m.end(), out, text[i - 1:i] == '!')
        elif t[0] == 'r':
            k = text.find('"' + '#' * (len(t) - 2), m.end())
            j = len(text) if k < 0 else k + len(t) - 1
        else:   # a char literal or a `«…»` name
            j = m.end()
        i = j
    return len(text)


def string_end(text: str, i: int, out: list[tuple[int, int]], interp: bool) -> int:
    """The end of the string literal whose body starts at `i`, past its escapes, and in an
    interpolated one (`interp`: `s!"…"`, `m!"…"`) past each term in braces (`lex`)."""
    while i < len(text):
        c = text[i]
        if c == '\\':
            i += 2
        elif c == '"':
            return i + 1
        elif c == '{' and interp:
            i = lex(text, i + 1, out, term=True)
        else:
            i += 1
    return len(text)


def blank(text: str) -> str:
    """`text` with every comment (`comments`) blanked, its lines kept."""
    chars = list(text)
    for i, j in comments(text):
        chars[i:j] = re.sub(r'[^\n]', ' ', text[i:j])
    return ''.join(chars)


def docs(text: str) -> list[str]:
    """The module docstrings of `text`: the comments that begin with `/-!`, without `/-!` and `-/`."""
    return [text[i + 3:j - 2] for i, j in comments(text) if text.startswith('/-!', i)]


def selfcheck() -> int:
    """Run `CHECKS` on `scan` and `DOCS` on `docs`; print and count each failure."""
    bad = 0
    for text, want in DOCS:
        if (got := docs(text)) != want:
            print(f'self-check: docs({text!r}) is {got!r}')
            bad += 1
    for text, want, refuse in CHECKS:
        got = scan(text)[0]
        for n in sorted(want - got):
            print(f'self-check: `{n}` not declared by {text!r}')
            bad += 1
        for n in sorted(refuse & got):
            print(f'self-check: `{n}` declared by {text!r}')
            bad += 1
    return bad


def git(*args: str) -> str:
    """The output of `git args`, in the working tree."""
    return subprocess.run(['git', *args], capture_output=True, text=True, check=True).stdout


def rev_decls(rev: str) -> set[str]:
    """The full names that the Lean files of `GPUProof/`, `MojoProof/` and `MojoProofTest/` at the
    commit `rev` declare (`scan`)."""
    decls: set[str] = set()
    for f in git('ls-tree', '-r', '--name-only', rev, '--', 'GPUProof', 'MojoProof',
                 'MojoProofTest').split():
        if f.endswith('.lean'):
            decls |= scan(git('show', f'{rev}:{f}'))[0]
    return decls


def suffixes(name: str) -> list[str]:
    """The suffixes of the full name `name` of one or more components, the name itself first."""
    parts = name.split('.')
    return ['.'.join(parts[i:]) for i in range(len(parts))]


def deleted(rev: str, decls: set[str], fields: set[str]) -> int:
    """Print every backticked span of our docstrings, comments and tracked Markdown files that
    begins with a suffix of a name `rev` declares and the working tree does not, where that suffix
    names nothing now (`--deleted`, in the module docstring); return their count."""
    now = {s for n in decls | package_decls() for s in suffixes(n)} | fields
    gone: dict[str, str] = {}
    for n in sorted(rev_decls(rev) - decls):
        for s in suffixes(n):
            if s not in now:
                gone.setdefault(s, n)
    skip = {'docs/BUGS.md', 'docs/found-bugs.md', 'docs/UPSTREAM.md'}
    texts = [f for f in git('ls-files', '--', '*.md').split() if f not in skip]
    texts += [str(p) for d in ('GPUProof', 'MojoProof', 'MojoProofTest')
              for p in sorted(pathlib.Path(d).rglob('*.lean'))]
    found = 0
    for f in texts:
        text = pathlib.Path(f).read_text(errors='replace')
        if f.endswith('.lean'):
            # only docstrings and comments: blank the code, keeping the lines
            keep = comments(text)
            chars = [c if c == '\n' else ' ' for c in text]
            for i, j in keep:
                chars[i:j] = text[i:j]
            text = ''.join(chars)
        for s in SPAN.finditer(text):
            head = s.group(1).split(' ')[0]
            if head in gone:
                line = text.count('\n', 0, s.start()) + 1
                print(f'{f}:{line}: `{head}` names `{gone[head]}`, declared at {rev} and not now')
                found += 1
    print(f'cited names deleted since {rev}: {found}')
    return found


def main() -> int:
    if failed := selfcheck():
        print(f'cited.py self-checks failed: {failed}')
        return 1
    files = [p for d in ('GPUProof', 'MojoProof', 'MojoProofTest') for p in sorted(pathlib.Path(d).rglob('*.lean'))]
    texts = {p: p.read_text() for p in files}
    info = {p: scan(t) for p, t in texts.items()}
    decls = set().union(*(i[0] for i in info.values()))
    fields = set().union(*(i[3] for i in info.values()))
    if sys.argv[1:2] == ['--deleted']:
        return 1 if deleted(sys.argv[2], decls, fields) else 0
    missing = 0
    for p, text in texts.items():
        for doc in docs(text):
            named = {pathlib.Path(f) for f in PATH.findall(doc)}
            named |= {pathlib.Path(m.replace('.', '/') + '.lean') for m in MODULE.findall(doc)}
            spaces = info[p][1] | info[p][2]
            for f in named & info.keys():
                spaces |= info[f][1]
            prefixes = {a for s in spaces for a in ancestors(s)} | {''}
            for t in sorted(set(TICK.findall(doc)) - OTHER - PLANNED):
                if t in fields:
                    continue
                if t.startswith('_root_.'):
                    full = [t.removeprefix('_root_.')]
                else:
                    full = [f'{a}.{t}' if a else t for a in prefixes]
                found = any(n in decls for n in full) or any(n in package_decls() for n in full)
                if not found:
                    print(f'{p}: `{t}` names no declaration it can mean')
                    missing += 1
    modules = {'.'.join(p.with_suffix('').parts) for p in files}
    for c in sorted(pathlib.Path('roadmap').glob('**/cards/*.md')):
        for line, t in card_names(c.read_text()):
            if t not in decls and t not in modules:
                print(f'{c}:{line}: `{t}` names no declaration')
                missing += 1
    print(f'cited names missing: {missing}')
    return 1 if missing else 0


if __name__ == '__main__':
    sys.exit(main())
