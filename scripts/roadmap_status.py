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
  index is scripts/cited.py's `scan` over MojoProof/ and MojoProofTest/, plus the names the
  command `mojo_kernel n := ...` adds that `scan` does not list (`n.covers`, `n.correct`, ...;
  below, `generated`), plus, for a name whose first component is another package's root
  (`FloatLib`, `TorchLean`), `scan` over that package's sources under .lake/packages. No Lean
  runs;
* every name in tests is a declaration or a module MojoProofTest.<M> with a file
  MojoProofTest/<M>.lean;
* every corpus entry is a path or a glob under tests/corpus/ that matches at least one file
  (the status counts the `.ll` files, the kernels);
* every depends entry is a card id, `<id>` in the card's area or else the one card of that id,
  or `<area>/<id>`;
* evidence is `L<k>: item, item; L<m>: ...`, each level once, at most the kind's top level;
  an item is a declaration name (as for lean), except that a GPU run level's items (kernel L1,
  construct L2) are files of this repository (the record of the run), and construct L3's
  items are kernel card ids whose card has L2 evidence;
* level is the computed level: the highest level whose evidence, and that of every level below
  it, is present (L0 is the card itself; construct L1's evidence is its lean names);
* a kernel's L2 evidence states `Kernel.Sound`.

For a kernel's L2 to L4 evidence it also reads what the cited theorems' premises restrict, from
the theorem's statement and the section variables it takes (those it `include`s or names), in
its source, or for a name a `mojo_kernel` command adds, from the command's statement template
in MojoProof/Sym/KernelCmd.lean: the launches (`L.Valid`, and a grid or block of side 1 in `y`
and `z`, `grid .y = 1`, is a one-dimensional launch), and above L2 whether an output is assumed
finite (`isFinite = true →`) and whether its real value is the exact one rounded (`roundAt`).
This reads text, not Lean: another premise on the launch's shape is reported as such, without
its meaning.

It writes roadmap/STATUS.md (a table per area: each card's level, the evidence present above
it, the scope of the theorems it cites, and what the next level needs), roadmap/status.yaml
(the same as data), roadmap/graph.dot (the areas as clusters, the cards, and an edge from each
card to each card it depends on) and
roadmap/graph.svg (`/usr/bin/dot -Tsvg` on graph.dot, skipped if dot is missing). The output is
sorted and has no timestamps, so it is the same for the same cards and code.

With --check it writes nothing, and exits 1 if a check fails or if STATUS.md, status.yaml or
graph.dot differ from what it would write (graph.svg is not compared). Without it, it exits 1,
writing nothing, if a check fails. Python 3 standard library only.
"""
import glob
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
import cited  # noqa: E402  (the declaration index: `scan`)

ROADMAP = ROOT / 'roadmap'
REQUIRED = ('id', 'title', 'kind', 'ref', 'quote', 'lean', 'corpus', 'tests', 'upstream', 'level')
OPTIONAL = ('depends', 'evidence')
NONE = {'lean': 'not stated yet', 'corpus': 'none', 'tests': 'none'}

# The ladders: (level, meaning, the evidence the script accepts).
LADDER = {
    'kernel': [
        ('L0', 'card written', 'the card, with every check passing'),
        ('L1', 'imported, and the evaluator agrees with a GPU run: a conformance test of the '
         'evaluator against the GPU on the recorded inputs, not a proof',
         'a tracked record of a GPU run of the corpus kernel (a file of this repository)'),
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
         'a tracked record of a GPU run of a test of the construct (a file of this repository)'),
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

# Names `mojo_kernel n := ...` adds (MojoProof/Sym/KernelCmd.lean), by the clause that adds them.
GENERATED = {
    None: ('paths', 'covers', 'sound_of', 'args', 'starts', 'sound'),
    'map2': ('argTy', 'argTail', 'ret', 'correct'),
    'loop': ('chains', 'coversChains', 'entry', 'init', 'step', 'exit', 'loop'),
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
    text = cited.COMMENT.sub(lambda m: re.sub(r'[^\n]', ' ', m.group(0)), text)
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


def scope(level: str, text: str | None) -> str:
    """What a cited theorem's premises restrict: for L2 the launches, above it also whether a
    finite output is assumed and whether the real value is the exact one rounded."""
    if text is None:
        return 'premises not read'
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
    return ', '.join(qs)


class Index:
    """The declaration index: MojoProof/ and MojoProofTest/, and other packages on demand."""

    def __init__(self):
        self.decls: set[str] = set()
        self.generated: set[str] = set()   # the names mojo_kernel commands add
        self.kernels: set[str] = set()     # their kernels' full names, for `n.b<i>`
        self.statements: dict[str, str] = {}   # theorem name: its statement with premises
        self.templates: dict[str, str] = {}    # generated suffix: the command's statement text
        for d in ('MojoProof', 'MojoProofTest'):
            for p in sorted((ROOT / d).rglob('*.lean')):
                self.add_file(p.read_text())
        cmd = (ROOT / 'MojoProof' / 'Sym' / 'KernelCmd.lean').read_text()
        for m in TEMPLATE.finditer(cmd):
            self.templates.setdefault(m.group(1), cmd[m.start():].split(':=', 1)[0])
        self.packages: dict[str, set[str]] = {}

    def add_file(self, text: str) -> None:
        decls = cited.scan(text)[0]
        self.decls |= decls
        self.statements.update(premises_of(text))
        lines = text.split('\n')
        prev = ''
        for i, line in enumerate(lines):
            m = KERNEL.match(line)
            if m and prev.strip() != '#guard_msgs in':
                n = m.group(1)
                bases = [d[:-len('.sound_of')] for d in decls
                         if d == f'{n}.sound_of' or d.endswith(f'.{n}.sound_of')]
                body = []
                for cont in lines[i:]:
                    if not cont.strip():
                        break
                    body.append(cont)
                words = set(re.findall(r'\b(map2|loop)\b', '\n'.join(body)))
                for base in bases:
                    self.kernels.add(base)
                    for clause, names in GENERATED.items():
                        if clause is None or clause in words:
                            self.generated |= {f'{base}.{s}' for s in names}
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
        if root in ('MojoProof', 'MojoProofTest'):
            return False
        pkg = self.package(root)
        return pkg is not None and name in pkg


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
        elif not (k['kind'] == 'construct' and lv == 'L3'):
            for n in its:
                if not index.has(n):
                    errs.append(f'{lv} evidence {n} is no declaration')
            if k['kind'] == 'kernel':
                c.scopes[lv] = '; '.join(dict.fromkeys(scope(lv, index.statement(n))
                                                       for n in its))
                if lv == 'L2':
                    for n in its:
                        st = index.statement(n)
                        if index.has(n) and st is not None and 'Kernel.Sound' not in st:
                            errs.append(f'L2 evidence {n} does not state Kernel.Sound')
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
    check = argv[1:] == ['--check']
    if argv[1:] and not check:
        print('usage: roadmap_status.py [--check]')
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
