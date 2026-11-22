#!/usr/bin/env python3
"""roadmap_llvm.py: write the LLVM IR area of the roadmap (roadmap/llvm-ir/) from the code.

The cards are generated, not written by hand. The inputs are:

* the importer's tables: the opcode maps and the `inst` and `terminator` cases of
  MojoProof/LLVM/Parser.lean (with its explicit refusals, `fail "unsupported instruction ..."`),
  the constructors of `Inst` and `Term` in MojoProof/LLVM/Syntax.lean, and the intrinsic
  families of MojoProof/LLVM/Intrinsic.lean with the LLVM names `Intrinsic.name` generates;
* the block checker's rule table, the `mojo_rule` attributes and `mojo_refuse` commands of
  MojoProof/Sym/Rules.lean;
* tests/corpus/REFUSALS.tsv, the corpus files the importer refuses and why;
* the table MojoProofTest/Modelled.lean pins (`#guard_msgs`): for each opcode keyword and intrinsic
  family, what the grid evaluator does with a small kernel of it (`returns`, or the fault);
* a token scan of the corpus `.ll` files: the opcode of every instruction line and the callee of
  every call of an `llvm.` intrinsic;
* the records of GPU runs, tests/gpu/<kernel>/record.txt: each names the corpus file of the
  kernel it ran (its `kernel:` line, with the file's sha256 on its `kernel sha256:` line) and
  says whether the evaluator agreed with the GPU (its `result:` line).

It writes one card per opcode the corpus uses, one per intrinsic family the corpus calls, and
one per construct the importer refuses (each distinct reason of REFUSALS.tsv, and each explicit
refusal of the parser), and the area's README.md.

An opcode or family card is L1 only if the semantics runs the construct: its row of
MojoProofTest/Modelled.lean's table says `returns`, that is, the grid evaluator ran a kernel of the
construct (one block of one thread, a straight-line body) until every thread returned. Any other
row (the run stops with `unsupported`, or with another fault, or does not start) makes the card
L0, "parsed, not modelled": its `lean` is `not stated yet` and its body names the importer's
declarations and the row. The table is computed by the semantics, not written by hand: the
module's build fails unless the evaluator's output is the pinned table, so the table changes with
the semantics; a construct with no row is an error here. A `returns` row is a positive witness
for the form the test kernel runs; an incidental fault of a test kernel can only make a card L0,
never L1. An L1 card is L2 when a record of a GPU run whose result is agreement ran a corpus
kernel whose IR uses the construct (the token scan of that kernel's file, not a list): the card's
`evidence: L2:` lists those records. Such a record is a conformance test, not a proof: the
evaluator and the GPU gave the same output buffer, bit for bit, on the launches it lists. A record
whose kernel file's sha256 is not the one it states is an error here. A card's `lean` lists only
names that the
declaration index of scripts/cited.py (`scan` over MojoProof/ and MojoProofTest/) contains, so
each is a declaration on this tree; the constructors (`Inst.bin`, `BinOp.add`), which that index
does not list, are named in the card's body. A card's quote is the first sentence of the cited
section, from the LLVM Language Reference or the PTX ISA in the versions docs/TRUST.md records
(T7); QUOTES below holds them, and --verify-quotes checks each against local copies.

Usage:
  python3 scripts/roadmap_llvm.py                  write roadmap/llvm-ir/
  python3 scripts/roadmap_llvm.py --check          write nothing; exit 1 if roadmap/llvm-ir/
                                                   differs from what it would write
  python3 scripts/roadmap_llvm.py --verify-quotes LANGREF.html PTX.html
                                                   exit 1 unless every quote is in the text of
                                                   the given LangRef or PTX ISA copy

The output is sorted and has no timestamps. Python 3 standard library only.
"""
import hashlib
import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
import cited  # noqa: E402  (the declaration index: `scan`)

AREA = ROOT / 'roadmap' / 'llvm-ir'
CORPUS = ROOT / 'tests' / 'corpus'
GPU = ROOT / 'tests' / 'gpu'
LANGREF = 'LLVM LangRef 24.0.0git'
PTX = 'PTX ISA 9.5'
SHOWN = 5   # corpus paths listed in a card's front matter
MODELLED = 'MojoProofTest/Modelled.lean'

# The first sentence of each cited section (LangRef 24.0.0git and PTX ISA 9.5, docs/TRUST.md T7).
QUOTES = {
    'add-instruction': 'The ‘add’ instruction returns the sum of its two operands.',
    'sub-instruction': 'The ‘sub’ instruction returns the difference of its two operands.',
    'mul-instruction': 'The ‘mul’ instruction returns the product of its two operands.',
    'udiv-instruction': 'The ‘udiv’ instruction returns the quotient of its two operands.',
    'sdiv-instruction': 'The ‘sdiv’ instruction returns the quotient of its two operands.',
    'urem-instruction': 'The ‘urem’ instruction returns the remainder from the unsigned division '
                        'of its two arguments.',
    'srem-instruction': 'The ‘srem’ instruction returns the remainder from the signed division of '
                        'its two operands.',
    'shl-instruction': 'The ‘shl’ instruction returns the first operand shifted to the left a '
                       'specified number of bits.',
    'lshr-instruction': 'The ‘lshr’ instruction (logical shift right) returns the first operand '
                        'shifted to the right a specified number of bits with zero fill.',
    'ashr-instruction': 'The ‘ashr’ instruction (arithmetic shift right) returns the first operand '
                        'shifted to the right a specified number of bits with sign extension.',
    'and-instruction': 'The ‘and’ instruction returns the bitwise logical and of its two operands.',
    'or-instruction': 'The ‘or’ instruction returns the bitwise logical inclusive or of its two '
                      'operands.',
    'xor-instruction': 'The ‘xor’ instruction returns the bitwise logical exclusive or of its two '
                       'operands.',
    'fadd-instruction': 'The ‘fadd’ instruction returns the sum of its two operands.',
    'fsub-instruction': 'The ‘fsub’ instruction returns the difference of its two operands.',
    'fmul-instruction': 'The ‘fmul’ instruction returns the product of its two operands.',
    'fdiv-instruction': 'The ‘fdiv’ instruction returns the quotient of its two operands.',
    'frem-instruction': 'The ‘frem’ instruction returns the remainder from the division of its two '
                        'operands.',
    'fneg-instruction': 'The ‘fneg’ instruction returns the negation of its operand.',
    'icmp-instruction': 'The ‘icmp’ instruction returns a boolean value or a vector of boolean '
                        'values based on comparison of its two integer, integer vector, pointer, or '
                        'pointer vector operands.',
    'fcmp-instruction': 'The ‘fcmp’ instruction returns a boolean value or vector of boolean values '
                        'based on comparison of its operands.',
    'trunc-to-instruction': 'The ‘trunc’ instruction truncates its operand to the type ty2.',
    'zext-to-instruction': 'The ‘zext’ instruction zero extends its operand to type ty2.',
    'sext-to-instruction': 'The ‘sext’ sign extends value to the type ty2.',
    'fptrunc-to-instruction': 'The ‘fptrunc’ instruction truncates value to type ty2.',
    'fpext-to-instruction': 'The ‘fpext’ extends a floating-point value to a larger floating-point '
                            'value.',
    'fptoui-to-instruction': 'The ‘fptoui’ converts a floating-point value to its unsigned integer '
                             'equivalent of type ty2.',
    'fptosi-to-instruction': 'The ‘fptosi’ instruction converts floating-point value to type ty2.',
    'uitofp-to-instruction': 'The ‘uitofp’ instruction regards value as an unsigned integer and '
                             'converts that value to the ty2 type.',
    'sitofp-to-instruction': 'The ‘sitofp’ instruction regards value as a signed integer and '
                             'converts that value to the ty2 type.',
    'ptrtoint-to-instruction': 'The ‘ptrtoint’ instruction converts the pointer or a vector of '
                               'pointers value to the integer (or vector of integers) type ty2.',
    'inttoptr-to-instruction': 'The ‘inttoptr’ instruction converts an integer value to a pointer '
                               'type, ty2.',
    'bitcast-to-instruction': 'The ‘bitcast’ instruction converts value to type ty2 without '
                              'changing any bits.',
    'addrspacecast-to-instruction': 'The ‘addrspacecast’ instruction converts ptrval from pty in '
                                    'address space n to type pty2 in address space m.',
    'select-instruction': 'The ‘select’ instruction is used to choose one value based on a '
                          'condition, without IR-level branching.',
    'phi-instruction': 'The ‘phi’ instruction is used to implement the φ node in the SSA graph '
                       'representing the function.',
    'alloca-instruction': 'The ‘alloca’ instruction allocates memory on the stack frame of the '
                          'currently executing function, to be automatically released when this '
                          'function returns to its caller.',
    'load-instruction': 'The ‘load’ instruction is used to read from memory.',
    'store-instruction': 'The ‘store’ instruction is used to write to memory.',
    'getelementptr-instruction': 'The ‘getelementptr’ instruction is used to get the address of a '
                                 'subelement of an aggregate data structure.',
    'extractvalue-instruction': 'The ‘extractvalue’ instruction extracts the value of a member '
                                'field from an aggregate value.',
    'insertvalue-instruction': 'The ‘insertvalue’ instruction inserts a value into a member field '
                               'in an aggregate value.',
    'extractelement-instruction': 'The ‘extractelement’ instruction extracts a single scalar '
                                  'element from a vector at a specified index.',
    'insertelement-instruction': 'The ‘insertelement’ instruction inserts a scalar element into a '
                                 'vector at a specified index.',
    'shufflevector-instruction': 'The ‘shufflevector’ instruction constructs a permutation of '
                                 'elements from two input vectors, returning a vector with the same '
                                 'element type as the input and length that is the same as the '
                                 'shuffle mask.',
    'call-instruction': 'The ‘call’ instruction represents a simple function call.',
    'atomicrmw-instruction': 'The ‘atomicrmw’ instruction is used to atomically modify memory.',
    'ret-instruction': 'The ‘ret’ instruction is used to return control flow (and optionally a '
                       'value) from a function back to the caller.',
    'br-instruction': 'The ‘br’ instruction is used to cause control flow to transfer to a '
                      'different basic block in the current function.',
    'switch-instruction': 'The ‘switch’ instruction is used to transfer control flow to one of '
                          'several different places.',
    'unreachable-instruction': 'The ‘unreachable’ instruction has no defined semantics.',
    'llvm-smax-intrinsic': 'Return the larger of %a and %b comparing the values as signed '
                           'integers.',
    'llvm-maxnum-intrinsic': 'The ‘llvm.maxnum.*’ intrinsics return the maximum of the two '
                             'arguments.',
    'llvm-lifetime-start-intrinsic': 'The ‘llvm.lifetime.start’ intrinsic specifies the start of a '
                                     'memory object’s lifetime.',
    'llvm-vector-reduce-and-intrinsic': 'The ‘llvm.vector.reduce.and.*’ intrinsics do a bitwise '
                                        'AND reduction of a vector, returning the result as a '
                                        'scalar.',
    'llvm-vector-extract-intrinsic': 'The ‘llvm.vector.extract.*’ intrinsics extract a vector from '
                                     'within another vector starting from a given index.',
    'llvm-stepvector-intrinsic': 'The ‘llvm.stepvector’ intrinsics are used to create vectors of '
                                 'integers whose elements contain a linear sequence of values '
                                 'starting from 0 with a step of 1.',
    'special-registers-tid': 'Thread identifier within a CTA.',
    'special-registers-laneid': 'Lane Identifier.',
    'parallel-synchronization-and-communication-instructions-bar': 'Barrier synchronization.',
    'data-movement-and-conversion-instructions-shfl-sync':
        'Register data shuffle within threads of a warp.',
    'floating-point-instructions-rsqrt': 'Take the reciprocal of the square root of a value.',
    'parallel-synchronization-and-communication-instructions-griddepcontrol':
        'Control execution of dependent grids.',
    'data-movement-and-conversion-instructions-cp-async-commit-group':
        'Commits all prior initiated but uncommitted cp.async instructions into a cp.async-group.',
    'data-movement-and-conversion-instructions-cp-async-wait-group':
        'cp.async.wait_group, cp.async.wait_all',
    'warp-level-matrix-instructions-ldmatrix':
        'Collectively load one or more matrices from shared memory for mma instruction',
    'warp-level-matrix-instructions-mma': 'Perform matrix multiply-and-accumulate operation',
    'data-movement-and-conversion-instructions-cvt': 'Convert a value from one type to another.',
    'data-movement-and-conversion-instructions-cp-async':
        'Initiates an asynchronous copy operation from one state space to another.',
}
PTX_ANCHORS = {a for a in QUOTES if not a.endswith(('-instruction', '-intrinsic'))}

# The LangRef or PTX section of each intrinsic family, and the semantics' helper for it.
FAMILY_REF = {
    'sreg': 'special-registers-tid', 'laneid': 'special-registers-laneid',
    'barrier': 'parallel-synchronization-and-communication-instructions-bar',
    'shfl': 'data-movement-and-conversion-instructions-shfl-sync',
    'minmax': 'llvm-smax-intrinsic', 'fminmax': 'llvm-maxnum-intrinsic',
    'rsqrtApprox': 'floating-point-instructions-rsqrt',
    'lifetime': 'llvm-lifetime-start-intrinsic',
    'reduceAnd': 'llvm-vector-reduce-and-intrinsic', 'extract': 'llvm-vector-extract-intrinsic',
    'stepvector': 'llvm-stepvector-intrinsic',
    'griddepWait': 'parallel-synchronization-and-communication-instructions-griddepcontrol',
    'griddepLaunch': 'parallel-synchronization-and-communication-instructions-griddepcontrol',
    'cpAsyncCommit': 'data-movement-and-conversion-instructions-cp-async-commit-group',
    'cpAsyncWait': 'data-movement-and-conversion-instructions-cp-async-wait-group',
    'ldmatrix': 'warp-level-matrix-instructions-ldmatrix',
    'mma': 'warp-level-matrix-instructions-mma',
}
FAMILY_HELPERS = {
    'shfl': ['MojoProof.Sem.shflSource'], 'minmax': ['MojoProof.Sem.intMinMax'],
    'rsqrtApprox': ['MojoProof.Sem.rsqrt', 'MojoProof.Sem.rsqrtOk'],
    'lifetime': ['MojoProof.Sem.lifetimeStarted'],
}
# The semantics' helper for an opcode, beyond `MojoProof.Sem.exec`.
OP_HELPERS = {
    'bin': ['MojoProof.Sem.intBin'], 'fbin': ['MojoProof.Sem.floatBin'],
    'icmp': ['MojoProof.LLVM.ICmp.holds'], 'atomicrmw': ['MojoProof.Sem.rmw'],
    'trunc': ['MojoProof.Sem.intCast'], 'zext': ['MojoProof.Sem.intCast'],
    'sext': ['MojoProof.Sem.intCast'], 'fptrunc': ['MojoProof.Sem.floatCast'],
    'fpext': ['MojoProof.Sem.floatCast'], 'sitofp': ['MojoProof.Sem.intToFloat'],
    'uitofp': ['MojoProof.Sem.intToFloat'], 'bitcast': ['MojoProof.Sem.bitcast'],
}
# What a family's card adds about its members.
FAMILY_NOTE = {
    'sreg': 'The family is the special registers `%tid`, `%ntid`, `%ctaid` and `%nctaid` in x, y '
            'and z; the ref is the section on `%tid` (PTX ISA 10.1; `%ntid` 10.2, `%ctaid` 10.6, '
            '`%nctaid` 10.7). ',
    'minmax': 'The family is `llvm.smax`, `llvm.smin`, `llvm.umax` and `llvm.umin`; the ref is the '
              'section on `llvm.smax`. ',
    'fminmax': 'The family is `llvm.maxnum` and `llvm.minnum`; the ref is the section on '
               '`llvm.maxnum`. ',
    'lifetime': 'The family is `llvm.lifetime.start` and `llvm.lifetime.end`; the ref is the '
                'section on `llvm.lifetime.start`. ',
    'griddepWait': 'PTX ISA has one section for `griddepcontrol.wait` and '
                   '`griddepcontrol.launch_dependents`. ',
    'griddepLaunch': 'PTX ISA has one section for `griddepcontrol.wait` and '
                     '`griddepcontrol.launch_dependents`. ',
}
# PTX instructions an inline asm string starts with, and their PTX sections.
ASM_REF = {
    'cvt': 'data-movement-and-conversion-instructions-cvt',
    'cp.async': 'data-movement-and-conversion-instructions-cp-async',
}


def read(rel: str) -> str:
    return (ROOT / rel).read_text()


def index() -> set[str]:
    decls: set[str] = set()
    for d in ('MojoProof', 'MojoProofTest'):
        for p in sorted((ROOT / d).rglob('*.lean')):
            decls |= cited.scan(p.read_text())[0]
    return decls


def modelled() -> dict[str, str]:
    """The table MojoProofTest/Modelled.lean pins: construct (an opcode keyword, or
    `Intrinsic.fam`) to the grid evaluator's outcome (`returns`, or the fault)."""
    m = re.search(r'/--\ninfo: (.*?)\n-/\n#guard_msgs in\n#eval do\n  for \(k, src\) in cases',
                  read(MODELLED), re.S)
    assert m, f'{MODELLED}: no pinned table'
    out = {}
    for line in m.group(1).split('\n'):
        k, outcome = line.split(': ', 1)
        assert k not in out, k
        out[k] = outcome
    return out


def def_body(text: str, header: str) -> str:
    """The text of the definition starting at `header`, up to the next blank line."""
    i = text.index(header)
    j = text.find('\n\n', i)
    return text[i:] if j < 0 else text[i:j]


def string_map(text: str, header: str) -> dict[str, str]:
    """`"key" => some .ctor` pairs of a parser map."""
    return dict(re.findall(r'"([a-z]+)" => some \.(\w+)', def_body(text, header)))


def arms(text: str, header: str) -> dict[str, str]:
    """The `| "op" => ...` arms of a `match op with` in the definition at `header`."""
    body = def_body(text, header)
    parts = re.split(r'\n  \| ', body)
    out = {}
    for p in parts[1:]:
        m = re.match(r'"([a-z]+)" =>(.*)', p, re.S)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def inductive(text: str, name: str) -> list[str]:
    """The constructors of `inductive name`, in order."""
    m = re.search(rf'^inductive {name}\b.*?\n(.*?)(?=\n\S|\n\n)', text, re.S | re.M)
    return re.findall(r'^  \| (\w+)', m.group(1), re.M)


class Op:
    """An opcode of the importer: its keyword, the `Inst` or `Term` constructors it produces and
    the operation constructor (`BinOp.add`), if any."""

    def __init__(self, kw, kind, ctors, opctor=None):
        self.kw, self.kind, self.ctors, self.opctor = kw, kind, ctors, opctor


def importer_ops() -> tuple[dict[str, Op], list[tuple[str, str]]]:
    """The opcodes the parser reads, and its explicit refusals (keyword, message)."""
    p = read('MojoProof/LLVM/Parser.lean')
    syn = read('MojoProof/LLVM/Syntax.lean')
    insts, terms = inductive(syn, 'Inst'), inductive(syn, 'Term')
    ops: dict[str, Op] = {}
    for header, ctor, enum in (('private def binOp?', 'bin', 'BinOp'),
                               ('private def fbinOp?', 'fbin', 'FBinOp'),
                               ('private def castOp?', 'cast', 'CastOp')):
        members = inductive(syn, enum)
        for kw, m in string_map(p, header).items():
            assert ctor in insts and m in members, (kw, ctor, m)
            ops[kw] = Op(kw, 'inst', [ctor], f'{enum}.{m}')
    refusals = []
    for kw, body in arms(p, 'partial def inst (op : String)').items():
        cs = list(dict.fromkeys(re.findall(r'return \.(\w+)', body)))
        assert cs and all(c in insts for c in cs), (kw, cs)
        ops[kw] = Op(kw, 'inst', cs)
        refusals += [(kw, msg) for msg in re.findall(r'fail "(unsupported instruction [^"]*)"', body)]
    for kw, body in arms(p, 'partial def terminator (op : String)').items():
        cs = list(dict.fromkeys(re.findall(r'return \.(\w+)', body)))
        assert cs and all(c in terms for c in cs), (kw, cs)
        ops[kw] = Op(kw, 'term', cs)
    return ops, refusals


def split_template(s: str) -> list[tuple[str, str]]:
    """The literal and `{hole}` parts of the body of an `s!"..."` string."""
    out, i, lit = [], 0, ''
    while i < len(s):
        if s[i] == '{':
            depth, j = 1, i + 1
            while depth:
                depth += {'{': 1, '}': -1}.get(s[j], 0)
                j += 1
            if lit:
                out.append(('lit', lit))
                lit = ''
            out.append(('hole', s[i + 1:j - 1]))
            i = j
        else:
            lit += s[i]
            i += 1
    if lit:
        out.append(('lit', lit))
    return out


def template_end(s: str, i: int) -> int:
    """The index of the closing quote of the string literal whose body starts at `i`."""
    depth = 0
    while True:
        c = s[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
        elif c == '"' and depth == 0:
            return i
        elif c == '"':
            i = s.index('"', i + 1)
        i += 1


def families() -> dict[str, re.Pattern]:
    """The intrinsic families and a pattern for the LLVM names `Intrinsic.name` gives them."""
    t = read('MojoProof/LLVM/Intrinsic.lean')
    names = {}
    for f, body in re.findall(r'private def (\w+Name) : \w+ →\n(.*?)\n\n', t, re.S):
        names[f] = re.findall(r'"([a-z]+)"', body)
    body = def_body(t, 'def name : Intrinsic → Option String')
    fams = inductive(t, 'Intrinsic')
    out = {}
    for line in re.split(r'\n  \| \.', body)[1:]:
        fam = re.match(r'(\w+)', line).group(1)
        assert fam in fams, fam
        k = line.index('"')
        end = template_end(line, k + 1)
        regex = ''
        for kind, part in split_template(line[k + 1:end]):
            if kind == 'lit':
                regex += re.escape(part)
            elif alts := re.findall(r'"([^"]*)"', part):
                regex += '(?:' + '|'.join(re.escape(a) for a in alts) + ')'
            elif (g := part.split()[0]) in names:
                regex += '(?:' + '|'.join(re.escape(a) for a in names[g]) + ')'
            else:
                regex += r'[a-z0-9]+'
        if '++ ·' in line[end:]:
            regex += r'[a-z0-9.]+'
        out[fam] = re.compile(regex + '$')
    return out


def rule_table() -> dict[str, list[str]]:
    """For each constructor (`Inst.bin`), the rule table's entries, as `#mojo_rules` prints them:
    the rules (`Sym.exec_bin (case)`), then the refusals (`refused (case): reason`)."""
    t = read('MojoProof/Sym/Rules.lean')
    t = re.sub(r'\\\n\s*', '', t)   # string gaps
    rules: dict[str, list[str]] = {}
    refused: dict[str, list[str]] = {}
    for cs, case, lemma in re.findall(
            r'attribute \[mojo_rule((?:\s+[A-Z]\w*\.\w+)+)(?:\s+"([^"]*)")?\]\s+([\w.]+)', t):
        for c in cs.split():
            rules.setdefault(c, []).append((lemma, case))
    for cs, case, reason in re.findall(
            r'mojo_refuse((?:\s+[A-Z]\w*\.\w+)+)(?:\s+"([^"]*)")?\s*:\s*"([^"]*)"', t):
        for c in cs.split():
            refused.setdefault(c, []).append((case, reason))
    out = {}
    for c in sorted(set(rules) | set(refused)):
        es = [f'`Sym.{lm}`' + (f' ({cs})' if cs else '') for lm, cs in rules.get(c, [])]
        es += ['refused' + (f' ({cs})' if cs else '') + f': {r}' for cs, r in refused.get(c, [])]
        out[c] = es
    out['_lemmas'] = sorted({lm for v in rules.values() for lm, _ in v})
    return out


def kernel_files() -> set[str]:
    """The corpus files of the programs a `mojo_kernel` theorem of the library is about: each
    program's name is bound to a corpus directory by `mojo_corpus` (MojoProof/Kernels.lean) or to
    one file by `mojo_import` (MojoProof/Kernels/*.lean)."""
    mods = [ROOT / 'MojoProof' / 'Kernels.lean'] + sorted((ROOT / 'MojoProof' / 'Kernels').glob('*.lean'))
    alias = {a: d for m in mods for d, a in re.findall(r'"([^"]+)"\s+as (\w+)', m.read_text())}
    out = set()
    for p in mods[1:]:
        for a in re.findall(r'^mojo_kernel \w+ := Kernels\.(\w+)\.prog', p.read_text(), re.M):
            q = CORPUS / alias[a]
            fs = [q] if q.suffix == '.ll' else q.glob('*.ll')
            out |= {str(f.relative_to(ROOT)) for f in fs}
    return out


LINE = re.compile(r'^\s+(?:%[-\w.$]+ = )?(?:(?:tail|notail|musttail) )?([a-z]+)\b')
CALL = re.compile(r'\bcall [^@\n]*@(llvm\.[\w.$]+)')


def scan_corpus(ops: dict[str, Op], fams: dict[str, re.Pattern]):
    """For each opcode and family: the corpus files that use it and the number of uses."""
    used: dict[str, dict[str, int]] = {}
    for f in sorted(CORPUS.rglob('*.ll')):
        rel = str(f.relative_to(ROOT))
        for line in f.read_text().split('\n'):
            m = LINE.match(line)
            if m and m.group(1) in ops:
                d = used.setdefault('op:' + m.group(1), {})
                d[rel] = d.get(rel, 0) + 1
            for name in CALL.findall(line):
                fam = [k for k, r in fams.items() if r.match(name)]
                key = 'fam:' + (fam[0] if len(fam) == 1 else '?' + name)
                d = used.setdefault(key, {})
                d[rel] = d.get(rel, 0) + 1
    return used


def gpu_launches(text: str) -> bool:
    """Whether the launches of a GPU run record (its text `text`) all agree. A launch line is
    `launch: n grid block words` (a 1-D launch) or `launch: m n k gx gy bx by words` (a 2-D launch
    of the naive matmul kernel: sizes `m`, `n`, `k`, the grid's and the block's sides in x and
    y). Its per-launch `evaluator: n N grid G block B: ...` or `evaluator: m M n N k K grid GX GY
    block BX BY: ...` lines are as many as its launch lines (at least one), name the same numbers
    but the words in the same order and each says `W words agree` with W the launch's words; its
    `evaluator: L launches, 0 differ` line has L the number of launches; and its `compare:`
    command passes that number as its last argument."""
    launches = [line.split() for line in re.findall(r'^launch: (\d+(?: \d+)*)$', text, re.M)]
    head = r'n \d+ grid \d+ block \d+|m \d+ n \d+ k \d+ grid \d+ \d+ block \d+ \d+'
    evals = [(re.findall(r'\d+', e[1]), e[2])
             for e in re.finditer(rf'^evaluator: ({head}): (.*)$', text, re.M)]
    n = len(launches)
    summary = re.findall(r'^evaluator: (\d+) launches, (\d+) differ$', text, re.M)
    return (n > 0 and n == len(evals) and summary == [(str(n), '0')] and
            re.findall(r'^compare: .* (\d+)$', text, re.M) == [str(n)] and
            all(len(lt) in (4, 8) and lt[:-1] == et[0] and et[1] == f'{lt[-1]} words agree'
                for lt, et in zip(launches, evals)))


def gpu_records() -> dict[str, str]:
    """The records of GPU runs (tests/gpu/*/record.txt) whose `result:` line starts with `agree`
    and whose launches all agree (`gpu_launches`): for each, the corpus file of the kernel it ran
    (its `kernel:` line). The file must exist and have the sha256 of the record's `kernel sha256:`
    line. A record whose `result:` says `agree` but whose launch, evaluator and compare lines do
    not is not counted, with a message on stderr. Each counted record, with its first launch's
    words changed, must be rejected by `gpu_launches`."""
    out = {}
    for p in sorted(GPU.glob('*/record.txt')):
        text = p.read_text()
        f = dict(re.findall(r'^([a-z][a-z0-9 ]*): (.*)$', text, re.M))
        rel = str(p.relative_to(ROOT))
        k = ROOT / f['kernel']
        assert k.is_file() and f['kernel'].startswith('tests/corpus/'), f'{rel}: no kernel file'
        sha = hashlib.sha256(k.read_bytes()).hexdigest()
        assert f['kernel sha256'] == sha, f'{rel}: {f["kernel"]} has sha256 {sha}'
        if not f['result'].startswith('agree'):
            continue
        if gpu_launches(text):
            out[rel] = f['kernel']
            bad = re.sub(r'^(launch: (?:\d+ )+)(\d+)$', lambda m: m[1] + str(int(m[2]) + 1),
                         text, count=1, flags=re.M)
            assert bad != text and not gpu_launches(bad), f'{rel}: a changed word count is accepted'
        else:
            print(f'{rel}: result agree, but its launch, evaluator and compare lines do not '
                  'agree; not counted', file=sys.stderr)
    return out


def refusals_tsv() -> dict[str, list[str]]:
    """The distinct reasons of REFUSALS.tsv (without the function), with their files."""
    out: dict[str, list[str]] = {}
    for line in (CORPUS / 'REFUSALS.tsv').read_text().split('\n')[1:]:
        if line.strip():
            path, reason = line.split('\t', 1)
            reason = re.sub(r" in '@[^']*'$", '', reason)
            out.setdefault(reason, []).append('tests/corpus/' + path)
    return out


def yq(s: str) -> str:
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def corpus_field(files: list[str]) -> str:
    return ', '.join(files[:SHOWN]) if files else 'none'


def corpus_text(files: dict[str, int] | list[str], total: int) -> str:
    n = len(files)
    uses = sum(files.values()) if isinstance(files, dict) else n
    if not n:
        return 'No corpus file uses it.'
    s = f'{n} of the {total} corpus files use it ({uses} uses)'
    if n > SHOWN:
        s += f'; `corpus` lists the first {SHOWN} in path order'
    return s + '.'


def ref_of(anchor: str) -> str:
    return f'{PTX if anchor in PTX_ANCHORS else LANGREF} #{anchor}'


def card(cid, title, ref, lean, files, tests, body, gpu=()) -> str:
    """A card; L1 when `lean` names declarations, L0 when it is empty (`not stated yet`); L2 when
    it is L1 and `gpu` lists records of GPU runs (its `evidence: L2:`)."""
    level = ('L2' if gpu else 'L1') if lean else 'L0'
    head = ['---', f'id: {cid}', f'title: {title}', 'kind: construct', f'ref: {ref}',
            f'quote: {yq(QUOTES[ref.split("#")[1]])}',
            f'lean: {", ".join(lean) if lean else "not stated yet"}',
            f'corpus: {corpus_field(files)}', f'tests: {", ".join(tests) if tests else "none"}',
            'upstream:', f'level: {level}'] + ([f'evidence: L2: {", ".join(gpu)}'] if gpu else []) \
        + ['---', '']
    return '\n'.join(head) + body.rstrip('\n') + '\n'


def open_text(run: str, gpu=()) -> str:
    """A construct card's open work, from its row of the Modelled table and its GPU records."""
    if run == 'returns' and gpu:
        return ('L3 needs a kernel card (roadmap/kernels/) with L2 evidence, a proved kernel, whose '
                'program uses the construct; this script reads no kernel card and writes no L3 '
                'evidence.\n')
    if run == 'returns':
        return 'L2 needs a recorded GPU run of a test of the construct; there is none.\n'
    return ('L1 needs a semantics of the construct: the run of its test kernel stops with '
            f'`{run}`. L2 then needs a recorded GPU run of a test of it; there is none.\n')


def checker_text(entries: list[str]) -> str:
    if not entries:
        return 'The block checker has no entry for it.'
    return 'The block checker (MojoProof/Sym/Rules.lean): ' + '; '.join(entries) + '.'


def generate() -> dict[str, str]:
    ops, parser_refusals = importer_ops()
    fams = families()
    rules = rule_table()
    decls = index()
    kfiles = kernel_files()
    records = gpu_records()
    used = scan_corpus(ops, fams)
    runs = modelled()
    collectives = set(re.findall(r'\| \.(\w+)[^\n]*convergent := true',
                                 def_body(read('MojoProof/LLVM/Intrinsic.lean'),
                                          'def effects : Intrinsic → Effects')))
    total = len(list(CORPUS.rglob('*.ll')))
    unknown = sorted(k for k in used if k.startswith('fam:?'))
    assert not unknown, f'calls no family matches: {unknown}'
    for lm in rules['_lemmas']:
        assert f'MojoProof.Sym.{lm}' in decls, lm

    def names(xs):
        out = []
        for x in xs:
            if x in decls and x not in out:
                out.append(x)
        return out

    def kernel_note(files):
        ks = sorted(set(files) & kfiles)
        if not ks:
            return ''
        return ('\n\nThe programs of the library\'s `mojo_kernel` theorems use it ('
                + ', '.join(f'`{k}`' for k in ks)
                + '). L3 counts that only through a kernel card (roadmap/kernels/) with L2 '
                'evidence, which this script does not read.')

    def gpu_of(files, run):
        """The records of GPU runs that agree, of a kernel whose file uses the construct."""
        return [r for r, k in sorted(records.items()) if k in files] if run == 'returns' else []

    def gpu_text(gpu):
        if not gpu:
            return ''
        return ('\n\n## GPU runs\n\nA conformance test, not a proof. The records of GPU runs '
                'of corpus kernels whose IR uses it: ' + ', '.join(gpu) + '. In each, the grid '
                'evaluator ran the imported corpus program on the inputs of the GPU run, and its '
                'output buffer agreed with the GPU\'s, bit for bit over the whole buffer, on every '
                'launch the record lists. That covers the forms of the construct those kernels '
                'use, on those inputs and launches, and nothing else.')

    out: dict[str, str] = {}
    items = []
    for kw in sorted(ops):
        files = used.get('op:' + kw, {})
        if not files:
            continue
        op = ops[kw]
        typ = 'Inst' if op.kind == 'inst' else 'Term'
        anchor = next(a for a in (f'{kw}-instruction', f'{kw}-to-instruction') if a in QUOTES)
        helpers = [h for c in op.ctors for h in OP_HELPERS.get(c, [])] + OP_HELPERS.get(kw, [])
        lemmas = [f'MojoProof.Sym.{e.split("`")[1][4:]}' for c in op.ctors
                  for e in rules.get(f'{typ}.{c}', []) if e.startswith('`')]
        parser = 'MojoProof.LLVM.Parser.inst' if op.kind == 'inst' else \
            'MojoProof.LLVM.Parser.terminator'
        sem = 'MojoProof.Sem.exec' if op.kind == 'inst' else 'MojoProof.Sem.step'
        lean = names([parser, f'MojoProof.LLVM.{typ}', sem] + helpers + lemmas)
        run = runs.get(kw)
        assert run, f'{MODELLED} has no row for {kw}'
        gpu = gpu_of(files, run)
        ctors = ' or '.join(f'`{typ}.{c}`' for c in op.ctors)
        if op.opctor:
            ctors += f' with `{op.opctor}`'
        entries = [e for c in op.ctors for e in rules.get(f'{typ}.{c}', [])]
        cid = f'{"inst" if op.kind == "inst" else "term"}-{kw}'
        title = f'The `{kw}` {"instruction" if op.kind == "inst" else "terminator"}'
        if run == 'returns':
            sem_text = (f'the semantics gives it a meaning in `{sem}`'
                        + (f', with {", ".join(f"`{h}`" for h in dict.fromkeys(helpers))}'
                           if helpers else '')
                        + f'. {MODELLED} runs a kernel of it (its row `{kw}`), and the run '
                        'returns. ')
        else:
            sem_text = (f'it is parsed, not modelled: {MODELLED}\'s kernel of it (its row '
                        f'`{kw}`) stops with `{run}`. The declarations: '
                        + ', '.join(f'`{x}`' for x in lean) + '. ')
            lean = []
        body = (f'# {title}\n\n'
                f'## Rule\n\nLangRef\'s section on `{kw}` (the quote is the first sentence of its '
                f'overview). The importer reads `{kw}` as {ctors} (`{parser.split(".", 2)[2]}`); '
                + sem_text + checker_text(entries) + '\n\n'
                f'## Corpus\n\n{corpus_text(files, total)}' + kernel_note(files)
                + gpu_text(gpu) + '\n\n'
                '## Out of scope\n\nForms of the instruction the corpus does not use are read by the '
                'same parser case, but no corpus file exercises them. That the semantics gives '
                f'`{kw}` the meaning LLVM gives it rests on reading LangRef (docs/TRUST.md T7), '
                + ('and on the GPU runs above for their inputs, ' if gpu else '')
                + 'not on a check against LLVM.\n\n'
                '## Open\n\n' + open_text(run, gpu))
        out[f'cards/{cid}.md'] = card(cid, title, ref_of(anchor), lean, sorted(files),
                                      ['MojoProofTest.Rule', 'MojoProofTest.Corpus',
                                       'MojoProofTest.Modelled'], body, gpu)
        items.append((cid, title, 'opcode', run == 'returns', gpu))
    for fam in sorted(fams, key=lambda f: list(fams).index(f)):
        files = used.get('fam:' + fam, {})
        if not files:
            continue
        anchor = FAMILY_REF[fam]
        lemmas = [f'MojoProof.Sym.{e.split("`")[1][4:]}'
                  for e in rules.get(f'Intrinsic.{fam}', []) if e.startswith('`')]
        lean = names(['MojoProof.LLVM.Intrinsic.ofDecl', 'MojoProof.LLVM.Intrinsic',
                      'MojoProof.Sem.intrinsic'] + FAMILY_HELPERS.get(fam, []) + lemmas)
        run = runs.get(f'Intrinsic.{fam}')
        assert run, f'{MODELLED} has no row for Intrinsic.{fam}'
        gpu = gpu_of(files, run)
        if run == 'returns':
            sem_text = ('The semantics gives a call its meaning in `MojoProof.Sem.intrinsic`'
                        + (', and the grid completes the collective call in '
                           '`MojoProof.Sem.Grid.fire`' if fam in collectives else '')
                        + f'. {MODELLED} runs a kernel of a call (its row `Intrinsic.{fam}`), and '
                        'the run returns. ')
        else:
            sem_text = (f'The family is parsed, not modelled: {MODELLED}\'s kernel of a call (its '
                        f'row `Intrinsic.{fam}`) stops with `{run}`. The declarations: '
                        + ', '.join(f'`{x}`' for x in lean) + '. ')
            lean = []
        cid = f'intrinsic-{fam.lower()}'
        title = f'The intrinsic family `Intrinsic.{fam}`'
        src = 'PTX ISA\'s section on the instruction NVPTX lowers it to' \
            if anchor in PTX_ANCHORS else 'LangRef\'s section on the intrinsic'
        names_used = sorted({n for f in files for n in CALL.findall((ROOT / f).read_text())
                             if fams[fam].match(n)})
        body = (f'# {title}\n\n'
                f'## Rule\n\n{src} (the quote is the section\'s first sentence). The importer '
                f'accepts a declaration of this family only if `Intrinsic.ofDecl` recognizes its '
                f'name and signature (`Intrinsic.name`, `Intrinsic.sig`). '
                + FAMILY_NOTE.get(fam, '') + sem_text
                + checker_text(rules.get(f'Intrinsic.{fam}', [])) + '\n\n'
                f'## Corpus\n\n{corpus_text(files, total)} The members called: '
                + ', '.join(f'`{n}`' for n in names_used) + '.' + kernel_note(files)
                + gpu_text(gpu) + '\n\n'
                '## Out of scope\n\nMembers of the family the corpus does not call. '
                + ('The NVPTX backend\'s documentation of the NVVM intrinsics is not quoted (no '
                   'local copy); that the intrinsic is the PTX instruction cited rests on reading '
                   'the PTX ISA (docs/TRUST.md T7' + (', T10' if fam == 'rsqrtApprox' else '')
                   + ').' if anchor in PTX_ANCHORS else
                   'That the semantics gives the family the meaning LLVM gives it rests on reading '
                   'LangRef (docs/TRUST.md T7).') + '\n\n'
                '## Open\n\n' + open_text(run, gpu))
        out[f'cards/{cid}.md'] = card(cid, title, ref_of(anchor), lean, sorted(files),
                                      ['MojoProofTest.Rule', 'MojoProofTest.Corpus',
                                       'MojoProofTest.Modelled'], body, gpu)
        items.append((cid, title, 'intrinsic', run == 'returns', gpu))
    for k, (reason, files) in enumerate(sorted(refusals_tsv().items()), 1):
        asm = re.match(r'unsupported inline asm "([^"]*)"', reason)
        instr = asm.group(1).split()[0] if asm else ''
        anchor = next((a for p, a in ASM_REF.items() if instr.startswith(p)), None)
        assert anchor, reason
        slug = re.sub(r'[^a-z0-9]+', '-', instr.lower()).strip('-')
        nargs = asm.group(1).count('$') if asm else 0
        cid = f'refused-asm-{slug}-{nargs}'
        title = f'Refused: inline asm `{instr}` with {nargs} operands'
        body = (f'# {title}\n\n'
                f'## Rule\n\nThe importer refuses a call of inline assembly: `Parser.inst` reads '
                f'no `asm` callee, and the corpus check records the files it refuses in '
                f'tests/corpus/REFUSALS.tsv with the reason `{reason}`. The quote is the first '
                f'sentence of PTX ISA\'s section on `{instr.split(".")[0]}`, the instruction the '
                f'string holds.\n\n'
                f'## Corpus\n\n{corpus_text(files, total)}\n\n'
                '## Out of scope\n\nEverything: no Lean model exists, and the files that call it '
                'are not imported.\n\n'
                '## Open\n\nA model of the instruction (an intrinsic family with a stated '
                'contract) before the importer can accept these files.\n')
        out[f'cards/{cid}.md'] = card(cid, title, ref_of(anchor), [], files,
                                      ['MojoProofTest.Corpus'], body)
        items.append((cid, title, 'refused', False, []))
    for kw, msg in parser_refusals:
        word = msg.split("'")[1]
        cid = 'refused-' + word.replace(' ', '-')
        title = f'Refused: `{word}`'
        files = used.get('op:' + kw, {})
        body = (f'# {title}\n\n'
                f'## Rule\n\nThe importer refuses `{word}` with the message `{msg}` '
                f'(`Parser.inst`). The quote is the first sentence of LangRef\'s section on '
                f'`{kw}`; the atomic form is described in the same section.\n\n'
                '## Corpus\n\nNo corpus file uses it: the corpus check would refuse such a file, '
                'and tests/corpus/REFUSALS.tsv gives no such reason.\n\n'
                '## Out of scope\n\nEverything: no Lean model exists.\n\n'
                '## Open\n\nA model of the atomic load and store orderings, if a kernel needs '
                'them.\n')
        out[f'cards/{cid}.md'] = card(cid, title, ref_of(f'{kw}-instruction'), [], [],
                                      ['MojoProofTest.Corpus'], body)
        items.append((cid, title, 'refused', False, []))
    out['README.md'] = readme(items, total, len(ops), sorted(records))
    return out


def readme(items, total, nops, records) -> str:
    groups = {'opcode': [], 'intrinsic': [], 'refused': []}
    for cid, title, g, ok, gpu in items:
        note = ' (tested against the GPU)' if gpu else \
            '' if ok or g == 'refused' else ' (parsed, not modelled)'
        groups[g].append(f'- [{cid}](cards/{cid}.md): {title}{note}')
    constructs = [(cid, ok) for cid, _, g, ok, _ in items if g != 'refused']
    l2 = sum(bool(gpu) for _, _, _, _, gpu in items)
    l1 = sum(ok for _, ok in constructs)
    unmodelled = [cid for cid, ok in constructs if not ok]
    coverage = (f'{l1} of the {len(constructs)} opcode and family cards are L1: the importer reads '
                'the construct, `MojoProof.Sem.exec`, `MojoProof.Sem.step` or '
                '`MojoProof.Sem.intrinsic` gives it a meaning, and the grid evaluator runs a '
                f'kernel of it to the end ({MODELLED}); the card repeats the block checker\'s '
                'rules and refusals for its constructors. '
                + (('The ' + ' and '.join(', '.join(f'`{c}`' for c in unmodelled).rsplit(', ', 1))
                    + ' card'
                    + ('s are' if len(unmodelled) > 1 else ' is')
                    + ' L0, parsed but not modelled: the semantics stops a run at the construct. ')
                   if unmodelled else '')
                + 'The refused constructs are L0. '
                + (f'{l2} of the L1 cards are L2: a record of a GPU run that agrees with the '
                   'evaluator ran a corpus kernel whose IR uses the construct ('
                   + ', '.join(records) + '; a conformance test, not a proof). '
                   if records else 'No card is L2, since no GPU run is recorded. ')
                + 'No card is L3: this script writes no L3 evidence.')
    return '\n'.join([
        '# LLVM IR constructs',
        '',
        'Written by `scripts/roadmap_llvm.py` from the importer, the rule table, the corpus and '
        'its refusals. Do not edit; run `python3 scripts/roadmap_llvm.py` after changing one of '
        'them.',
        '',
        '## Scope',
        '',
        f'The LLVM IR the {total} corpus files use: every opcode the importer reads that some '
        'corpus file uses, every intrinsic family some corpus file calls, and every construct the '
        'importer refuses. The corpus IR declares no LLVM version (it has no `llvm.ident`); the '
        'cards cite the LangRef and PTX ISA versions the semantics was read from (LangRef '
        '24.0.0git, PTX ISA 9.5, docs/TRUST.md T7). An opcode or family card is L1 when its `lean` '
        'names exist and the semantics runs the construct: the grid evaluator runs a kernel of it '
        f'until every thread returns, the row `returns` of the table {MODELLED} pins (its build '
        'checks the table). A construct the importer reads and the semantics stops at (with '
        '`unsupported` or another fault) is L0, parsed but not modelled, and its card says so.',
        '',
        '## Items',
        '',
        '### Opcodes',
        '',
        *groups['opcode'],
        '',
        '### Intrinsic families',
        '',
        *groups['intrinsic'],
        '',
        '### Refused constructs',
        '',
        *groups['refused'],
        '',
        '## Out of scope',
        '',
        f'Opcodes the importer reads ({nops} keywords) that no corpus file uses, and intrinsic '
        'families no corpus file calls: the cards follow the corpus. Calls of functions defined in '
        'the module are calls, not intrinsics, and have no card of their own.',
        '',
        '## Depends on',
        '',
        'The corpus (tests/corpus/MANIFEST.tsv) and the importer\'s tables; the reading of LangRef '
        'and PTX ISA (docs/TRUST.md T7, T9, T10).',
        '',
        '## Coverage in MojoProof',
        '',
        coverage,
        '',
        '## Next steps',
        '',
        '- A recorded GPU run of a kernel that uses the construct, for L2 of the L1 cards that '
        'are not L2.',
        *(['- A semantics of the constructs parsed but not modelled ('
           + ', '.join(f'`{c}`' for c in unmodelled) + '), for L1.'] if unmodelled else []),
        '- A model of the refused inline asm (`cvt` to e4m3 and `cp.async.cg`), so the refused '
        'files import.',
        '- The block checker\'s refusals listed in each card, which bound what a proved kernel '
        'can use today.',
        '',
    ])


def verify_quotes(langref: str, ptx: str) -> int:
    def text(path):
        s = pathlib.Path(path).read_text()
        s = re.sub(r'<[^>]+>', '', s)
        return re.sub(r'\s+', ' ', html.unescape(s))
    docs = {False: text(langref), True: text(ptx)}
    bad = [a for a, q in sorted(QUOTES.items()) if q not in docs[a in PTX_ANCHORS]
           or f'id="{a}"' not in pathlib.Path(ptx if a in PTX_ANCHORS else langref).read_text()]
    for a in bad:
        print(f'quote or section not found: {a}')
    print(f'{len(QUOTES) - len(bad)} of {len(QUOTES)} quotes found')
    return 1 if bad else 0


def main() -> int:
    args = sys.argv[1:]
    if args[:1] == ['--verify-quotes'] and len(args) == 3:
        return verify_quotes(args[1], args[2])
    if args not in ([], ['--check']):
        print(__doc__)
        return 2
    want = generate()
    have = {str(p.relative_to(AREA)): p.read_text() for p in sorted(AREA.rglob('*.md'))} \
        if AREA.is_dir() else {}
    if args == ['--check']:
        diff = sorted(k for k in set(want) | set(have) if want.get(k) != have.get(k))
        for k in diff:
            print(f'roadmap/llvm-ir/{k} differs from what scripts/roadmap_llvm.py writes')
        return 1 if diff else 0
    for k in sorted(set(have) - set(want)):
        (AREA / k).unlink()
    for k, v in sorted(want.items()):
        (AREA / k).parent.mkdir(parents=True, exist_ok=True)
        (AREA / k).write_text(v)
    print(f'wrote roadmap/llvm-ir/: {len(want) - 1} cards and README.md')
    return 0


if __name__ == '__main__':
    sys.exit(main())
