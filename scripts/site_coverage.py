"""How much of Modular's GPU code is proved: the coverage figure, the progress figure and the coverage page.

The kernels are the ones roadmap/kernels/universe.tsv lists (scripts/kernel_universe.py universe, from Modular's
repository at a pinned commit). A kernel's status comes from the kernel cards: a card whose `ref` and `quote` name
the kernel's file and function gives it the card's level, and other kernels of that file whose names start with the
card's function are on the roadmap through the card. Levels L2 and up mean a proved specialization: the card's kernel
theorem (`Kernel.Sound`) is about the IR files of its `corpus`, compiled from the function's source at the revision
its `ref` names, which need not be the universe's. The page shows both revisions and the IR, and claims nothing about
the function's other specializations or about its source at the universe's revision.

The progress figure reads roadmap/kernels/levels.tsv and roadmap/kernels/theorems.tsv (scripts/kernel_universe.py
history) and adds the current tree's levels and theorem counts (`kernel_universe.count_theorems`: the `theorem` and
`lemma` declarations in the source, not the theorems commands generate), so it is never older than the site.

Like the home page's figures, these are inline SVG coloured by the stylesheet, with no JavaScript: marks are links,
hover is CSS, tooltips are SVG titles, and the page's filters are radio buttons read by CSS `:has()`.
"""
import datetime
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


def lvl(level: str) -> int:
    return int(str(level)[1:] or 0)


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
    out = []
    for r in rows:
        c = exact.get((r['path'], r['name']))
        if c:
            out.append((r, 'proved' if lvl(c['level']) >= 2 else 'roadmap', c, c['level']))
            continue
        fam = next((c for c in cards if c['fn'] and c['path'] and r['name'].startswith(c['fn'])
                    and r['path'].rsplit('/', 1)[0] == c['path'].rsplit('/', 1)[0]), None)
        out.append((r, 'roadmap', fam, None) if fam else (r, 'none', None, None))
    return commit, date, head, out, cards


def proved_at(c: dict, commit: str) -> str:
    """What a card's theorems are about, in words: the IR it names and the revision that IR was compiled from, with a
    note when that is not the universe's revision `commit`."""
    note = '' if commit.startswith(c['rev'] or '-') else \
        f"; the function at the inventory's revision {commit[:8]} is not checked"
    return f'proved for the IR in {c["corpus"]}, compiled at modular@{c["rev"]}{note}'


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
            what = (f'a proved specialization ({c["id"]}, {level}), {proved_at(c, commit)}' if s == 'proved' else
                    f'on the roadmap ({c["id"]})' if s == 'roadmap' else 'not started')
            href = card_href(prefix, c) if c else source_url(commit, r)
            cls = f'sq {s}' + (f' lv{lvl(level)}' if s == 'proved' else '')
            out.append(f'<a href="{esc(href)}" class="k"><title>{esc(r["name"])} ({esc(r["path"])}): {esc(what)}'
                       f'</title><rect class="{cls}" x="{x}" y="{yy}" width="{cell}" height="{cell}" rx="2.5" '
                       f'{sq_paint(s, level)}/></a>')
        y += max(nrows * pitch, 28) + 8
    ly = y + 6
    legend = [('sq proved lv4', ('proved', 'L4'), 'proved specialization, L4'),
              ('sq proved lv2', ('proved', 'L2'), 'proved specialization, L2 or L3'),
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


def _level_series(site, cards):
    """[(date, set of the cards of Modular's kernels with a proved specialization)]: the history of levels.tsv, then today's
    levels. MojoProof's own corpus kernels are left out, as in the coverage figure."""
    modular = {c['id'] for c in cards if c['modular']}
    level: dict[str, str] = {}
    steps = []
    for l in (site.root / 'roadmap' / 'kernels' / 'levels.tsv').read_text().split('\n'):
        if l and not l.startswith('#') and not l.startswith('time\t'):
            t, cid, lv = l.split('\t')
            level[cid] = lv
            steps.append((t[:10], {k for k, v in level.items() if lvl(v) >= 2 and k in modular}))
    now = {c['id'] for c in cards if lvl(c['level']) >= 2 and c['modular']}
    if not steps or steps[-1][1] != now:
        steps.append((_head_date(site), now))
    return steps


# Figure: progress over time, two panels on one day axis.
def progress_svg(site, fig_id: str) -> str:
    commit, date, head, st, cards = statuses(site)
    th = _theorem_series(site)
    lv = _level_series(site, cards)
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
    cur, path = set(), []
    for d in [x.isoformat() for x in days]:
        if d in by_day:
            cur = by_day[d]
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
        status = (f'<a href="{c["id"]}.html">{esc(c["id"])}</a>, {esc(level)}, {esc(proved_at(c, commit))}'
                  if stt == 'proved' else
                  f'<a href="{c["id"]}.html">{esc(c["id"])}</a>' if stt == 'roadmap' else '-')
        trs.append(f'<tr data-st="{stt}" data-area="{esc(r["area"])}"><td><a href="{esc(source_url(commit, r))}">'
                   f'<code>{esc(r["name"])}</code></a></td><td>{esc(r["area"])}</td>'
                   f'<td><code>{esc(r["path"])}:{r["line"]}</code></td><td class="num">{r["sites"]}</td>'
                   f'<td>{esc(STATUS_NAME[stt])}</td><td>{status}</td></tr>')
    own = ', '.join(f'<a href="{c["id"]}.html">{esc(c["id"])}</a>' for c in s['own'])
    revs = sorted({c['rev'] for _, stt, c, _ in st if stt == 'proved'})
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
<p>A proved specialization is a kernel theorem (<code>Kernel.Sound</code>, level L2 and up) about one compiled program
of the function: the IR of one choice of its element types and parameters, compiled from Modular's source at the
revision the card names ({revs_text}), {same}. It
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
specialization, by day, from the history of the cards' levels (MojoProof's own corpus kernels are not counted).
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
A function counts once however many launches name it. A function has a proved specialization when a card's
<code>ref</code> names its file and function and the card's level is L2 or more: the card's theorems are about the IR
its <code>corpus</code> names, compiled at the card's revision; the list above gives both. The match is by file and
function name, so it does not show that the function at this list's revision, or another specialization of it,
meets the theorem. Other functions of that file whose names start with the card's function are on the roadmap
through it.</p>
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
