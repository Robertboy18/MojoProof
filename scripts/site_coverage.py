"""How much of Modular's GPU code is proved: the coverage figure, the progress figure and the coverage page.

The kernels are the ones roadmap/kernels/universe.tsv lists (scripts/kernel_universe.py universe, from Modular's
repository at a pinned commit). A kernel has a proved specialization when a theorem of roadmap/llvm-ir/programs.tsv
(scripts/L3Programs.lean: each theorem concluding `Kernel.Sound`, with the corpus file its program is bound to by its
term) is about a file compiled from it (`kernel_universe.proved_functions`, through the file's manifest row); the page
names those files and their digests, and the revision they were compiled from, which need not be the universe's. A
kernel card's level is shown next to it but does not decide the count. Other kernels are on the roadmap when a card's
`ref` and `quote` name their file and function, or name a function of the same directory their name starts with.
Nothing is claimed about a function's other specializations or about its source at the universe's revision.

The progress figure reads roadmap/kernels/proved.tsv and roadmap/kernels/theorems.tsv (scripts/kernel_universe.py
history) and adds the current tree's proved kernels and theorem counts (`kernel_universe.count_theorems`: the
`theorem` and `lemma` declarations in the source, not the theorems commands generate), so it is never older than the
site.

Like the home page's figures, these are inline SVG coloured by the stylesheet, with no JavaScript: marks are links,
hover is CSS, tooltips are SVG titles, and the page's filters are radio buttons read by CSS `:has()`.
"""
import datetime
import fnmatch
import re
import subprocess
from html import escape

import kernel_universe

AREA_TITLES = {'nn': 'nn: attention, norms, softmax, MoE, convolution', 'linalg': 'linalg: matmul, GEMV, quantization',
               'examples': 'examples', 'comm': 'comm: collectives', 'state_space': 'state_space',
               'shmem': 'shmem', 'graph_compiler': 'graph_compiler', 'kv_cache': 'kv_cache',
               'quantization': 'quantization', 'internal_utils': 'internal_utils', 'misc': 'other'}
STATUS_NAME = {'proved': 'has a proved specialization', 'roadmap': 'on the roadmap', 'none': 'not started'}
# Light-surface colours, written as presentation attributes so the figures read without the stylesheet (in a PDF, a
# feed reader); the stylesheet's rules override them and switch to the dark-mode steps.
FG, MUTED, BG, RULE, LEAN, MOJO, GOOD = '#1f2023', '#5d5f66', '#fdfcf9', '#dcdad3', '#2a78d6', '#eb6834', '#0ca30c'
LV = ['#86b6ef', '#5598e7', '#2a78d6', '#1c5cab', '#104281']


def sq_paint(status: str, level) -> str:
    if status == 'proved':
        return f'fill="{LV[lvl(level)]}" stroke="{BG}"'
    if status == 'roadmap':
        return f'fill="{BG}" stroke="{LEAN}" stroke-width="1.4"'
    return f'fill="{RULE}" stroke="{RULE}"'


def esc(s) -> str:
    return escape(str(s), quote=True)


def lvl(level) -> int:
    return int(str(level)[1:] or 0) if level else 0


def universe(site):
    """(commit, date, header notes, rows); each row: name, area, path, line, launch sites."""
    text = (site.root / 'roadmap' / 'kernels' / 'universe.tsv').read_text().split('\n')
    head = [l[2:] for l in text if l.startswith('# ')]
    m = re.search(r'modular/modular@([0-9a-f]{40}) \((\d{4}-\d\d-\d\d)\)', head[0])
    rows = []
    for l in text:
        if l and not l.startswith('#') and not l.startswith('name\t'):
            n, a, p, ln, s = l.split('\t')
            rows.append({'name': n, 'area': a, 'path': p, 'line': int(ln), 'sites': int(s)})
    return m.group(1), m.group(2), head, rows


def kernel_cards(site):
    """The kernel cards: id, level, title, the Modular revision, file and function their `ref` and `quote` name, and the
    IR their `corpus` names (the compiled programs the card's theorems are about)."""
    import roadmap_status as rs
    out = []
    for a in site.areas:
        if a['id'] != 'kernels':
            continue
        for c in a['cards']:
            keys, _ = rs.front_matter((site.root / 'roadmap' / 'kernels' / 'cards' / f'{c["id"]}.md').read_text())
            ref = str(keys.get('ref', '')).strip().strip('"')
            m = re.match(r'modular/modular@([0-9a-f]+):([^:]+):(\d+)', ref)
            fn = re.search(r'\b(?:def|fn)\s+([A-Za-z_]\w*)', str(keys.get('quote', '')))
            out.append({'id': c['id'], 'level': c['level'], 'title': keys.get('title', c['id']),
                        'rev': m.group(1) if m else None, 'path': m.group(2) if m else None,
                        'ref_line': int(m.group(3)) if m else None, 'fn': fn.group(1) if fn else None,
                        'modular': bool(m), 'ref': ref, 'corpus': str(keys.get('corpus', '')).strip()})
    return out


def statuses(site):
    """Every kernel of the universe with its status: (row, status, card or None, level or None)."""
    commit, date, head, rows = universe(site)
    cards = kernel_cards(site)
    for c in cards:
        # a card that quotes a line inside the kernel names the function whose definition is the nearest one above
        # that line in the same file
        if c['path'] and not c['fn']:
            above = [r for r in rows if r['path'] == c['path'] and r['line'] <= c['ref_line']]
            if above:
                c['fn'] = max(above, key=lambda r: r['line'])['name']
    exact = {(c['path'], c['fn']): c for c in cards if c['path'] and c['fn']}
    proofs = kernel_universe.proved_functions(_read(site, 'roadmap/llvm-ir/programs.tsv'),
                                              _read(site, 'tests/corpus/MANIFEST.tsv'), rows)
    out = []
    for r in rows:
        r['proofs'] = proofs.get((r['path'], r['name']), [])
        c = exact.get((r['path'], r['name']))
        fam = c or next((c for c in cards if c['fn'] and c['path'] and r['name'].startswith(c['fn'])
                         and r['path'].rsplit('/', 1)[0] == c['path'].rsplit('/', 1)[0]), None)
        status = 'proved' if r['proofs'] else 'roadmap' if fam else 'none'
        out.append((r, status, fam, c['level'] if c else None))
    return commit, date, head, out, cards


def _read(site, rel: str) -> str:
    f = site.root / rel
    return f.read_text() if f.is_file() else ''


def _manifest(site) -> dict[str, dict]:
    """tests/corpus/MANIFEST.tsv by file (tests/corpus/<path>)."""
    out = {}
    for line in _read(site, 'tests/corpus/MANIFEST.tsv').split('\n'):
        cols = line.split('\t')
        if len(cols) == len(kernel_universe.MANIFEST_COLS) and cols[0] != 'path':
            out['tests/corpus/' + cols[0]] = dict(zip(kernel_universe.MANIFEST_COLS, cols))
    return out


def _refused(site) -> set[str]:
    """The corpus files the importer refuses (tests/corpus/REFUSALS.tsv), as tests/corpus/<path>."""
    return {'tests/corpus/' + l.split('\t')[0] for l in _read(site, 'tests/corpus/REFUSALS.tsv').split('\n')[1:] if l}


def _selected(c: dict, files) -> list[str]:
    """The files of `files` (tests/corpus/<path>) a card's `corpus` selector names: a directory names the files under
    it, a pattern the files it matches, `none` nothing."""
    out = []
    for sel in [s.strip().rstrip('/') for s in (c or {}).get('corpus', '').split(',') if s.strip()]:
        if sel == 'none':
            continue
        glob = any(ch in sel for ch in '*?[')
        out += [f for f in files if (fnmatch.fnmatch(f, sel) if glob else f.startswith(sel + '/'))]
    return sorted(set(out))


def _rev(m: dict | None) -> str:
    """The Modular revision a manifest row's source is at (`modular/modular@<rev>:<path>`), or `-`."""
    g = re.match(r'modular/modular@([0-9a-f]+):', (m or {}).get('source', ''))
    return g.group(1) if g else '-'


def proved_at(site, r: dict, c: dict | None, commit: str) -> str:
    """What a kernel's theorems are about, in words: the corpus files they are bound to (with their digests) and the
    revision those were compiled from, with a note when that is not the universe's revision `commit`; then the other
    files the card's `corpus` selector names, which no theorem is about, and how many of them the importer refuses."""
    man = _manifest(site)
    files = sorted({f for _, f, _ in r['proofs']})
    revs = sorted({_rev(man.get(f)) for f in files})
    named = ', '.join(f'{f.removeprefix("tests/corpus/")} (sha256 {man[f]["sha256"][:12]})' for f in files)
    note = '' if all(commit.startswith(v) for v in revs) else \
        f"; the function at the inventory's revision {commit[:8]} is not checked"
    text = f'Kernel.Sound for {named}, compiled at modular@{"/".join(revs)}{note}'
    rest = [f for f in _selected(c, man) if f not in files]
    if rest:
        refused = sum(1 for f in rest if f in _refused(site))
        text += (f'; the card\'s corpus also has {len(rest)} other file{"s" if len(rest) != 1 else ""} with no kernel '
                 f'theorem' + (f', {refused} of them refused by the importer' if refused else ''))
    return text


def source_url(commit: str, r: dict) -> str:
    return f'https://github.com/modular/modular/blob/{commit}/{r["path"]}#L{r["line"]}'


def card_href(prefix: str, c: dict) -> str:
    return f'{prefix}roadmap/kernels/{c["id"]}.html'


def summary(site):
    commit, date, head, st, cards = statuses(site)
    n = len(st)
    proved = sum(1 for _, s, _, _ in st if s == 'proved')
    road = sum(1 for _, s, _, _ in st if s == 'roadmap')
    own = [c for c in cards if not c['modular'] and lvl(c['level']) >= 2]
    return {'n': n, 'proved': proved, 'roadmap': road, 'none': n - proved - road, 'commit': commit,
            'date': date, 'own': own, 'head': head}


# Figure: one square per kernel, one band per area, proved first.
def coverage_svg(site, prefix: str, fig_id: str) -> str:
    commit, date, head, st, cards = statuses(site)
    order = {'proved': 0, 'roadmap': 1, 'none': 2}
    areas: dict[str, list] = {}
    for item in st:
        areas.setdefault(item[0]['area'], []).append(item)
    per_row, cell, gap = 40, 11, 3
    pitch = cell + gap
    label_w, top = 168, 6
    out, y = [], top
    for a in sorted(areas, key=lambda a: (-len(areas[a]), a)):
        items = sorted(areas[a], key=lambda x: (order[x[1]], -(lvl(x[3]) if x[3] else 0), x[0]['name']))
        done = sum(1 for x in items if x[1] == 'proved')
        nrows = -(-len(items) // per_row)
        out.append(f'<text class="band" x="{label_w - 12}" y="{y + 10}" text-anchor="end" fill="{FG}" '
                   f'font-size="12.5">{esc(a)}</text>'
                   f'<text class="band-n" x="{label_w - 12}" y="{y + 24}" text-anchor="end" fill="{MUTED}" '
                   f'font-size="11">'
                   f'{done} of {len(items)}</text>')
        for i, (r, s, c, level) in enumerate(items):
            row, col = divmod(i, per_row)
            x, yy = label_w + col * pitch, y + row * pitch
            what = (f'a proved specialization ({c["id"] + ", " + level if c and level else c["id"] if c else "no card"}), '
                    f'{proved_at(site, r, c, commit)}' if s == 'proved' else
                    f'on the roadmap ({c["id"]})' if s == 'roadmap' else 'not started')
            href = card_href(prefix, c) if c else source_url(commit, r)
            level = ('L4' if level == 'L4' else 'L2') if s == 'proved' else level
            cls = f'sq {s}' + (f' lv{lvl(level)}' if s == 'proved' else '')
            out.append(f'<a href="{esc(href)}" class="k"><title>{esc(r["name"])} ({esc(r["path"])}): {esc(what)}'
                       f'</title><rect class="{cls}" x="{x}" y="{yy}" width="{cell}" height="{cell}" rx="2.5" '
                       f'{sq_paint(s, level)}/></a>')
        y += max(nrows * pitch, 28) + 8
    ly = y + 6
    legend = [('sq proved lv4', ('proved', 'L4'), 'proved specialization, card at L4'),
              ('sq proved lv2', ('proved', 'L2'), 'proved specialization, card below L4'),
              ('sq roadmap', ('roadmap', None), 'on the roadmap'), ('sq none', ('none', None), 'not started')]
    for i, (cls, (s, level), text) in enumerate(legend):
        lx, yy = label_w + (i % 2) * 280, ly + (i // 2) * 20
        out.append(f'<rect class="{cls}" x="{lx}" y="{yy}" width="{cell}" height="{cell}" rx="2.5" {sq_paint(s, level)}/>'
                   f'<text class="legend" x="{lx + cell + 6}" y="{yy + 10}" fill="{MUTED}" font-size="12">{esc(text)}</text>')
    H = ly + 40 + 4
    W = label_w + per_row * pitch
    return (f'<svg class="fig coverage" viewBox="0 0 {W} {H}" role="img" aria-labelledby="{fig_id}-title">'
            f'<title id="{fig_id}-title">Modular\'s GPU kernels, one square each, by status</title>'
            + ''.join(out) + '</svg>')


def _theorem_series(site):
    """[(date, library, tests)] from theorems.tsv, with today's tree as the last point: the `theorem` and `lemma`
    declarations in the source (`kernel_universe.count_theorems`)."""
    pts = []
    for l in (site.root / 'roadmap' / 'kernels' / 'theorems.tsv').read_text().split('\n'):
        if l and not l.startswith('#') and not l.startswith('date\t'):
            d, lib, tst = l.split('\t')
            pts.append((d, int(lib), int(tst)))
    lib = tst = 0
    for f in site.files:
        if f.endswith('.lean') and f.split('/')[0] in kernel_universe.LIBRARY + kernel_universe.TESTS:
            k = kernel_universe.count_theorems((site.root / f).read_text())
            if f.split('/')[0] in kernel_universe.TESTS:
                tst += k
            else:
                lib += k
    today = _head_date(site)
    pts = [p for p in pts if p[0] < today] + [(today, lib, tst)]
    return pts


def _head_date(site) -> str:
    r = subprocess.run(['git', '-C', str(site.root), 'log', '-1', '--format=%cs'], capture_output=True, text=True)
    return r.stdout.strip() or datetime.date.today().isoformat()


def _proved_series(site, st):
    """[(date, set of Modular's kernel functions with a proved specialization, by name)]: roadmap/kernels/proved.tsv
    (from the day programs.tsv was first written), then today's tree. MojoProof's own corpus kernels are left out, as
    in the coverage figure."""
    steps = []
    for l in _read(site, 'roadmap/kernels/proved.tsv').split('\n'):
        if l and not l.startswith('#') and not l.startswith('date\t'):
            d, fns = (l.split('\t') + [''])[:2]
            steps.append((d, {f.rsplit(':', 1)[1] for f in fns.split(';') if f}))
    today = _head_date(site)
    steps = [s for s in steps if s[0] < today] + [(today, {r['name'] for r, s, _, _ in st if s == 'proved'})]
    return steps


# Figure: progress over time, two panels on one day axis.
def progress_svg(site, fig_id: str) -> str:
    commit, date, head, st, cards = statuses(site)
    th = _theorem_series(site)
    lv = _proved_series(site, st)
    days = [datetime.date.fromisoformat(th[0][0]) + datetime.timedelta(d)
            for d in range((datetime.date.fromisoformat(th[-1][0]) - datetime.date.fromisoformat(th[0][0])).days + 1)]
    W, left, right = 760, 62, 34
    pw = W - left - right
    step = pw / max(len(days) - 1, 1)

    def x(d: str) -> float:
        return left + (datetime.date.fromisoformat(d) - days[0]).days * step

    out = []
    # panel (a): kernels with a proved specialization, a step line over the days
    a_top, a_h = 30, 92
    kmax = max(len(s) for _, s in lv) + 1
    ya = lambda n: a_top + a_h - n / kmax * a_h
    out.append(f'<text class="panel" x="{left}" y="{a_top - 14}" fill="{FG}" font-size="13" font-weight="600">'
               "(a) Modular's kernels with a proved specialization</text>")
    for n in range(0, kmax + 1):
        out.append(f'<line class="grid" x1="{left}" x2="{W - right}" y1="{ya(n)}" y2="{ya(n)}" stroke="{RULE}"/>'
                   f'<text class="tick" x="{left - 8}" y="{ya(n) + 4}" text-anchor="end" fill="{MUTED}" '
                   f'font-size="11">{n}</text>')
    by_day: dict[str, set] = {}
    for d, s in lv:
        by_day[d] = s
    cur, path = None, []
    for d in [x.isoformat() for x in days]:
        if d in by_day:
            cur = by_day[d]
        if cur is not None:   # no point before the first day with a table of theorem programs
            path.append((x(d), ya(len(cur)), d, sorted(cur)))
    pd = f'M{path[0][0]},{path[0][1]}' + ''.join(f' H{px} V{py}' for px, py, _, _ in path[1:])
    out.append(f'<path class="kline" d="{pd}" fill="none" stroke="{GOOD}" stroke-width="2.4"/>')
    for px, py, d, ids in path:
        names = ', '.join(ids) if ids else 'none yet'
        out.append(f'<g class="pt"><title>{esc(d)}: {len(ids)} ({esc(names)})</title>'
                   f'<circle class="kdot" cx="{px}" cy="{py}" r="4" fill="{GOOD}" stroke="{BG}" stroke-width="1.5"/></g>')
    # panel (b): theorem declarations in the source, two lines
    b_top, b_h = a_top + a_h + 52, 118
    tmax = max(l + t for _, l, t in th)
    top_tick = 10 ** len(str(tmax)) // 10 * (-(-tmax // (10 ** len(str(tmax)) // 10)))
    yb = lambda n: b_top + b_h - n / top_tick * b_h
    out.append(f'<text class="panel" x="{left}" y="{b_top - 14}" fill="{FG}" font-size="13" font-weight="600">'
               '(b) theorem and lemma declarations in the source</text>')
    ticks = 4
    for i in range(ticks + 1):
        n = top_tick * i // ticks
        out.append(f'<line class="grid" x1="{left}" x2="{W - right}" y1="{yb(n)}" y2="{yb(n)}" stroke="{RULE}"/>'
                   f'<text class="tick" x="{left - 8}" y="{yb(n) + 4}" text-anchor="end" fill="{MUTED}" '
                   f'font-size="11">{n:,}</text>')
    for cls, val in (('total', lambda p: p[1] + p[2]), ('lib', lambda p: p[1])):
        d = ' '.join(f'{"M" if i == 0 else "L"}{x(p[0])},{yb(val(p))}' for i, p in enumerate(th))
        col, dash = (LEAN, '') if cls == 'total' else (MOJO, ' stroke-dasharray="5 3"')
        out.append(f'<path class="tline {cls}" d="{d}" fill="none" stroke="{col}" stroke-width="2.2"{dash}/>')
    for p in th:
        out.append(f'<g class="pt"><title>{esc(p[0])}: {p[1] + p[2]:,} theorem declarations ({p[1]:,} in the library, '
                   f'{p[2]:,} about kernels and test programs)</title>'
                   f'<circle class="tdot total" cx="{x(p[0])}" cy="{yb(p[1] + p[2])}" r="4" fill="{LEAN}" '
                   f'stroke="{BG}" stroke-width="1.5"/>'
                   f'<circle class="tdot lib" cx="{x(p[0])}" cy="{yb(p[1])}" r="3.4" fill="{MOJO}" stroke="{BG}" '
                   f'stroke-width="1.5"/></g>')
    # the shared day axis
    base = b_top + b_h
    for i, d in enumerate(days):
        if i % max(1, len(days) // 11) == 0 or i == len(days) - 1:
            out.append(f'<text class="tick" x="{left + i * step}" y="{base + 18}" text-anchor="middle" '
                       f'fill="{MUTED}" font-size="11">'
                       f'{d.strftime("%b")} {d.day}</text>')
    ly = base + 40
    out.append(f'<line class="tline total" x1="{left}" x2="{left + 22}" y1="{ly}" y2="{ly}" stroke="{LEAN}" '
               f'stroke-width="2.2"/>'
               f'<text class="legend" x="{left + 28}" y="{ly + 4}" fill="{MUTED}" font-size="12">all declarations</text>'
               f'<line class="tline lib" x1="{left + 160}" x2="{left + 182}" y1="{ly}" y2="{ly}" stroke="{MOJO}" '
               f'stroke-width="2.2" stroke-dasharray="5 3"/>'
               f'<text class="legend" x="{left + 188}" y="{ly + 4}" fill="{MUTED}" font-size="12">'
               'in the library (GPUProof/, MojoProof/)</text>')
    H = ly + 12
    return (f'<svg class="fig progress" viewBox="0 0 {W} {H}" role="img" aria-labelledby="{fig_id}-title">'
            f'<title id="{fig_id}-title">Progress over time</title>' + ''.join(out) + '</svg>')


def coverage_page(site) -> str:
    """The body of roadmap/kernels/coverage.html."""
    commit, date, head, st, cards = statuses(site)
    lv_start = _proved_series(site, st)[0][0]
    s = summary(site)
    areas = sorted({r['area'] for r, *_ in st}, key=lambda a: (-sum(1 for r, *_ in st if r['area'] == a), a))
    rows_by_area = []
    for a in areas:
        items = [x for x in st if x[0]['area'] == a]
        c = {k: sum(1 for x in items if x[1] == k) for k in ('proved', 'roadmap', 'none')}
        rows_by_area.append(f'<tr><td>{esc(a)}</td><td class="num">{len(items)}</td><td class="num">{c["proved"]}</td>'
                            f'<td class="num">{c["roadmap"]}</td><td class="num">{c["none"]}</td></tr>')
    rows_by_area.append(f'<tr class="total"><td>All</td><td class="num">{s["n"]}</td><td class="num">{s["proved"]}</td>'
                        f'<td class="num">{s["roadmap"]}</td><td class="num">{s["none"]}</td></tr>')
    status_inputs = ''.join(
        f'<input type="radio" name="cov-st" id="st-{k}"{" checked" if k == "all" else ""}>'
        f'<label for="st-{k}">{esc(t)}</label>'
        for k, t in (('all', 'All'), ('proved', 'Proved specialization'), ('roadmap', 'On the roadmap'),
                     ('none', 'Not started')))
    area_inputs = ''.join(
        f'<input type="radio" name="cov-ar" id="ar-{esc(a)}"{" checked" if a == "all" else ""}>'
        f'<label for="ar-{esc(a)}">{esc("All areas" if a == "all" else a)}</label>' for a in ['all'] + areas)
    trs = []
    for r, stt, c, level in sorted(st, key=lambda x: ({'proved': 0, 'roadmap': 1, 'none': 2}[x[1]], x[0]['area'], x[0]['name'])):
        card = f'<a href="{c["id"]}.html">{esc(c["id"])}</a>' + (f', {esc(level)}' if level else '') if c else 'no card'
        status = (f'{card}, {esc(proved_at(site, r, c, commit))}' if stt == 'proved' else
                  f'<a href="{c["id"]}.html">{esc(c["id"])}</a>' if stt == 'roadmap' else '-')
        trs.append(f'<tr data-st="{stt}" data-area="{esc(r["area"])}"><td><a href="{esc(source_url(commit, r))}">'
                   f'<code>{esc(r["name"])}</code></a></td><td>{esc(r["area"])}</td>'
                   f'<td><code>{esc(r["path"])}:{r["line"]}</code></td><td class="num">{r["sites"]}</td>'
                   f'<td>{esc(STATUS_NAME[stt])}</td><td>{status}</td></tr>')
    own = ', '.join(f'<a href="{c["id"]}.html">{esc(c["id"])}</a>' for c in s['own'])
    man = _manifest(site)
    revs = sorted({_rev(man.get(f)) for r, stt, _, _ in st if stt == 'proved' for _, f, _ in r['proofs']})
    revs_text = ', '.join(f'<code>{esc(r)}</code>' for r in revs) or 'none'
    same = 'the revision this list is from' if all(commit.startswith(r) for r in revs) else \
        f'not the revision this list is from (<code>{commit[:10]}</code>)'
    area_css = ''.join(f'.cov-list:has(#ar-{a}:checked) tbody tr:not([data-area="{a}"]) {{ display: none; }}\n'
                       for a in areas)
    return f'''<p class="crumbs"><a href="../index.html">Roadmap</a> / <a href="index.html">Kernels</a></p>
<h1>How much of Modular's GPU code is proved</h1>
<p class="lede">Of the {s["n"]} GPU kernel functions that Modular's open-source code launches, {s["proved"]}
{"has" if s["proved"] == 1 else "have"} a proved specialization today, {s["roadmap"]} more are on the roadmap, and
{s["none"]} are not started.</p>
<p>A proved specialization is a kernel theorem (<code>Kernel.Sound</code>) about one compiled program of the
function: the IR of one choice of its element types and parameters, compiled from Modular's source at the revision
the corpus records ({revs_text}), {same}. The list below names each such file and its digest. It
says nothing about the function's other specializations, or about its source at another revision. The theorem says
that every valid launch of the shape it states, at every choice of addresses and of the oracle that the theorem
admits, is memory safe, race free and deadlock free, terminates, and meets its spec, and that the runs that finish
agree on the outputs the theorem observes; at L4 the outputs also have an IEEE error bound or exact bits. MojoProof
also proves
{len(s["own"])} kernels of its own corpus ({own}), which are not Modular's and not counted here. Most of what is left
is the production code: tensor-core matmuls, attention, normalization, collectives and quantization.</p>
<figure id="figure-1">
{coverage_svg(site, "../../", "cov1")}
<figcaption><span class="fig">Figure 1.</span> Modular's GPU kernels, one square per kernel function, grouped by the
directory of <code>max/kernels/src</code> they live in. Filled squares have a proved specialization (the darkest, L4,
also an IEEE error bound or exact bits), outlined ones are on the roadmap, and grey ones are not started. Hover a square for
the function and its file, and click it to open its card or its source. Computed from the cards when the site is
built.</figcaption>
</figure>
<figure id="figure-2">
{progress_svg(site, "cov2")}
<figcaption><span class="fig">Figure 2.</span> Progress over time. (a) Modular's kernels with a proved
specialization, by day, from the table of theorem programs at the last commit of each day, which exists from
{esc(lv_start)} (MojoProof's own corpus kernels are not counted).
(b) The <code>theorem</code> and <code>lemma</code> declarations in the source of the library and of the kernel and
test programs at the last commit of each day, outside comments, strings and quoted templates. Lean checks each of
them (the build allows no <code>sorry</code>); the theorems that commands such as <code>mojo_kernel</code> generate
are checked too but have no declaration in the source and are not counted. The last day is the tree this site was
built from. Hover a point for its numbers.</figcaption>
</figure>
<h2 id="by-area">By area</h2>
<div class="table-wrap"><table><thead><tr><th>Area</th><th class="num">Kernels</th><th class="num">Proved specialization</th>
<th class="num">On the roadmap</th><th class="num">Not started</th></tr></thead><tbody>{"".join(rows_by_area)}</tbody></table></div>
<h2 id="every-kernel">Every kernel</h2>
<div class="cov-list">
<div class="filters"><span class="flabel">Status</span>{status_inputs}</div>
<div class="filters"><span class="flabel">Area</span>{area_inputs}</div>
<div class="table-wrap"><table><thead><tr><th>Kernel</th><th>Area</th><th>Defined at</th><th class="num">Launch sites</th>
<th>Status</th><th>Card</th></tr></thead><tbody>{"".join(trs)}</tbody></table></div>
</div>
<style>{area_css}</style>
<h2 id="how-this-is-counted">How this is counted</h2>
<p>A kernel here is a Mojo function that code in <code>max/kernels/src</code>, <code>max/examples</code> or
<code>Mojo/examples</code> launches with <code>DeviceContext.enqueue_function</code>, directly or through the nearest
<code>comptime</code> alias above the launch. Each file is read whole, without its comments and strings, so a launch
whose function's name is on a later line than its bracket counts, and one in a comment or a docstring does not. The list is from Modular's repository at
<a href="https://github.com/modular/modular/tree/{commit}"><code>{commit[:10]}</code></a> ({esc(date)}), written by
<a href="{site.blob}scripts/kernel_universe.py"><code>scripts/kernel_universe.py</code></a>. {esc(head[1])}
A function counts once however many launches name it. A function has a proved specialization when a theorem in
<a href="{site.blob}roadmap/llvm-ir/programs.tsv"><code>roadmap/llvm-ir/programs.tsv</code></a> is about a corpus file
compiled from it. <a href="{site.blob}scripts/L3Programs.lean"><code>scripts/L3Programs.lean</code></a> writes that
table: each theorem that a kernel card gives as evidence or that a module of <code>MojoProof.Kernels</code> proves,
concluding <code>Kernel.Sound</code> of a program, with the corpus file the program is bound to by its term and that
file's digest. The file's row in <code>tests/corpus/MANIFEST.tsv</code> names the Mojo file that defines its kernel and
the kernel's name, which is the function's name followed by the specialization; the function is the one of that file
whose name it starts with. A kernel theorem that the table does not list is not counted. The card's level is shown
next to the function but does not decide the count, and the card's other corpus files, which no theorem is about, are
counted apart, with the ones the importer refuses. The match is by file and function name, so it does not show that
the function at this list's revision, or another specialization of it, meets the theorem. Other functions are on the
roadmap when a card names them, or names a function of their directory that their name starts with.</p>
'''


CSS = '''
/* Coverage and progress */
svg.fig.coverage .band { font-size: 12.5px; fill: var(--fg); }
svg.fig.coverage .band-n { font-size: 11px; fill: var(--muted); font-variant-numeric: tabular-nums; }
svg.fig .legend { font-size: 12px; fill: var(--muted); }
.sq { stroke-width: 1; transition: stroke .1s, stroke-width .1s; }
.sq.none { fill: var(--rule); stroke: var(--rule); opacity: .75; }
.sq.roadmap { fill: var(--bg); stroke: var(--lean); stroke-width: 1.4; }
.sq.proved { stroke: var(--bg); }
svg.fig .k:hover .sq { stroke: var(--fg); stroke-width: 2; opacity: 1; }
svg.fig.progress .panel { font-size: 13px; fill: var(--fg); font-weight: 600; }
svg.fig.progress .tick { font-size: 11px; fill: var(--muted); font-variant-numeric: tabular-nums; }
svg.fig.progress .grid { stroke: var(--rule); stroke-width: 1; }
svg.fig.progress .kline { fill: none; stroke: var(--good); stroke-width: 2.4; }
svg.fig.progress .kdot { fill: var(--good); stroke: var(--bg); stroke-width: 1.5; }
svg.fig.progress .tline { fill: none; stroke-width: 2.2; }
svg.fig.progress .tline.total { stroke: var(--lean); }
svg.fig.progress .tline.lib { stroke: var(--mojo); stroke-dasharray: 5 3; }
svg.fig.progress .tdot.total { fill: var(--lean); stroke: var(--bg); stroke-width: 1.5; }
svg.fig.progress .tdot.lib { fill: var(--mojo); stroke: var(--bg); stroke-width: 1.5; }
svg.fig.progress .pt circle { transition: r .1s; }
svg.fig.progress .pt:hover circle { r: 6.5; }
.filters { display: flex; flex-wrap: wrap; align-items: center; gap: .35rem; margin: .5rem 0;
  font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; font-size: .85rem; }
.filters .flabel { color: var(--muted); margin-right: .3rem; min-width: 3.2rem; }
.filters input { position: absolute; opacity: 0; width: 1px; height: 1px; }
.filters label { padding: .2rem .7rem; border: 1px solid var(--rule); border-radius: 999px; cursor: pointer; }
.filters label:hover { border-color: var(--link); }
.filters input:checked + label { background: var(--link); border-color: var(--link); color: var(--bg); }
.filters input:focus-visible + label { outline: 2px solid var(--link); outline-offset: 2px; }
.cov-list:has(#st-proved:checked) tbody tr:not([data-st="proved"]),
.cov-list:has(#st-roadmap:checked) tbody tr:not([data-st="roadmap"]),
.cov-list:has(#st-none:checked) tbody tr:not([data-st="none"]) { display: none; }
'''
