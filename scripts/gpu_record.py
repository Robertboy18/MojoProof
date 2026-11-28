#!/usr/bin/env python3
"""gpu_record.py: the one check of a GPU run record of a corpus kernel (tests/gpu/<name>/record.txt
with a `kernel:` line), which scripts/roadmap_status.py (a card's GPU run evidence) and
scripts/roadmap_llvm.py (the records it counts) both use.

`problem(text, root, corpus)` says why a record is not that of a GPU run that agrees, or None. A
record that agrees:

* starts with a line that starts with `GPU run record:`;
* has a `kernel:` line naming a file under tests/corpus/ of the repository at `root` (with
  `corpus`, one of those files) and a `kernel sha256:` line with that file's sha256;
* names a kernel of the validator's table `KERNELS`, which binds each corpus file a record may
  name, independently of any record, to its comparator (the name `MojoProofTest/Gpu.lean`'s
  `main` runs it by, `Kernels.<name>.prog` or `naiveSm80.prog`), its dump file, its launch's
  columns and the length in words of its output buffer at a launch (`<expr>`: the allocation of
  the run's program, tests/gpu/<dir>/*.mojo);
* has a `result:` line that starts with `agree`;
* has a `dump:` line naming the table's dump with that file's sha256, a `compare:` command
  (`lake env lean --run tests/gpu/Compare.lean` or `.lake/build/bin/mojoproof_test gpu`) of the
  table's comparator on that dump, and the line the comparator prints first, `evaluator: program
  <name>: corpus file sha256 <sha>`, with the table's comparator and the kernel file's sha256
  (the digest of the program the comparator ran);
* states on its `launches:` line the table's columns, the names before its first comma, the last
  `words`, and the table's word count: `where words = <expr> is the length` (`words_rule`);
* has at least one `launch:` line, each with a number per column, and the words of each are
  positive and are the table's `<expr>` at that launch's numbers (`launch_problem`);
* has, for each launch in order, an `evaluator:` line that names the launch's numbers but the
  words (`n N grid G block B` for a 1-D launch, `m M n N k K grid GX GY block BX BY` for a 2-D
  one) and says `W words agree`, W the launch's words; an `evaluator: L launches, 0 differ` line
  with L the number of launches; and a `compare:` command whose last argument is L;
* its launches are the dump's, in order: each `case` line of the dump starts with the launch's
  numbers, words included, and the dump's output buffer of that case (`out` or `c`) holds that
  many words (`dump_problem`).

So the output's extent comes from the launch and the table's rule, and is the extent of the dump's
output buffer; no count of the record's own sets it. The inputs and the other lines are not read:
the record is what the run printed, and the check is that it says the table's comparator compared,
on the table's dump, for every launch, as many words as the kernel's output is long, and that
they agreed. A record of one instruction (no `kernel:` line: tests/gpu/mma/, ldmatrix/,
cp-async/) is no record of a corpus kernel; scripts/roadmap_llvm.py reads those apart.

With --self-test, exits 1 unless the table's comparators, kernel files and dumps exist, the records
of tests/gpu/ that have a `kernel:` line pass, and the changed records of `self_test` fail. Python
3 standard library only.
"""
import ast
import hashlib
import pathlib
import re
import sys

HEADER = 'GPU run record:'

# The validator's table: for each corpus file a record may name, its comparator (an arm of
# `MojoProofTest/Gpu.lean`'s `main`), its dump, its launch's columns, the output's length in words
# at a launch (the buffer the run's program allocates for it) and the dump's tag of that buffer.
KERNELS: dict[str, tuple[str, str, str, str, str]] = {
    'tests/corpus/vadd/vadd_vector_addition_vector_addition6A6A_793e5fe36a195e73.nvptx.ll':
        ('vadd', 'tests/gpu/vadd/dump.txt', 'n grid block words', 'n + 64', 'out'),
    'tests/corpus/vmul/vector_multiply_vector_multiply_vector_multiply6A6A_227fc544da3deaff'
    '.nvptx.ll':
        ('vmul', 'tests/gpu/vmul/dump.txt', 'n grid block words', 'n + 64', 'out'),
    'tests/corpus/vsub/vector_subtraction_vector_subtraction_vector_subtr6A6A_a0b4d9d2b6e652e1'
    '.nvptx.ll':
        ('vsub', 'tests/gpu/vsub/dump.txt', 'n grid block words', 'n + 64', 'out'),
    'tests/corpus/mgemm_sm80/test_multistage_gemm_kernel_matmul_kernel_naive_float32_float32_'
    'float32_True_16_343aedc5.nvptx.ll':
        ('naive', 'tests/gpu/naive/dump.txt', 'm n k gx gy bx by words', 'm * 50257', 'c'),
}
COMPARE = re.compile(r'^compare: (?:lake env lean --run tests/gpu/Compare\.lean|'
                     r'\.lake/build/bin/mojoproof_test gpu) (\S+) (\S+) (\d+)$', re.M)
LAUNCH = re.compile(r'^launch: (\d+(?: \d+)*)$', re.M)
EVAL_HEAD = r'n \d+ grid \d+ block \d+|m \d+ n \d+ k \d+ grid \d+ \d+ block \d+ \d+'


def fields(text: str) -> dict[str, str]:
    """The `key: value` lines of a record (a key of lowercase letters, digits and spaces at the
    start of a line), the last value of each key."""
    return dict(re.findall(r'^([a-z][a-z0-9 ]*): (.*)$', text, re.M))


def rule(cols: list[str], src: str) -> tuple[list[str], ast.Expression] | None:
    """The columns `cols` and the expression `src`, parsed; None if the last column is not
    `words`, a column repeats, or the expression is anything but whole numbers and the other
    columns' names under `+`, `-`, `*` and parentheses."""
    if not cols or cols[-1] != 'words' or len(set(cols)) != len(cols):
        return None
    try:
        expr = ast.parse(src, mode='eval')
    except SyntaxError:
        return None
    ok = (ast.Expression, ast.BinOp, ast.Add, ast.Sub, ast.Mult, ast.Constant, ast.Name, ast.Load)
    for node in ast.walk(expr):
        if not isinstance(node, ok) \
                or isinstance(node, ast.Constant) and type(node.value) is not int \
                or isinstance(node, ast.Name) and node.id not in cols[:-1]:
            return None
    return cols, expr


def words_rule(text: str) -> tuple[list[str], ast.Expression] | None:
    """The columns of the record's `launches:` line (the names before its first comma, the last
    `words`) and the expression after its `where words = ` up to ` is the length`, parsed (`rule`);
    None if there is no such line or `rule` refuses them."""
    line = fields(text).get('launches', '')
    m = re.search(r'where words = (.+?) is the length', line)
    return rule(line.split(',', 1)[0].split(), m.group(1)) if m else None


def value(node: ast.AST, env: dict[str, int]) -> int:
    """The value of an expression `words_rule` accepted, the columns' names at `env`."""
    if isinstance(node, ast.Expression):
        return value(node.body, env)
    if isinstance(node, ast.Constant):
        return node.value
    if isinstance(node, ast.Name):
        return env[node.id]
    a, b = value(node.left, env), value(node.right, env)
    if isinstance(node.op, ast.Add):
        return a + b
    return a - b if isinstance(node.op, ast.Sub) else a * b


def launch_problem(text: str) -> str | None:
    """Why the record's launch, evaluator and compare lines are not those of a run that compared,
    on each launch, as many words as the table's rule (`KERNELS`) says the output of the record's
    kernel has, all agreeing; or None (the module docstring's launch points)."""
    entry = KERNELS.get(fields(text).get('kernel', ''))
    if entry is None:
        return 'names no kernel of the validator\'s table'
    stated = words_rule(text)
    if stated is None:
        return ('states no word count on its launches: line (columns ending in words, then '
                '`where words = <expr> is the length`)')
    table = rule(entry[2].split(), entry[3])
    assert table is not None, entry
    cols, expr = table
    if stated[0] != cols or ast.dump(stated[1]) != ast.dump(expr):
        return (f'states the launches {" ".join(stated[0])} and words = '
                f'{ast.unparse(stated[1])}, not the table\'s {entry[2]} and words = {entry[3]}')
    launches = [line.split() for line in LAUNCH.findall(text)]
    if not launches:
        return 'records no launch (no launch: line)'
    evals = [(re.findall(r'\d+', e[1]), e[2])
             for e in re.finditer(rf'^evaluator: ({EVAL_HEAD}): (.*)$', text, re.M)]
    if len(evals) != len(launches):
        return f'has {len(launches)} launch: lines and {len(evals)} per-launch evaluator: lines'
    for lt, (et, said) in zip(launches, evals):
        if len(lt) != len(cols):
            return f'has the launch {" ".join(lt)}, not one number per column ({" ".join(cols)})'
        words = int(lt[-1])
        want = value(expr, dict(zip(cols[:-1], map(int, lt[:-1]))))
        if words <= 0:
            return f'has the launch {" ".join(lt)}, which compares no word'
        if words != want:
            return f'has the launch {" ".join(lt)}, whose words are not {want} (the table\'s rule)'
        if lt[:-1] != et or said != f'{words} words agree':
            return (f'has no evaluator: line saying the {words} words of the launch '
                    f'{" ".join(lt)} agree')
    n = len(launches)
    if re.findall(r'^evaluator: (\d+) launches, (\d+) differ$', text, re.M) != [(str(n), '0')]:
        return f'has no evaluator: line `{n} launches, 0 differ`'
    if re.findall(r'^compare: .* (\d+)$', text, re.M) != [str(n)]:
        return f'has no compare: command over its {n} launches'
    return None


def dump_cases(dump: str, tag: str) -> list[tuple[list[int], int]]:
    """The launches of a dump (tests/gpu/Compare.lean's format): for each `case` line its numbers
    and the number of words of its output buffer, the line tagged `tag` after it (a token `v*k`
    is `k` words)."""
    cases: list[tuple[list[int], int]] = []
    for line in dump.split('\n'):
        key, _, rest = line.partition(' ')
        if key == 'case':
            cases.append(([int(x) for x in rest.split()], -1))
        elif key == tag and cases and cases[-1][1] < 0:
            cases[-1] = (cases[-1][0], sum(int(w.partition('*')[2] or 1) for w in rest.split()))
    return cases


def dump_problem(text: str, root: pathlib.Path) -> str | None:
    """Why the record's dump, compare and evaluator-program lines are not the table's comparator
    run on the table's dump of the record's kernel, or the record's launches not the dump's (their
    numbers and the length of the dump's output buffer); or None."""
    keys = fields(text)
    kern = keys.get('kernel', '')
    entry = KERNELS.get(kern)
    if entry is None:
        return f'names {kern}, which the validator\'s table binds to no comparator'
    name, dump, _, _, tag = entry
    if not (root / dump).is_file():
        return f'has no dump file {dump}'
    data = (root / dump).read_bytes()
    m = re.match(r'(\S+), sha256 ([0-9a-f]{64})\b', keys.get('dump', ''))
    if not m or m.groups() != (dump, hashlib.sha256(data).hexdigest()):
        return f'has no dump: line naming {dump} with its sha256'
    if [c[:2] for c in COMPARE.findall(text)] != [(name, dump)]:
        return f'has no compare: command of the comparator {name} on {dump}'
    sha = hashlib.sha256((root / kern).read_bytes()).hexdigest()
    if f'\nevaluator: program {name}: corpus file sha256 {sha}\n' not in text:
        return f'has no evaluator: line saying the comparator {name} ran the program of {kern}'
    launches = [[int(x) for x in line.split()] for line in LAUNCH.findall(text)]
    cases = dump_cases(data.decode(), tag)
    if len(cases) != len(launches):
        return f'has {len(launches)} launches and its dump {len(cases)}'
    for lt, (nums, words) in zip(launches, cases):
        if nums[:len(lt)] != lt or words != lt[-1]:
            return (f'has the launch {" ".join(map(str, lt))}, not the dump\'s case '
                    f'{" ".join(map(str, nums))} with its {words} output words')
    return None


def problem(text: str, root: pathlib.Path, corpus: set[str] | None = None) -> str | None:
    """Why `text` is not the record of a GPU run of a corpus kernel that agrees (the module
    docstring), or None. `root` is the repository; with `corpus`, the kernel must be one of those
    files (relative to `root`)."""
    if not text.split('\n')[0].startswith(HEADER):
        return f'is no GPU run record (its first line does not start with {HEADER})'
    keys = fields(text)
    kern = keys.get('kernel', '')
    if not kern.startswith('tests/corpus/') or '..' in kern or not (root / kern).is_file():
        return 'names no file under tests/corpus on its kernel: line'
    if corpus is not None and kern not in corpus:
        return f'ran {kern}, none of the card\'s corpus files'
    if keys.get('kernel sha256', '') != hashlib.sha256((root / kern).read_bytes()).hexdigest():
        return f'has no kernel sha256: line with the sha256 of {kern}'
    if not keys.get('result', '').startswith('agree'):
        return 'records no agreement (its result: line does not start with agree)'
    return launch_problem(text) or dump_problem(text, root)


def self_test(root: pathlib.Path) -> list[str]:
    """What the check gets wrong, [] if nothing: each comparator of the table is an arm of
    `MojoProofTest/Gpu.lean`'s `main` and its kernel file and dump exist; every record of
    tests/gpu/ with a `kernel:` line passes; changed from tests/gpu/vadd/record.txt, a record
    whose kernel and kernel sha256 are vmul's (the dump, comparator and evaluator digest still
    vadd's), one whose dump: line is also vmul's, one whose compare command is also vmul's (the
    evaluator's program line still vadd's), a self-consistent record of one
    launch of one word (`launch: 1 1 1 1`, `where words = 1`, `1 words agree`, one launch counted),
    one whose launches are not the dump's (its last launch dropped and the counts kept
    consistent), one with another launch than the dump's (`launch: 38 3 16 102` for its second,
    and its evaluator line), a record whose first line is not the header, a
    three-line record (its header, the kernel and an agreeing result), one whose kernel sha256 is
    changed, one whose first launch compares no word (`launch: 1 1 1 0` and `0 words agree`), one
    whose first launch compares one word more than the n + 64 its launches: line states (and says
    those agree), one whose launches: line states no word count, one with a launch that differs,
    one whose evaluator misses a launch, and one whose compare command counts another number of
    launches fail; from tests/gpu/naive/record.txt, the 2-D record, one whose first launch's words
    are not m * 50257 fails."""
    bad = []
    gpu = (root / 'MojoProofTest/Gpu.lean').read_text()
    for kern, (name, dump, _, _, _) in KERNELS.items():
        if f'| "{name}" =>' not in gpu:
            bad.append(f'the comparator {name} is no arm of MojoProofTest/Gpu.lean\'s main')
        if not (root / kern).is_file() or not (root / dump).is_file():
            bad.append(f'the table row of {kern} names a missing file')
    recs = {p: p.read_text() for p in sorted((root / 'tests' / 'gpu').glob('*/record.txt'))}
    kernels = {p: t for p, t in recs.items() if 'kernel' in fields(t)}
    if len(kernels) < 2:
        bad.append(f'only {len(kernels)} records of corpus kernels under tests/gpu')
    for p, t in kernels.items():
        if (why := problem(t, root)) is not None:
            bad.append(f'{p.relative_to(root)} fails ({why})')
    rec = (root / 'tests/gpu/vadd/record.txt').read_text()
    va = fields(rec)['kernel']
    one = 'n 1 grid 1 block 1: '
    vm = fields((root / 'tests/gpu/vmul/record.txt').read_text())
    vmul = rec.replace(va, vm['kernel']).replace(fields(rec)['kernel sha256'], vm['kernel sha256'])
    vm_dump = vmul.replace(fields(rec)['dump'], vm['dump'])
    vm_cmp = vm_dump.replace('Compare.lean vadd tests/gpu/vadd/',
                             'Compare.lean vmul tests/gpu/vmul/')
    word = re.sub(r'^launch: (?!1 1 1 65$).*\n', '', rec, flags=re.M)
    word = re.sub(r'^evaluator: n (?!1 grid 1 block 1:).*\n', '', word, flags=re.M)
    word = word.replace('words = n + 64 is', 'words = 1 is').replace('1 1 1 65', '1 1 1 1') \
        .replace(one + '65 words agree', one + '1 words agree') \
        .replace('6 launches, 0 differ', '1 launches, 0 differ')
    word = re.sub(r'^(compare: .*) 6$', r'\1 1', word, flags=re.M)
    short = re.sub(r'^launch: 1100 2 1024 1164\n', '', rec, flags=re.M)
    short = re.sub(r'^evaluator: n 1100 .*\n', '', short, flags=re.M) \
        .replace('6 launches, 0 differ', '5 launches, 0 differ')
    short = re.sub(r'^(compare: .*) 6$', r'\1 5', short, flags=re.M)
    cases = {
        'relabeled': vmul,
        'relabeled with the dump': vm_dump,
        'relabeled with the dump and comparator': vm_cmp,
        'one-word': word,
        'not the dump\'s launches': short,
        'another launch': rec.replace('launch: 37 3 16 101', 'launch: 38 3 16 102')
                             .replace('n 37 grid 3 block 16: 101', 'n 38 grid 3 block 16: 102'),
        'headerless': rec.replace(HEADER, 'GPU run:', 1),
        'three-line': f'{HEADER} a conformance test, not a proof.\nkernel: {va}\nresult: agree\n',
        'changed sha': rec.replace(fields(rec)['kernel sha256'], '8e4779ad' + '0' * 56),
        'zero-word': rec.replace('launch: 1 1 1 65', 'launch: 1 1 1 0')
                        .replace(one + '65 words agree', one + '0 words agree'),
        'one word more': rec.replace('launch: 1 1 1 65', 'launch: 1 1 1 66')
                            .replace(one + '65 words agree', one + '66 words agree'),
        'no word count': rec.replace('where words = n + 64 is the length',
                                     'where words is the length'),
        'differing': rec.replace('launches, 0 differ', 'launches, 1 differ'),
        'evaluator short': rec.replace(f'evaluator: {one}65 words agree\n', ''),
        'compare count': re.sub(r'^(compare: .*) 6$', r'\1 5', rec, flags=re.M),
    }
    nv = (root / 'tests/gpu/naive/record.txt').read_text()
    cases['naive words'] = nv.replace('launch: 1 1 1 1 1 16 16 50257',
                                      'launch: 1 1 1 1 1 16 16 50258') \
        .replace('block 16 16: 50257 words agree', 'block 16 16: 50258 words agree', 1)
    for n, t in cases.items():
        if t == rec or t == nv:
            bad.append(f'the {n} case changes nothing')
        elif problem(t, root) is None:
            bad.append(f'the {n} record passes')
    return bad


def main(argv: list[str]) -> int:
    if argv[1:] != ['--self-test']:
        print(__doc__)
        return 2
    bad = self_test(pathlib.Path(__file__).resolve().parent.parent)
    for b in bad:
        print(f'self-test: {b}')
    print('self-test: ' + ('failed' if bad else 'the table and the records pass; the relabeled, '
                           'relabeled-with-the-dump, relabeled-with-the-comparator, one-word, '
                           'not-the-dump\'s, another-launch, headerless, three-line, re-hashed, '
                           'zero-word, one-word-more, uncounted, differing, short and miscounted '
                           'records fail'))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
