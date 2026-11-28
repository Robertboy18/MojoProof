#!/usr/bin/env python3
"""roadmap_status.py: check the roadmap's cards and write its status from the code.

The roadmap is roadmap/<area>/README.md and roadmap/<area>/cards/<id>.md for every directory
<area> under roadmap/ (roadmap/README.md describes the format). The script reads every area and
card and checks, reporting every problem it finds:

* the area has a README.md whose first line is a `# ` heading (the area's title);
* the card starts with front matter between `---` lines, one `key: value` per line (a `#` after
  a space starts a comment), with the keys id, title, kind, ref, quote, lean, corpus, tests,
  upstream and level, and optionally depends and evidence, and no other key;
* id is the file name without `.md`; kind is `kernel` or `construct`; quote is a double-quoted
  string; upstream is empty or an issue number (`#123` or a URL ending in one);
* a ref `repo:<path>:<line>` names a file of this repository, and its line contains the quote;
* every name in lean is a declaration (`lean: not stated yet` names none). The declaration
  index is scripts/cited.py's `scan` over GPUProof/, MojoProof/ and MojoProofTest/, which lists
  the theorems each command `mojo_kernel n := ...` adds by its clauses (`n.covers`, `n.sound`,
  `n.correct`, ...; below, `generated`), plus the blocks `n.b<i>`, plus, for a name whose first
  component is another package's root (`FloatLib`, `TorchLean`), `scan` over that package's
  sources under .lake/packages. No Lean runs;
* every name in tests is a declaration or a module MojoProofTest.<M> with a file
  MojoProofTest/<M>.lean;
* every corpus entry is a path or a glob under tests/corpus/ that matches at least one file
  (the status counts the `.ll` files, the kernels);
* every depends entry is a card id, `<id>` in the card's area or else the one card of that id,
  or `<area>/<id>`;
* evidence is `L<k>: item, item; L<m>: ...`, each level once, at most the kind's top level;
  an item is a declaration name (as for lean), except that a GPU run level's items (kernel L1,
  construct L2) are files of this repository, each the record of a GPU run that agrees, by the
  check scripts/roadmap_llvm.py counts records by too (scripts/gpu_record.py, `problem`: its
  first line starts with `GPU run record:`, its `kernel:` line names a file under tests/corpus/,
  for a kernel card one of the card's corpus files, its `kernel sha256:` line is that file's
  sha256, its `result:` line starts with `agree`, it has at least one launch, and each launch
  compares a positive number of words, the number its `launches:` line's `where words = <expr>`
  gives at the launch, with an evaluator line saying that many words agree, the summary line and
  the compare command),
  and construct L3's items are kernel card ids whose card has L2 evidence;
* level is the computed level: the highest level whose evidence, and that of every level below
  it, is present (L0 is the card itself; construct L1's evidence is its lean names);
* a kernel's L2 evidence concludes `Kernel.Sound` of programs bound to corpus files, by the
  table roadmap/llvm-ir/programs.tsv (`programs`, `l2_problem`), which scripts/L3Programs.lean
  writes from the built environment: each theorem's row must name a declaration whose
  conclusion, after its binders, is `Kernel.Sound` of a program (or a conjunction of such), and
  every such program must be bound to a corpus file, that is, unfold to a program constant
  `mojo_import` added for that file, one of the card's corpus files, whose sha256 is the digest
  the row records. A theorem that mentions `Kernel.Sound` only in a premise or under a negation,
  or about a program that keeps an imported program's digest with another module, or another
  kernel's program, does not count. It must also have a witness, by the table
  roadmap/llvm-ir/witnesses.tsv (`witnesses`): a closed theorem
  `L.Valid ∧ ∃ y, Kernel.Obs … L … y ∧ Q y`, proved by `Kernel.Sound.exists_obs` at a proof that
  applies it (directly, through a conversion from `GPUProof.Kernel.Sound`, or as an instance), so
  that its premises hold together at a launch with a thread and some complete run observes an
  output its relation constrains; a theorem true for want of a run (its premises unsatisfiable,
  no thread, or no observation) has none;
* a kernel's L3 and L4 evidence is a theorem whose statement states that level about a run of a
  program bound to one of the card's corpus files, by the table roadmap/llvm-ir/evidence.tsv
  (`evidence_table`, `l34_problem`): each row is one program the statement mentions, with the
  levels the statement states about that program's observed runs only, and the row with the
  level must be bound to one of the card's files with that file's digest. A definition, a
  theorem about another kernel's run (one that mentions this kernel only in a premise), or one
  about no program does not count. The gate checks the three tables against the build
  (`lake env lean --run scripts/L3Programs.lean --check`); this script only reads them.

For a kernel's L2 to L4 evidence it also reads what the cited theorems' premises restrict, from the
theorem's statement and the section variables it takes (those it `include`s or names), in its
source, or for a name a `mojo_kernel` command adds, from the command's statement template in
MojoProof/Sym/KernelCmd.lean (the `mat` clause's theorems have none: their premises are not read):
the launches (`L.Valid`, and a grid or block of side 1 in `y` and `z`, `grid .y = 1`, is a
one-dimensional launch), and above L2 whether an output is assumed finite (`isFinite = true →`),
whether its real value is the exact one rounded (`roundAt`), and whether the thread's oracle fuses
no round (`% 3 ≠ 2`: no oracle number selects the fused `fadd contract` of its right-hand product).
A premise only some of a level's theorems have is reported after their names. This reads text, not
Lean: another premise on the launch's shape is reported as such, without its meaning.

It writes roadmap/STATUS.md (a table per area: each card's level, the evidence present above
it, the scope of the theorems it cites, and what the next level needs), roadmap/status.yaml
(the same as data), roadmap/graph.dot (the areas as clusters, the cards, and an edge from each
card to each card it depends on) and
roadmap/graph.svg (`/usr/bin/dot -Tsvg` on graph.dot, skipped if dot is missing). The output is
sorted and has no timestamps, so it is the same for the same cards and code.

With --check it writes nothing, and exits 1 if a check fails or if STATUS.md, status.yaml or
graph.dot differ from what it would write (graph.svg is not compared). Without it, it exits 1,
writing nothing, if a check fails. With --self-test it reads no card and exits 1 unless
`l2_problem`, `l34_problem` and the record check accept the good rows and records of `self_test`
and refuse its others, and scripts/gpu_record.py's self-test passes. Python 3 standard library only.
"""
import glob
import hashlib
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
import cited  # noqa: E402  (the declaration index: `scan`)
import gpu_record  # noqa: E402  (the check of a GPU run record: `problem`)

ROADMAP = ROOT / 'roadmap'
PROGRAMS = ROADMAP / 'llvm-ir' / 'programs.tsv'   # written by scripts/L3Programs.lean
REGEN = 'lake env lean --run scripts/L3Programs.lean'
PROGRAMS_HEADER = 'theorem\tmodule\tprogram\tfile\tsha256'
WITNESSES = ROADMAP / 'llvm-ir' / 'witnesses.tsv'   # written by scripts/L3Programs.lean
WITNESSES_HEADER = 'theorem\twitness'
EVIDENCE_TSV = ROADMAP / 'llvm-ir' / 'evidence.tsv'   # written by scripts/L3Programs.lean
EVIDENCE_HEADER = 'name\tkind\tlevels\tprogram\tfile\tsha256'
# an evidence name's kind and its rows: (program, file, sha256, the levels stated of its runs)
Evidence = dict[str, tuple[str, list[tuple[str, str, str, set[str]]]]]
REQUIRED = ('id', 'title', 'kind', 'ref', 'quote', 'lean', 'corpus', 'tests', 'upstream', 'level')
OPTIONAL = ('depends', 'evidence')
NONE = {'lean': 'not stated yet', 'corpus': 'none', 'tests': 'none'}

# The ladders: (level, meaning, the evidence the script accepts).
LADDER = {
    'kernel': [
        ('L0', 'card written', 'the card, with every check passing'),
        ('L1', 'imported, and the evaluator agrees with a GPU run: a conformance test of the '
         'evaluator against the GPU on the recorded inputs, not a proof',
         'a tracked record of a GPU run of the corpus kernel that agrees (a file of this '
         'repository)'),
        ('L2', 'memory safety and race freedom for every valid launch of the shape the theorem '
         'states',
         'a Kernel.Sound theorem (declaration name); the launches its premises admit are listed '
         'per card'),
        ('L3', 'the outputs are the TorchLean operation\'s, under the theorem\'s premises',
         'a theorem equating the output with the TorchLean operation (declaration name); its '
         'launch shape, and whether it needs a finite output and gives the real value rounded, '
         'are listed per card'),
        ('L4', 'an IEEE bound, or bit-exact',
         'a theorem bounding the error, or giving the exact bits (declaration name); its '
         'premises are listed per card as for L3'),
    ],
    'construct': [
        ('L0', 'card written', 'the card, with every check passing'),
        ('L1', 'modelled in Lean', 'the card\'s lean names'),
        ('L2', 'tested against the GPU: a conformance test of the model against the GPU on the '
         'recorded inputs, not a proof',
         'a tracked record of a GPU run of a test of the construct that agrees (a file of '
         'this repository)'),
        ('L3', 'used by a proved kernel', 'a kernel card id whose card has L2 evidence'),
    ],
}
GPU_LEVEL = {'kernel': 'L1', 'construct': 'L2'}
NEXT = {
    ('kernel', 'L1'): 'L1 needs a recorded GPU run (a conformance test, not a proof)',
    ('kernel', 'L2'): 'L2 needs a Kernel.Sound theorem',
    ('kernel', 'L3'): 'L3 needs a theorem against TorchLean',
    ('kernel', 'L4'): 'L4 needs an IEEE bound or bit-exact theorem',
    ('construct', 'L1'): 'L1 needs a Lean model',
    ('construct', 'L2'): 'L2 needs a recorded GPU run (a conformance test, not a proof)',
    ('construct', 'L3'): 'L3 needs a proved kernel that uses it',
}

BLOCK = re.compile(r'b\d+')
KERNEL = re.compile(r'^mojo_kernel\s+([^\s:]+)\s+:=')
EVIDENCE = re.compile(r'^\s*(L\d)\s*:\s*(.*?)\s*$')
REPO_REF = re.compile(r'^repo:([^:]+):(\d+)$')
ISSUE = re.compile(r'^(#\d+|\S+/(issues|pull)/\d+)$')
THEOREM = re.compile(
    r'^\s*(?:@\[[^\]]*\]\s*)?(?:(?:private|protected)\s+)*(?:theorem|lemma)\s+([^\s:({\[]+)')
SCOPE = re.compile(r'^\s*(namespace|section|end)\b\s*(.*)$')
VARIABLE = re.compile(r'^\s*variable\b(.*)$')
INCLUDE = re.compile(r'^\s*include\b(.*)$')
TEMPLATE = re.compile(r'theorem \$(\w+)Id\b')
SIDE = re.compile(r'\b(grid|block)\s+\.([xyz])\s*=\s*1\b')
SHAPE = re.compile(r'\b(grid|block)\s+\.[xyz]\s*(=|≤|<|≥|>|∣)')
VALID = re.compile(r'\bL\.Valid\b|\bLaunch\.Valid\b')
FINITE = re.compile(r'isFinite\s*=\s*true\s*→')
ROUNDED = re.compile(r'\broundAt\b')
NOFUSE = re.compile(r'%\s*3\s*≠\s*2\b')
OPEN, CLOSE = '({[⦃', ')}]⦄'


def binders(text: str) -> list[tuple[list[str], str]]:
    """The binders `(a b : T)`, `{a : T}`, `[T]` of `text` at bracket depth 0: names and text."""
    out, depth, start = [], 0, 0
    for i, ch in enumerate(text):
        if ch in OPEN:
            if depth == 0:
                start = i
            depth += 1
        elif ch in CLOSE and depth:
            depth -= 1
            if depth == 0:
                b = text[start:i + 1]
                head = b[1:-1].split(' : ', 1)
                names = head[0].split() if len(head) == 2 else []
                out.append((names, b))
    return out


def premises_of(text: str) -> dict[str, str]:
    """The theorems a Lean file declares, by full name, each with the text of its statement and of
    the section variables it takes (those it `include`s or names). Comments are blanked first."""
    text = cited.blank(text)
    lines = text.split('\n')
    out: dict[str, str] = {}
    stack: list[tuple[str, list, set]] = []   # (namespace segment or '', variables, included)
    i = 0
    while i < len(lines):
        line = lines[i]
        if m := SCOPE.match(line):
            if m.group(1) == 'end':
                if stack:
                    stack.pop()
            else:
                seg = m.group(2).split()[0] if m.group(1) == 'namespace' and m.group(2).split() \
                    else ''
                stack.append((seg, [], set()))
        elif (m := VARIABLE.match(line)) and stack:
            body = [m.group(1)]
            while i + 1 < len(lines) and lines[i + 1][:1] == ' ':
                i += 1
                body.append(lines[i])
            stack[-1][1].extend(binders(' '.join(body)))
        elif (m := INCLUDE.match(line)) and stack:
            stack[-1][2].update(m.group(1).split())
        elif m := THEOREM.match(line):
            body = []
            j = i
            while j < len(lines):
                body.append(lines[j].split(':=', 1)[0])
                if ':=' in lines[j]:
                    break
                j += 1
            stmt = ' '.join(body)
            words = set(re.findall(r"[^\s(){}\[\]⦃⦄,:]+", stmt))
            taken = [b for _, vs, inc in stack for names, b in vs
                     if any(n in inc or n in words for n in names)]
            cur = '.'.join(seg for seg, _, _ in stack if seg)
            out[f'{cur}.{m.group(1)}' if cur else m.group(1)] = ' '.join(taken + [stmt])
            i = j
        i += 1
    return out


def launch_scope(text: str) -> str:
    """The launches a statement admits, from its premises `grid .y = 1`, ... and `L.Valid`."""
    sides: dict[str, set[str]] = {}
    for part, d in SIDE.findall(text):
        sides.setdefault(part, set()).add(d)
    valid = 'valid ' if VALID.search(text) else ''
    other = ' (and other premises on the shape)' if SHAPE.search(SIDE.sub('', text)) else ''
    if not sides:
        return (f'every {valid}launch' if valid and not other
                else 'the launches its premises admit')
    by_dims: dict[tuple[str, ...], list[str]] = {}
    for part, ds in sides.items():
        by_dims.setdefault(tuple(sorted(ds)), []).append(part)
    shape = ', '.join(f'{" and ".join(sorted(ps))} of side 1 in {" and ".join(ds)}'
                      for ds, ps in sorted(by_dims.items()))
    if sides.get('grid') == {'y', 'z'} and sides.get('block') == {'y', 'z'}:
        return f'{valid}one-dimensional launches ({shape}){other}'
    return f'{valid}launches with {shape}{other}'


def scope(level: str, text: str | None) -> list[str]:
    """What a cited theorem's premises restrict, the launches first: for L2 the launches, above
    it also whether a finite output is assumed, whether the real value is the exact one rounded,
    and whether the thread's oracle fuses no round (no oracle number 2 modulo 3, `% 3 ≠ 2`: the
    oracle number of `contract` that fuses the product on the right of an `fadd`)."""
    if text is None:
        return ['premises not read']
    qs = [launch_scope(text)]
    if level != 'L2':
        fin, rnd = FINITE.search(text), ROUNDED.search(text)
        if fin and rnd:
            qs.append('where the output is finite and is the exact real result rounded to the '
                      'format')
        elif fin:
            qs.append('where the output is finite')
        elif rnd:
            qs.append('where the output is the exact real result rounded to the format')
        if NOFUSE.search(text):
            qs.append('for a thread whose oracle fuses no round (no oracle number 2 modulo 3)')
    return qs


def short(name: str) -> str:
    """A declaration's name without the library's root namespace."""
    for root in ('MojoProofTest.', 'MojoProof.'):
        if name.startswith(root):
            return name[len(root):]
    return name


def level_scope(scopes: dict[str, list[str]]) -> str:
    """The scope of one level's cited theorems (`scope` of each, by name): the launches and
    premises they all have, then each premise only some have, after the names of those; if
    their launches differ, each theorem's scope after its name."""
    if not scopes:
        return ''
    first = next(iter(scopes.values()))
    if all(sc == first for sc in scopes.values()):
        return ', '.join(first)
    if any(sc[0] != first[0] for sc in scopes.values()):
        return '; '.join(dict.fromkeys(f'{short(n)}: {", ".join(sc)}'
                                       for n, sc in scopes.items()))
    common = [q for q in first[1:] if all(q in sc[1:] for sc in scopes.values())]
    own: dict[str, list[str]] = {}
    for n, sc in scopes.items():
        for q in sc[1:]:
            if q not in common:
                own.setdefault(q, []).append(short(n))
    return ', '.join([first[0]] + common + [f'{" and ".join(ns)} only {q}'
                                            for q, ns in own.items()])


class Index:
    """The declaration index: GPUProof/, MojoProof/ and MojoProofTest/, and other packages on
    demand."""

    def __init__(self):
        self.decls: set[str] = set()
        self.generated: set[str] = set()   # the names `scan` lists under a mojo_kernel command
        self.kernels: set[str] = set()     # their kernels' full names, for `n.b<i>`
        self.statements: dict[str, str] = {}   # theorem name: its statement with premises
        self.templates: dict[str, str] = {}    # generated suffix: the command's statement text
        for d in ('GPUProof', 'MojoProof', 'MojoProofTest'):
            for p in sorted((ROOT / d).rglob('*.lean')):
                self.add_file(p.read_text())
        cmd = (ROOT / 'MojoProof' / 'Sym' / 'KernelCmd.lean').read_text()
        for m in TEMPLATE.finditer(cmd):
            self.templates.setdefault(m.group(1), cmd[m.start():].split(':=', 1)[0])
        self.packages: dict[str, set[str]] = {}
        self.table: dict[str, tuple[str, list[tuple[str, str, str]]]] | None = None
        self.wit: dict[str, list[str]] | None = None
        self.ev: Evidence | None = None

    def programs(self) -> dict[str, tuple[str, list[tuple[str, str, str]]]]:
        """The table of programs (`programs`), read once."""
        if self.table is None:
            self.table = programs()
        return self.table

    def witnesses(self) -> dict[str, list[str]]:
        """The witness table (`witnesses`), read once."""
        if self.wit is None:
            self.wit = witnesses()
        return self.wit

    def evidence(self) -> Evidence:
        """The table of the cards' L3 and L4 names (`evidence_table`), read once."""
        if self.ev is None:
            self.ev = evidence_table()
        return self.ev

    def add_file(self, text: str) -> None:
        decls = cited.scan(text)[0]
        self.decls |= decls
        self.statements.update(premises_of(text))
        # as `cited.scan` reads the file: comments blanked, the kernel's full name from the
        # namespaces open at the command
        lines = cited.blank(text).split('\n')
        stack: list[str] = []   # namespace segments, '' for a section or a mutual block
        prev = ''
        for line in lines:
            if m := cited.SCOPE.match(line):
                kind, rest = m.group(1), m.group(2).split()
                if kind == 'namespace' and rest:
                    stack.append(rest[0])
                elif kind in ('section', 'mutual'):
                    stack.append('')
                elif kind == 'end' and stack:
                    stack.pop()
            m = KERNEL.match(line)
            if m and not cited.GUARD.match(prev.strip()):
                base = '.'.join([s for s in stack if s] + [m.group(1)])
                if base in decls:
                    self.kernels.add(base)
                    self.generated |= {d for d in decls if d.rpartition('.')[0] == base}
            if line.strip():
                prev = line

    def package(self, root: str) -> set[str] | None:
        if root not in self.packages:
            found = None
            for pkg in sorted((ROOT / '.lake' / 'packages').glob('*')):
                if (pkg / root).is_dir() or (pkg / f'{root}.lean').is_file():
                    found = set()
                    for p in sorted(pkg.rglob('*.lean')):
                        if '.lake' not in p.relative_to(pkg).parts:
                            found |= cited.scan(p.read_text(errors='replace'))[0]
                    break
            self.packages[root] = found
        return self.packages[root]

    def statement(self, name: str) -> str | None:
        """The statement of theorem `name` with its premises: from its source, or for a name a
        `mojo_kernel` command adds, from the command's template."""
        if name in self.statements:
            return self.statements[name]
        if name in self.generated:
            return self.templates.get(name.rpartition('.')[2])
        return None

    def has(self, name: str) -> bool:
        if name in self.decls or name in self.generated:
            return True
        head, _, last = name.rpartition('.')
        if BLOCK.fullmatch(last) and head in self.kernels:
            return True
        root = name.split('.')[0]
        if root in ('GPUProof', 'MojoProof', 'MojoProofTest'):
            return False
        pkg = self.package(root)
        return pkg is not None and name in pkg


def programs(text: str | None = None) -> dict[str, tuple[str, list[tuple[str, str, str]]]]:
    """The table scripts/L3Programs.lean writes from the built environment
    (roadmap/llvm-ir/programs.tsv, or `text`): for each theorem, its module (`-`: no declaration)
    and the programs its conclusion is about, each as (program, file, sha256): the program
    constant `mojo_import` added that it unfolds to, that constant's corpus file and recorded
    digest, or for a program bound to no file its term and `-`, `-`. Raises ValueError on a table
    of another shape."""
    if text is None:
        text = PROGRAMS.read_text() if PROGRAMS.is_file() else ''
    rows = text.split('\n')
    if rows[0] != PROGRAMS_HEADER:
        raise ValueError(f'roadmap/llvm-ir/programs.tsv is no table of programs; run `{REGEN}`')
    out: dict[str, tuple[str, list[tuple[str, str, str]]]] = {}
    for r in rows[1:]:
        if r:
            cols = r.split('\t')
            if len(cols) != 5:
                raise ValueError(f'roadmap/llvm-ir/programs.tsv: a row of {len(cols)} columns, '
                                 f'not 5: {r!r}; run `{REGEN}`')
            n, mod, prog, f, sha = cols
            ps = out.setdefault(n, (mod, []))[1]
            if prog != '-':
                ps.append((prog, f, sha))
    return out


def table_rows(path: pathlib.Path, header: str, cols: int,
               text: str | None = None) -> list[list[str]]:
    """The rows of a table scripts/L3Programs.lean writes (`path`, or `text`), each split into its
    `cols` columns. Raises ValueError on another header line or a row of another width."""
    if text is None:
        text = path.read_text() if path.is_file() else ''
    rel = path.relative_to(ROOT).as_posix()
    rows = text.split('\n')
    if rows[0] != header:
        raise ValueError(f'{rel} is not the table scripts/L3Programs.lean writes; run `{REGEN}`')
    out = []
    for r in rows[1:]:
        if r:
            cs = r.split('\t')
            if len(cs) != cols:
                raise ValueError(f'{rel}: a row of {len(cs)} columns, not {cols}: {r!r}; '
                                 f'run `{REGEN}`')
            out.append(cs)
    return out


def witnesses(text: str | None = None) -> dict[str, list[str]]:
    """The witness table scripts/L3Programs.lean writes (roadmap/llvm-ir/witnesses.tsv, or
    `text`): for each theorem of the table of programs, its witnesses, the theorems that apply it
    by `Kernel.Sound.exists_obs` at premises they prove, with no premise of their own, and an
    observation and a relation that depend on the output (none: an empty list)."""
    out: dict[str, list[str]] = {}
    for n, w in table_rows(WITNESSES, WITNESSES_HEADER, 2, text):
        ws = out.setdefault(n, [])
        if w != '-':
            ws.append(w)
    return out


def evidence_table(text: str | None = None) -> Evidence:
    """The table of the kernel cards' L3 and L4 names scripts/L3Programs.lean writes
    (roadmap/llvm-ir/evidence.tsv, or `text`): for each name, its kind (`theorem`, `definition`,
    `other`, or `-` for no declaration) and one row per program its type mentions (in a
    `Kernel.Sound`, `Kernel.Safe`, `GPUProof.Kernel.Sound` or `Kernel.Obs` anywhere in it):
    (program, file, sha256) as in `programs`, and the levels the statement states about the
    observed runs of that program and function only (L3Programs' level rule, `runLevels`: `L3`
    for an output of the run equal to a TorchLean operation's value, `L4` for an output's real
    value equal to a real rounded or an error bound on it; none for `-`). A name whose type
    mentions no program has no row."""
    out: Evidence = {}
    for n, kind, lvs, prog, f, sha in table_rows(EVIDENCE_TSV, EVIDENCE_HEADER, 6, text):
        rows = out.setdefault(n, (kind, []))[1]
        if prog != '-':
            rows.append((prog, f, sha, set(lvs.split()) - {'-'}))
    return out


DIGESTS: dict[str, str | None] = {}


def digest(rel: str) -> str | None:
    """The sha256 of the file `rel` (relative to the repository), None if it is no file."""
    if rel not in DIGESTS:
        f = ROOT / rel
        DIGESTS[rel] = hashlib.sha256(f.read_bytes()).hexdigest() \
            if '..' not in rel and f.is_file() else None
    return DIGESTS[rel]


def l2_problem(table: dict[str, tuple[str, list[tuple[str, str, str]]]], name: str,
               corpus: set[str] | None = None,
               wit: dict[str, list[str]] | None = None) -> str | None:
    """Why theorem `name` is no L2 evidence by the table of programs (`programs`), or None when
    it is: it must have a row (else the table is stale), be a declaration, conclude `Kernel.Sound`
    of a program, and have every program its conclusion is about bound to a corpus file. For a
    kernel card, `corpus` is the card's corpus files: each such file must be one of them and have
    the digest its row records. With the witness table `wit` (`witnesses`), it must have a
    witness: a theorem with no premise that applies it at an admitted choice and reaches an
    observed output its relation constrains (scripts/L3Programs.lean, `witnessOf`), so that its
    premises can be met and it is not true for want of a run."""
    if name not in table:
        return f'has no row in roadmap/llvm-ir/programs.tsv; run `{REGEN}`'
    mod, ps = table[name]
    if mod == '-':
        return 'is no declaration (roadmap/llvm-ir/programs.tsv)'
    if not ps:
        return 'does not conclude Kernel.Sound of a program (roadmap/llvm-ir/programs.tsv)'
    unbound = [p for p, f, _ in ps if f == '-']
    if unbound:
        return (f'concludes Kernel.Sound of {", ".join(unbound)}, which no corpus file\'s '
                'imported program is (roadmap/llvm-ir/programs.tsv)')
    if corpus is not None:
        for p, f, sha in ps:
            if f not in corpus:
                return (f'concludes Kernel.Sound of {p}, bound to {f}, which is none of the '
                        'card\'s corpus files (roadmap/llvm-ir/programs.tsv)')
            if digest(f) != sha:
                return (f'concludes Kernel.Sound of {p}, which records the digest {sha}, not the '
                        f'sha256 of {f} (roadmap/llvm-ir/programs.tsv)')
    if wit is not None:
        if name not in wit:
            return f'has no row in roadmap/llvm-ir/witnesses.tsv; run `{REGEN}`'
        if not wit[name]:
            return ('has no witness (roadmap/llvm-ir/witnesses.tsv): no theorem without premises '
                    'applies it by Kernel.Sound.exists_obs to an admitted choice and an observed '
                    'output that its relation constrains')
    return None


def l34_problem(ev: Evidence, name: str, corpus: set[str], level: str) -> str | None:
    """Why `name` is no evidence at `level` (`L3` or `L4`) of a kernel card whose corpus files are
    `corpus`, by the table of the cards' L3 and L4 names (`evidence_table`), or None when it is:
    it must have a row (else the table is stale), be a theorem, and state `level` about a run of
    the kernel: one of its rows, a program bound with its function to one of the card's corpus
    files with that file's digest, must have `level` among the levels stated of that program's
    runs. A statement that mentions the kernel only in a premise (its levels are another run's),
    or concludes soundness and nothing about an output, has no level for it."""
    if name not in ev:
        return f'has no row in roadmap/llvm-ir/evidence.tsv; run `{REGEN}`'
    kind, rows = ev[name]
    if kind == '-':
        return 'is no declaration (roadmap/llvm-ir/evidence.tsv)'
    if kind != 'theorem':
        return f'is a {kind}, not a theorem (roadmap/llvm-ir/evidence.tsv)'
    if not any(level in lvs for _, _, _, lvs in rows):
        said = '; '.join(f'{p}: {" ".join(sorted(lvs)) or "none"}' for p, _, _, lvs in rows)
        return (f'states {level} of no run: the levels of its programs\' runs are '
                f'{said or "none (no program)"} (roadmap/llvm-ir/evidence.tsv)')
    if not any(level in lvs and f in corpus and digest(f) == sha for _, f, sha, lvs in rows):
        said = ', '.join(f'{p} ({f})' for p, f, _, lvs in rows if level in lvs)
        return (f'states {level} only of runs of {said}, no program of the card\'s corpus files '
                '(roadmap/llvm-ir/evidence.tsv)')
    return None


def self_test() -> int:
    """`l2_problem`, `l34_problem` and the record check (scripts/gpu_record.py) on rows of the
    shapes scripts/L3Programs.lean's self-test elaborates and on records. By the table of
    programs alone: a theorem about a program bound to a file and one about two such programs
    pass; a premise-only or negated mention (a declaration with no program), a mutant that keeps
    a corpus digest (a program bound to no file), a theorem with a bound and an unbound program, a
    name with no declaration and a name with no row fail; a table of the old four-column shape is
    refused.
    At the vadd card's corpus files, on the tables' rows of the real theorems: vadd's theorem with
    its witness passes; vmul's theorem (another kernel's file), a row whose digest is not its
    file's, a theorem with no witness (`outer`, true for want of a run) and one with no row in the
    witness table fail. As L3 and as L4 evidence of that card: vadd's `vadd_real` (of both
    forms) passes; the definition `vadd.bytes`, vmul's `vmul_real`, a theorem about vadd's
    program only in a premise (`premise`), one whose conclusion is soundness and `True` (`both`),
    both of no level, `pair` (its output identified by no equation, no level), and a theorem
    about no program (an old row with levels and no program) fail; a theorem of the form of L3
    only passes as L3 and fails as L4; `vmul_extra`, about vadd's run with a premise about a vmul
    run, passes at the vadd card and fails at the vmul card. As GPU run
    records of that card: tests/gpu/vadd/record.txt passes; a record of three lines (its first
    line, the kernel and an agreeing result), one whose kernel sha256 is changed, one with a
    launch that disagrees and one whose first launch compares no word (`launch: 1 1 1 0`, its
    evaluator line `0 words agree`) fail; and scripts/gpu_record.py's own self-test passes."""
    d = '8e4779ad' + '0' * 56
    t = programs(PROGRAMS_HEADER + '\n'
                 f'T.outer\tT\tT.p.prog\ttests/corpus/vadd/a.ll\t{d}\n'
                 f'T.two\tT\tT.p.prog\ttests/corpus/vadd/a.ll\t{d}\n'
                 f'T.two\tT\tT.q.prog\ttests/corpus/vmul/b.ll\t{d}\n'
                 'T.premise\tT\t-\t-\t-\n'
                 'T.negated\tT\t-\t-\t-\n'
                 'T.mutant\tT\tT.m.prog\t-\t-\n'
                 f'T.mixed\tT\tT.p.prog\ttests/corpus/vadd/a.ll\t{d}\n'
                 'T.mixed\tT\tT.m.prog\t-\t-\n'
                 'T.missing\t-\t-\t-\t-\n')
    bad = [n for n in ('T.outer', 'T.two') if l2_problem(t, n) is not None]
    bad += [n for n in ('T.premise', 'T.negated', 'T.mutant', 'T.mixed', 'T.missing', 'T.absent')
            if l2_problem(t, n) is None]
    try:
        programs('theorem\tmodule\tprogram\tsha256\n' f'T.outer\tT\tT.p.prog\t{d}\n')
        bad.append('the four-column table')
    except ValueError:
        pass
    va = 'tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll'
    vm = ('tests/corpus/vmul/'
          'vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff.nvptx.ll')
    corpus = {va}
    real = programs(PROGRAMS_HEADER + '\n'
                    f'K.vadd.correct\tK\tK.vadd.prog\t{va}\t{digest(va)}\n'
                    f'K.vmul.correct\tK\tK.vmul.prog\t{vm}\t{digest(vm)}\n'
                    f'K.stale\tK\tK.vadd.prog\t{va}\t{d}\n'
                    f'T.outer\tT\tK.vadd.prog\t{va}\t{digest(va)}\n'
                    f'T.unlisted\tT\tK.vadd.prog\t{va}\t{digest(va)}\n')
    wit = witnesses(WITNESSES_HEADER + '\n'
                    'K.vadd.correct\tT.vadd_obs23\n'
                    'K.vmul.correct\tT.vmul_obs23\n'
                    'K.stale\tT.vadd_obs23\n'
                    'T.outer\t-\n')
    if l2_problem(real, 'K.vadd.correct', corpus, wit) is not None:
        bad.append('vadd.correct at the vadd card')
    bad += [f'{n} at the vadd card' for n in ('K.vmul.correct', 'K.stale', 'T.outer', 'T.unlisted')
            if l2_problem(real, n, corpus, wit) is None]
    ev = evidence_table(EVIDENCE_HEADER + '\n'
                        f'T.vadd_real\ttheorem\tL3 L4\tK.vadd.prog\t{va}\t{digest(va)}\n'
                        f'T.vadd_eq\ttheorem\tL3\tK.vadd.prog\t{va}\t{digest(va)}\n'
                        f'K.vadd.bytes\tdefinition\t-\tK.vadd.prog\t{va}\t{digest(va)}\n'
                        f'T.vmul_real\ttheorem\tL3 L4\tK.vmul.prog\t{vm}\t{digest(vm)}\n'
                        f'T.premise\ttheorem\t-\tT.p.prog\t{va}\t{digest(va)}\n'
                        f'T.both\ttheorem\t-\tT.p.prog\t{va}\t{digest(va)}\n'
                        f'T.pair\ttheorem\t-\tK.vadd.prog\t{va}\t{digest(va)}\n'
                        f'T.vmul_extra\ttheorem\tL3 L4\tK.vadd.prog\t{va}\t{digest(va)}\n'
                        f'T.vmul_extra\ttheorem\t-\tK.vmul.prog\t{vm}\t{digest(vm)}\n'
                        'T.nothing\ttheorem\tL3 L4\t-\t-\t-\n')
    for lv in ('L3', 'L4'):
        for n in ('T.vadd_real', 'T.vmul_extra'):
            if l34_problem(ev, n, corpus, lv) is not None:
                bad.append(f'{n} as {lv} evidence of the vadd card')
        bad += [f'{n} as {lv} evidence of the vadd card'
                for n in ('K.vadd.bytes', 'T.vmul_real', 'T.premise', 'T.both', 'T.pair',
                          'T.nothing', 'T.absent') if l34_problem(ev, n, corpus, lv) is None]
        if l34_problem(ev, 'T.vmul_extra', {vm}, lv) is None:
            bad.append(f'vmul_extra as {lv} evidence of the vmul card')
        if l34_problem(ev, 'T.vmul_real', {vm}, lv) is not None:
            bad.append(f'vmul_real as {lv} evidence of the vmul card')
    if l34_problem(ev, 'T.vadd_eq', corpus, 'L3') is not None:
        bad.append('vadd_eq as L3 evidence of the vadd card')
    if l34_problem(ev, 'T.vadd_eq', corpus, 'L4') is None:
        bad.append('vadd_eq as L4 evidence of the vadd card')
    rec = (ROOT / 'tests/gpu/vadd/record.txt').read_text()
    if (why := gpu_record.problem(rec, ROOT, corpus)) is not None:
        bad.append(f'tests/gpu/vadd/record.txt ({why})')
    three = f'GPU run record: a conformance test, not a proof.\nkernel: {va}\nresult: agree\n'
    shaed = rec.replace(digest(va), d)
    differ = rec.replace('launches, 0 differ', 'launches, 1 differ')
    zero = rec.replace('launch: 1 1 1 65', 'launch: 1 1 1 0').replace(
        'n 1 grid 1 block 1: 65 words agree', 'n 1 grid 1 block 1: 0 words agree')
    bad += [f'the {n} record' for n, r in (('three-line', three), ('changed sha', shaed),
                                            ('disagreeing', differ), ('zero-word', zero))
            if r == rec or gpu_record.problem(r, ROOT, corpus) is None]
    bad += gpu_record.self_test(ROOT)
    for n in bad:
        print(f'self-test: {n} is not what the check should make of it')
    print('self-test: ' + ('failed' if bad else
                           'the bound rows pass; the premise, the negation, the mutant, the mixed '
                           'row, the missing name and the old table fail; at the vadd card, '
                           'vmul\'s theorem, the stale digest, the theorem with no witness, the '
                           'definition, the other kernel\'s theorem, the premise, the soundness '
                           'conjunction, the unidentified pair and the program-less theorem as L3 '
                           'and L4, the L3 form as L4, the extra premise\'s run at the vmul card, '
                           'the three-line, re-hashed, disagreeing and zero-word records '
                           'fail'))
    return 1 if bad else 0


def items(value: str) -> list[str]:
    return [x.strip() for x in value.split(',') if x.strip()]


def front_matter(text: str) -> tuple[dict[str, str], str]:
    """The card's keys and values, and its body; raises ValueError on a malformed header."""
    lines = text.split('\n')
    if not lines or lines[0].strip() != '---':
        raise ValueError('no front matter (the first line is not ---)')
    try:
        end = lines.index('---', 1)
    except ValueError:
        raise ValueError('front matter not closed by ---') from None
    keys: dict[str, str] = {}
    for line in lines[1:end]:
        if not line.strip():
            continue
        m = re.match(r'^([a-z]+):(.*)$', line)
        if not m:
            raise ValueError(f'not a key: value line: {line!r}')
        key, value = m.group(1), m.group(2)
        if key != 'quote':
            value = re.sub(r'(^|\s)#\s.*$', '', value)
        else:
            value = re.sub(r'("(?:[^"\\]|\\.)*")\s+#\s.*$', r'\1', value)
        if key in keys:
            raise ValueError(f'key {key} twice')
        keys[key] = value.strip()
    return keys, '\n'.join(lines[end + 1:])


def parse_evidence(value: str) -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for part in value.split(';'):
        if not part.strip():
            continue
        m = EVIDENCE.match(part)
        if not m:
            raise ValueError(f'evidence part {part.strip()!r} is not L<k>: items')
        if m.group(1) in out:
            raise ValueError(f'evidence level {m.group(1)} twice')
        out[m.group(1)] = items(m.group(2))
        if not out[m.group(1)]:
            raise ValueError(f'evidence level {m.group(1)} has no item')
    return out


class Card:
    def __init__(self, area: str, path: pathlib.Path):
        self.area, self.path, self.id = area, path, path.stem
        self.keys, self.body = front_matter(path.read_text())
        self.evidence: dict[str, list[str]] = {}
        self.level = 'L0'
        self.present: list[str] = []   # levels above `level` with evidence present
        self.files = 0                 # corpus kernels (.ll files) matched
        self.corpus: set[str] = set()  # the corpus files matched, relative to the repository
        self.scopes: dict[str, str] = {}   # kernel level: what its theorems' premises restrict

    @property
    def key(self) -> str:
        return f'{self.area}/{self.id}'


def check_card(c: Card, index: Index) -> list[str]:
    """The card's problems, the evidence present (in `c.evidence`) set aside for `levels`."""
    errs = []
    k = c.keys
    missing = [x for x in REQUIRED if x not in k]
    extra = sorted(set(k) - set(REQUIRED) - set(OPTIONAL))
    if missing:
        return [f'missing keys: {", ".join(missing)}']
    if extra:
        errs.append(f'unknown keys: {", ".join(extra)}')
    if k['id'] != c.id:
        errs.append(f'id {k["id"]!r} is not the file name {c.id!r}')
    if k['kind'] not in LADDER:
        return errs + [f'kind {k["kind"]!r} is not kernel or construct']
    if not k['title']:
        errs.append('empty title')
    if not k['ref']:
        errs.append('empty ref')
    q = k['quote']
    if not (len(q) >= 2 and q[0] == '"' and q[-1] == '"'):
        errs.append('quote is not a double-quoted string')
    quote = q[1:-1].replace('\\"', '"').replace('\\\\', '\\')
    if m := REPO_REF.match(k['ref']):
        f = ROOT / m.group(1)
        lines = f.read_text().split('\n') if f.is_file() else None
        n = int(m.group(2))
        if lines is None:
            errs.append(f'ref names no file {m.group(1)}')
        elif not 1 <= n <= len(lines) or not quote or quote not in lines[n - 1]:
            errs.append(f'quote is not on line {n} of {m.group(1)}')
    if k['upstream'] and not ISSUE.match(k['upstream']):
        errs.append('upstream is neither empty nor an issue number')
    if k['lean'] != NONE['lean']:
        for n in items(k['lean']):
            if not index.has(n):
                errs.append(f'lean name {n} is no declaration')
    if k['tests'] != NONE['tests']:
        for n in items(k['tests']):
            mod = n.startswith('MojoProofTest.') and (
                ROOT / (n.replace('.', '/') + '.lean')).is_file()
            if not mod and not index.has(n):
                errs.append(f'test {n} is no declaration or test module')
    if k['corpus'] != NONE['corpus']:
        for p in items(k['corpus']):
            hits = [h for h in glob.glob(str(ROOT / p), recursive=True)]
            files = [h for h in hits if pathlib.Path(h).is_file()]
            files += [str(f) for h in hits if pathlib.Path(h).is_dir()
                      for f in pathlib.Path(h).rglob('*') if f.is_file()]
            if not p.startswith('tests/corpus/') or '..' in p or not files:
                errs.append(f'corpus path {p} matches no file under tests/corpus')
            c.files += len({f for f in files if f.endswith('.ll')})
            c.corpus |= {pathlib.Path(f).relative_to(ROOT).as_posix() for f in files}
    try:
        c.evidence = parse_evidence(k.get('evidence', ''))
    except ValueError as e:
        return errs + [str(e)]
    top = LADDER[k['kind']][-1][0]
    for lv, its in sorted(c.evidence.items()):
        if lv == 'L0' or lv > top:
            errs.append(f'evidence level {lv} is not one of L1-{top[1]} for a {k["kind"]}')
        elif lv == GPU_LEVEL[k['kind']]:
            for p in its:
                if not (ROOT / p).is_file() or '..' in p:
                    errs.append(f'{lv} evidence {p} is no file of this repository')
                elif bad := gpu_record.problem((ROOT / p).read_text(), ROOT,
                                               c.corpus if k['kind'] == 'kernel' else None):
                    errs.append(f'{lv} evidence {p} {bad}')
        elif not (k['kind'] == 'construct' and lv == 'L3'):
            for n in its:
                if not index.has(n):
                    errs.append(f'{lv} evidence {n} is no declaration')
            if k['kind'] == 'kernel':
                c.scopes[lv] = level_scope({n: scope(lv, index.statement(n)) for n in its})
                if lv == 'L2':
                    try:
                        table, wit = index.programs(), index.witnesses()
                    except ValueError as e:
                        errs.append(str(e))
                        table = wit = None
                    for n in its:
                        if table is not None and index.has(n) and \
                                (bad := l2_problem(table, n, c.corpus, wit)) is not None:
                            errs.append(f'L2 evidence {n} {bad}')
                elif lv in ('L3', 'L4'):
                    try:
                        ev = index.evidence()
                    except ValueError as e:
                        errs.append(str(e))
                        ev = None
                    for n in its:
                        if ev is not None and index.has(n) and \
                                (bad := l34_problem(ev, n, c.corpus, lv)) is not None:
                            errs.append(f'{lv} evidence {n} {bad}')
    return errs


def scope_line(c: Card) -> str:
    """The scopes of the card's cited theorems, levels with the same scope together."""
    groups: dict[str, list[str]] = {}
    for lv in sorted(c.scopes):
        groups.setdefault(c.scopes[lv], []).append(lv)
    return '; '.join(f'{", ".join(lvs)}: {sc}' for sc, lvs in groups.items())


def resolve(ref: str, area: str, cards: dict[str, Card]) -> Card | None:
    if '/' in ref:
        return cards.get(ref)
    if f'{area}/{ref}' in cards:
        return cards[f'{area}/{ref}']
    same = [c for c in cards.values() if c.id == ref]
    return same[0] if len(same) == 1 else None


def levels(cards: dict[str, Card]) -> list[str]:
    """Compute each card's level and evidence present; the cards' level and depends problems."""
    errs = []
    for c in cards.values():
        kind = c.keys['kind']
        met = {'L0': True}
        if kind == 'construct':
            met['L1'] = c.keys['lean'] != NONE['lean']
            if 'L1' in c.evidence:
                errs.append(f'{c.key}: construct L1 evidence is its lean names, not an evidence entry')
        for lv, its in c.evidence.items():
            if kind == 'construct' and lv == 'L3':
                ok = True
                for i in its:
                    k = resolve(i, c.area, cards)
                    if k is None or k.keys['kind'] != 'kernel' or 'L2' not in k.evidence:
                        errs.append(f'{c.key}: L3 evidence {i} is no kernel card with L2 evidence')
                        ok = False
                met[lv] = ok
            else:
                met[lv] = True
        ladder = [lv for lv, _, _ in LADDER[kind]]
        c.level = 'L0'
        for lv in ladder[1:]:
            if not met.get(lv):
                break
            c.level = lv
        c.present = [lv for lv in ladder if lv > c.level and met.get(lv)]
        if c.keys['level'] != c.level:
            errs.append(f'{c.key}: level {c.keys["level"]} but the computed level is {c.level}')
        for d in items(c.keys.get('depends', '')):
            if resolve(d, c.area, cards) is None:
                errs.append(f'{c.key}: depends on {d}, which is no card (or more than one)')
    return errs


def status_line(c: Card) -> tuple[str, str]:
    """The evidence present above the card's level, and what the next level needs."""
    kind = c.keys['kind']
    ladder = [lv for lv, _, _ in LADDER[kind]]
    if c.level == ladder[-1]:
        return '', 'top level'
    nxt = ladder[ladder.index(c.level) + 1]
    present = ''
    if c.present:
        ps = c.present
        present = (ps[0] if len(ps) == 1 else ', '.join(ps[:-1]) + ' and ' + ps[-1]) + \
            ' evidence present'
    return present, NEXT[(kind, nxt)]


def md(s: str) -> str:
    return s.replace('|', '\\|')


def write_status(areas: dict[str, str], cards: dict[str, Card]) -> str:
    out = ['# Roadmap status', '',
           'Written by `scripts/roadmap_status.py` from the cards and the code. Do not edit; run',
           '`python3 scripts/roadmap_status.py` after changing a card or a declaration it names.',
           'roadmap/README.md describes the cards and the levels.', '']
    for kind, ladder in sorted(LADDER.items()):
        out += [f'## The {kind} ladder', '', '| Level | Meaning | Evidence |', '|---|---|---|']
        out += [f'| {lv} | {m} | {e} |' for lv, m, e in ladder]
        out.append('')
    out += ['## Summary', '', '| Area | Cards | ' + ' | '.join(f'L{i}' for i in range(5)) + ' |',
            '|---|---|' + '---|' * 5]
    for a in sorted(areas):
        cs = [c for c in cards.values() if c.area == a]
        counts = [sum(c.level == f'L{i}' for c in cs) for i in range(5)]
        out.append(f'| [{md(areas[a])}]({a}/README.md) | {len(cs)} | ' +
                   ' | '.join(str(n) for n in counts) + ' |')
    runs = sorted({p for c in cards.values() for p in c.evidence.get(GPU_LEVEL[c.keys['kind']], [])})
    out += ['', f'Records of GPU runs the cards cite: {len(runs)}' + (
        '.' if runs else '. Kernel L1 and construct L2 need one, so no kernel card is past L0 and '
        'no construct card past L1; the evidence present above a card\'s level is listed with it.'),
        '']
    for a in sorted(areas):
        out += [f'## {md(areas[a])}', '', f'[{a}/README.md]({a}/README.md)', '',
                '| Card | Kind | Level | Evidence above the level | Scope of the cited theorems | '
                'Next | Corpus kernels |',
                '|---|---|---|---|---|---|---|']
        for c in sorted((c for c in cards.values() if c.area == a), key=lambda c: c.id):
            present, nxt = status_line(c)
            out.append(f'| [{c.id}]({a}/cards/{c.id}.md): {md(c.keys["title"])} | '
                       f'{c.keys["kind"]} | {c.level} | {present or "-"} | '
                       f'{md(scope_line(c)) or "-"} | {nxt} | {c.files} |')
        out.append('')
    return '\n'.join(out)


def yq(s: str) -> str:
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def write_yaml(areas: dict[str, str], cards: dict[str, Card]) -> str:
    out = ['# Written by scripts/roadmap_status.py from the cards and the code. Do not edit.',
           'areas:']
    for a in sorted(areas):
        cs = sorted((c for c in cards.values() if c.area == a), key=lambda c: c.id)
        out += [f'  - id: {a}', f'    title: {yq(areas[a])}', f'    readme: roadmap/{a}/README.md',
                '    levels: {' + ', '.join(
                    f'L{i}: {sum(c.level == f"L{i}" for c in cs)}' for i in range(5)) + '}',
                '    cards:']
        for c in cs:
            present, nxt = status_line(c)
            out += [f'      - id: {c.id}', f'        title: {yq(c.keys["title"])}',
                    f'        kind: {c.keys["kind"]}', f'        level: {c.level}',
                    '        evidence_present: [' + ', '.join(c.present) + ']',
                    '        evidence_scope: {' + ', '.join(
                        f'{lv}: {yq(sc)}' for lv, sc in sorted(c.scopes.items())) + '}',
                    f'        next: {yq(nxt)}', f'        corpus_kernels: {c.files}',
                    '        lean: [' + ', '.join(
                        [] if c.keys['lean'] == NONE['lean'] else items(c.keys['lean'])) + ']',
                    '        depends: [' + ', '.join(
                        resolve(d, a, cards).key for d in items(c.keys.get('depends', ''))) + ']']
    return '\n'.join(out) + '\n'


def write_graph(areas: dict[str, str], cards: dict[str, Card]) -> str:
    out = ['// Written by scripts/roadmap_status.py from the cards. Do not edit.',
           'digraph roadmap {', '  rankdir=LR;', '  node [shape=box, fontsize=10];']
    for a in sorted(areas):
        out += [f'  subgraph "cluster_{a}" {{', f'    label={yq(areas[a])};']
        for c in sorted((c for c in cards.values() if c.area == a), key=lambda c: c.id):
            out.append(f'    {yq(c.key)} [label={yq(c.id + " " + c.level)}];')
        out.append('  }')
    edges = sorted({(c.key, resolve(d, c.area, cards).key)
                    for c in cards.values() for d in items(c.keys.get('depends', ''))})
    out += [f'  {yq(x)} -> {yq(y)};' for x, y in edges]
    out.append('}')
    return '\n'.join(out) + '\n'


def main(argv: list[str]) -> int:
    if argv[1:] == ['--self-test']:
        return self_test()
    check = argv[1:] == ['--check']
    if argv[1:] and not check:
        print('usage: roadmap_status.py [--check | --self-test]')
        return 2
    errs: list[str] = []
    areas: dict[str, str] = {}
    cards: dict[str, Card] = {}
    index = Index()
    for d in sorted(p for p in ROADMAP.iterdir() if p.is_dir()):
        readme = d / 'README.md'
        first = readme.read_text().split('\n', 1)[0] if readme.is_file() else ''
        if not first.startswith('# '):
            errs.append(f'roadmap/{d.name}: no README.md starting with a # heading')
        areas[d.name] = first[2:].strip() or d.name
        for p in sorted((d / 'cards').glob('*')):
            if p.suffix != '.md' or not p.is_file():
                errs.append(f'roadmap/{d.name}/cards/{p.name}: not a card (.md file)')
                continue
            try:
                c = Card(d.name, p)
            except ValueError as e:
                errs.append(f'roadmap/{d.name}/cards/{p.name}: {e}')
                continue
            es = check_card(c, index)
            errs += [f'{c.key}: {e}' for e in es]
            if not es:
                cards[c.key] = c
    errs += levels(cards)
    if errs:
        for e in errs:
            print(e)
        print(f'roadmap problems: {len(errs)}')
        return 1
    outputs = {'STATUS.md': write_status(areas, cards), 'status.yaml': write_yaml(areas, cards),
               'graph.dot': write_graph(areas, cards)}
    if check:
        stale = [n for n, t in outputs.items()
                 if not (ROADMAP / n).is_file() or (ROADMAP / n).read_text() != t]
        for n in stale:
            print(f'roadmap/{n} is stale: run python3 scripts/roadmap_status.py')
        if not stale:
            print(f'roadmap: {len(areas)} areas, {len(cards)} cards, up to date')
        return 1 if stale else 0
    for n, t in outputs.items():
        (ROADMAP / n).write_text(t)
    dot = pathlib.Path('/usr/bin/dot')
    if dot.is_file():
        subprocess.run([str(dot), '-Tsvg', str(ROADMAP / 'graph.dot'), '-o',
                        str(ROADMAP / 'graph.svg')], check=True, timeout=60)
    else:
        print('no /usr/bin/dot: roadmap/graph.svg not written')
    print(f'roadmap: {len(areas)} areas, {len(cards)} cards written')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
