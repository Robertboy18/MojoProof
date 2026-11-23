#!/usr/bin/env python3
"""cited.py: every name a module docstring or a roadmap card cites is declared where it can mean it.

A module docstring (`/-! ... -/`) in MojoProof/ or MojoProofTest/ that cites in backticks a name
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
clause also `N.argTy`, `N.argTail`, `N.ret` and `N.correct`. A tactic declared by `elab`,
`syntax` or `macro` with a quoted name (`elab "kernel_check" : tactic`, with or without a trailing
space inside the quotes) is a declaration of that name at the root. So a library lemma `Mem.load_skel` does not stand in for a deleted test
`load_skel`. A name that none of our files declares at those namespaces may be a dependency's: it
resolves if a Lean file of a package under `.lake/packages/` declares it at one of them (the
packages are read, by the same scan, at the first such name), so a docstring can cite Mathlib's
`Fin.ofFn_take_eq_take_ofFn`. Lean's own library (`Init`, `Std`, `Lean`) is not read, so a name
declared only there is reported.

The body of every roadmap card (`roadmap/**/cards/*.md`, after the front matter between its
first two `---` lines) is checked too, against the same declarations: every backticked span that
begins with a fully qualified name (`MojoProof.` or `MojoProofTest.` and one or more components,
`MojoProofTest.NaiveOff.correct`, or the head of a term, `MojoProof.Sem.deliver r n`) must begin
with a declaration (a structure field or a name a command above generates included) or a module
of the library or its tests (`MojoProofTest.NaiveStart`). Short names in card bodies are not
checked: a card opens no namespace, so they are ambiguous.

Prints each missing name and the count; exits 1 if any is missing.
"""
import functools
import pathlib
import re
import sys

# Names cited in module docstrings that are not Lean declarations.
OTHER = {
    'mojo_import',      # the importer's command (scripts and docs/IMPORT)
    'sym_summary',      # the block checker's command (MojoProof/Sym/Command.lean)
    'mojo_kernel',      # the kernel command (MojoProof/Sym/KernelCmd.lean)
    'mojo_corpus',      # the corpus command (MojoProof/LLVM/Corpus.lean)
    'mojo_refuse',      # a refusal of the rule table (MojoProof/Sym/RuleAttr.lean)
    'mojo_rules_complete',  # the rule table's completeness command (MojoProof/Sym/RuleAttr.lean)
    'mojo_mutant',      # quotes a mutant program as a term (MojoProof/LLVM/Mutate.lean)
    'n.sound_of',       # what `mojo_kernel n` adds, schematic in n (MojoProof/Sym/KernelCmd.lean)
    'n.loop',           # what `mojo_kernel n` adds with a loop clause: the thread's run
    'n.sound_loop',     # and the kernel theorem through the loop (MojoProof/Sym/KernelCmd.lean)
    'n.sound_mat',      # what `mojo_kernel n` adds with the mat clause (MojoProof/Sym/KernelCmd.lean)
    'n.sound_inv',      # and with `mat … inv` (MojoProof/Sym/KernelCmd.lean)
    'mojo_kills',       # checks the refutation theorems of mutants (MojoProof/LLVM/Mutate.lean)
    'matmul_kernel_naive_float32_float32_float32_True_16_16826c8c',  # corpus kernels
    'tiled_matmul',     # corpus kernels
    'vector_addition',
    'vector_multiply',
    'seq_cst',          # an LLVM ordering keyword
    'mojo_import.root', # the importer's root directory (MojoProof/LLVM/Quote.lean)
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
TACTIC = re.compile(r'^\s*(?:elab|syntax|macro)(?:\s+\(name\s*:=\s*[^)]*\))?\s+"([a-z][A-Za-z0-9_]*) ?"[^\n]*:\s*tactic\b')
COMMENT = re.compile(r'/-.*?-/|--[^\n]*', re.S)
DOC = re.compile(r'/-!(.*?)-/', re.S)
TICK = re.compile(r"`((?:[A-Za-z_][A-Za-z0-9_'₂]*\.)*[a-z][A-Za-z0-9'₂]*(?:_[A-Za-z0-9'₂]+)+)`")
PATH = re.compile(r'\b(MojoProof(?:Test)?/[A-Za-z0-9_/]+\.lean)\b')
MODULE = re.compile(r'\b(MojoProof(?:Test)?(?:\.[A-Z][A-Za-z0-9_]*)+)\b')
FRONT = re.compile(r'\A---\n.*?\n---\n', re.S)
SPAN = re.compile(r'`([^`]*)`')
QUAL = re.compile(r"(MojoProof(?:Test)?(?:\.[\w'!?]+)+)(?![\w'!?.])")


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
    # blank out comments, keeping the lines
    text = COMMENT.sub(lambda m: re.sub(r'[^\n]', ' ', m.group(0)), text)
    prev = ''   # the last non-blank line
    kernel = None   # the full name of the unrefused `mojo_kernel` command whose clauses follow
    for line in text.split('\n'):
        cur = '.'.join(s for _, s in stack if s)
        if kernel and line[:1].strip():
            kernel = None
        if kernel and LOOP.match(line):
            decls.add(f'{kernel}.sound_loop')
        if m := KERNEL.match(line):
            full = f'{cur}.{m.group(1)}' if cur else m.group(1)
            decls.add(full)
            if prev.strip() != '#guard_msgs in':
                decls.add(f'{full}.sound_of')
                kernel = full
        if kernel and MAT.search(line):
            decls.discard(f'{kernel}.sound_of')
            decls.update(f'{kernel}.{x}' for x in ('names', 'starts', 'out', 'sound_mat'))
            if INV.search(line):
                decls.update(f'{kernel}.{x}' for x in ('runInv', 'kept', 'sound_inv'))
        if kernel and MAP2.search(line):
            decls.update(f'{kernel}.{x}' for x in ('argTy', 'argTail', 'ret', 'correct'))
        if m := TACTIC.match(line):
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


def main() -> int:
    files = [p for d in ('MojoProof', 'MojoProofTest') for p in sorted(pathlib.Path(d).rglob('*.lean'))]
    texts = {p: p.read_text() for p in files}
    info = {p: scan(t) for p, t in texts.items()}
    decls = set().union(*(i[0] for i in info.values()))
    fields = set().union(*(i[3] for i in info.values()))
    missing = 0
    for p, text in texts.items():
        for d in DOC.finditer(text):
            doc = d.group(1)
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
