"""The website's home page: what MojoProof is, Figure 1 (how it works), what is proved, Figures 2 and 3 (how much
of Modular's GPU code is proved, and the progress over time, from scripts/site_coverage.py), Figure 4 (the roadmap as
a map) and how to take part. Called by scripts/site.py; everything shown is read from the repository when the site is
built, so the page never says more than the code does.

The figures are inline SVG, coloured by the site's stylesheet (so they follow light and dark mode). Their only
text is part labels, a legend and per-mark tooltips; what they show is said in their numbered captions. They use no
JavaScript: shapes are links, hover is CSS, and the one moving part is an SVG animation that CSS hides for readers
who ask for reduced motion.
"""
import re
from html import escape

LEVELS = ['L0', 'L1', 'L2', 'L3', 'L4']
# The level colours on the light surface (one blue ramp, light to dark); the stylesheet swaps in the dark-mode steps.
LIGHT = ['#86b6ef', '#5598e7', '#2a78d6', '#1c5cab', '#104281']


def esc(s) -> str:
    return escape(str(s), quote=True)


def decl_url(site, path: str, name: str) -> str:
    """The GitHub URL of the line of `path` that declares `name` (the file if it is not found)."""
    text = (site.root / path).read_text() if (site.root / path).is_file() else ''
    short = name.split('.')[-1]
    for i, line in enumerate(text.split('\n'), 1):
        if re.match(rf'^\s*(?:@\[[^\]]*\]\s*)?(?:private |protected |noncomputable )*'
                    rf'(?:theorem|lemma|def|abbrev|structure|inductive)\s+(?:\S+\.)?{re.escape(short)}\b',
                    line) and (name in line or short in line):
            return f'{site.blob}{path}#L{i}'
    for i, line in enumerate(text.split('\n'), 1):
        if line.startswith(f'mojo_kernel {short} '):
            return f'{site.blob}{path}#L{i}'
    return f'{site.blob}{path}'


# Figure 1: the pipeline. Boxes: (key, x, y, w, label, sublabel, kind, link).
def pipeline_svg(site) -> str:
    W, H = 960, 330
    bw, bh = 170, 64
    boxes = [
        ('src', 20, 74, 'Mojo kernel', '.mojo', 'mojo', f'{site.tree}tests/corpus'),
        ('ir', 270, 74, 'LLVM IR', '.nvptx.ll', 'mojo', f'{site.tree}tests/corpus/vadd'),
        ('lean', 520, 74, 'Lean program', 'LLVM AST', 'lean', f'{site.tree}MojoProof/LLVM'),
        ('thm', 770, 74, 'Kernel theorem', 'Kernel.Sound', 'lean',
         decl_url(site, 'MojoProof/Kernels/Vadd.lean', 'vadd')),
        ('float', 270, 226, 'FloatLib', 'IEEE 754', 'lib', 'https://github.com/lean-dojo/FloatLib'),
        ('sem', 520, 226, 'Semantics', 'MojoProof.Sem', 'lean', f'{site.tree}MojoProof/Sem'),
        ('spec', 770, 226, 'Spec', 'TorchLean', 'lib', 'https://github.com/lean-dojo/TorchLean'),
    ]
    pos = {k: (x, y) for k, x, y, *_ in boxes}

    def right(k):
        x, y = pos[k]
        return x + bw, y + bh / 2

    def left(k):
        x, y = pos[k]
        return x, y + bh / 2

    def top(k, dx=bw / 2):
        x, y = pos[k]
        return x + dx, y

    def bottom(k, dx=bw / 2):
        x, y = pos[k]
        return x + dx, y + bh

    edges = [  # (from, to, label, main)
        (right('src'), left('ir'), 'mojo build --emit llvm', True),
        (right('ir'), left('lean'), 'mojo_import', True),
        (right('lean'), left('thm'), 'mojo_kernel', True),
        (right('float'), left('sem'), '', False),
        (top('sem', bw - 30), bottom('thm', 30), '', False),
        (top('spec'), bottom('thm'), '', False),
    ]
    out = [f'<svg class="fig pipeline" viewBox="0 0 {W} {H}" role="img" '
           f'aria-labelledby="fig1-title"><title id="fig1-title">How MojoProof works</title>',
           '<defs><marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
           'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" class="arrowhead" fill="#1f2023"/></marker></defs>']
    for (x1, y1), (x2, y2), label, main in edges:
        cls = 'edge main' if main else 'edge'
        out.append(f'<line class="{cls}" x1="{x1}" y1="{y1}" x2="{x2 - 3 if y1 == y2 else x2}" '
                   f'y2="{y2 if y1 == y2 else y2 + 3}" stroke="{"#1f2023" if main else "#5d5f66"}" '
                   f'stroke-width="{2 if main else 1.6}" marker-end="url(#arr)"/>')
        if label:
            out.append(f'<text class="edge-label" x="{(x1 + x2) / 2}" y="{pos["src"][1] - 14}" '
                       f'text-anchor="middle" fill="#5d5f66" font-size="12.5">{esc(label)}</text>')
    for key, x, y, label, sub, kind, href in boxes:
        fill, stroke = {'mojo': ('#fdf0ea', '#eb6834'), 'lean': ('#edf4fc', '#2a78d6'),
                        'lib': ('#fdfcf9', '#5d5f66')}[kind]
        out.append(f'<a href="{esc(href)}" class="node {kind}"><title>{esc(label)}: {esc(sub)}</title>'
                   f'<rect x="{x}" y="{y}" width="{bw}" height="{bh}" rx="10" fill="{fill}" stroke="{stroke}" '
                   f'stroke-width="1.6"' + (' stroke-dasharray="5 4"' if kind == 'lib' else '') + '/>'
                   f'<text class="node-label" x="{x + bw / 2}" y="{y + 28}" text-anchor="middle" fill="#1f2023" '
                   f'font-size="17" font-weight="600">{esc(label)}</text>'
                   f'<text class="node-sub" x="{x + bw / 2}" y="{y + 48}" text-anchor="middle" fill="#5d5f66" '
                   f'font-size="12.5">{esc(sub)}</text>'
                   '</a>')
    # a check mark on the theorem: its proof is checked by Lean's kernel
    tx, ty = pos['thm']
    out.append(f'<g class="check" transform="translate({tx + bw - 6},{ty - 6})"><circle r="13" fill="#0ca30c"/>'
               '<path d="M-6,0 L-1.5,5 L6.5,-5" fill="none" stroke="#ffffff" stroke-width="2.6" '
               'stroke-linecap="round" stroke-linejoin="round"/></g>')
    # one pulse travels the main path
    path = f'M{right("src")[0]},{right("src")[1]} L{left("thm")[0]},{left("thm")[1]}'
    out.append(f'<circle class="pulse" r="5" fill="#eb6834" opacity="0"><animateMotion dur="5s" '
               f'repeatCount="indefinite" path="{path}"/><animate attributeName="opacity" values="0;1;1;0" '
               'keyTimes="0;0.08;0.92;1" dur="5s" repeatCount="indefinite"/></circle>')
    out.append('</svg>')
    return ''.join(out)


# Figure 2: the roadmap as a map, one band per area, one square per card coloured by its level.
def roadmap_svg(site) -> str:
    per_row, cell, gap = 28, 17, 5
    pitch = cell + gap
    label_w = 196
    top = 14
    rows_out, y = [], top
    for a in site.areas:
        cards = a['cards']
        nrows = max(1, -(-len(cards) // per_row))
        band_h = nrows * pitch
        area_href = f'roadmap/{a["id"]}/index.html'
        rows_out.append(f'<a href="{area_href}" class="band-label"><text x="{label_w - 14}" '
                        f'y="{y + 13}" text-anchor="end" fill="#1f2023" font-size="13.5">{esc(a["title"] if len(a["title"]) < 28 else short_title(a))}</text></a>')
        for i, c in enumerate(cards):
            r, col = divmod(i, per_row)
            cx, cy = label_w + col * pitch, y + r * pitch
            lvl = c.get('level', 'L0')
            above = bool(c.get('evidence_present'))
            tip = f'{c["title"]} ({lvl}' + (', with evidence above its level' if above else '') + ')'
            rows_out.append(
                f'<a href="roadmap/{a["id"]}/{c["id"]}.html" class="card-sq"><title>{esc(tip)}</title>'
                f'<rect class="lv{lvl[1]}" x="{cx}" y="{cy}" width="{cell}" height="{cell}" rx="4" fill="{LIGHT[int(lvl[1])]}"/>' +
                (f'<circle class="above" cx="{cx + cell / 2}" cy="{cy + cell / 2}" r="2.6" fill="#ffffff"/>'
                 if above else '') +
                '</a>')
        y += band_h + 10
    # legend
    ly = y + 8
    legend = []
    lx = label_w
    for i, lv in enumerate(LEVELS):
        legend.append(f'<rect class="lv{i}" x="{lx}" y="{ly}" width="{cell}" height="{cell}" rx="4" '
                      f'fill="{LIGHT[i]}"/>'
                      f'<text class="legend" x="{lx + cell + 6}" y="{ly + 13}" fill="#5d5f66" '
                      f'font-size="12.5">{lv}</text>')
        lx += 66
    legend.append(f'<rect class="lv0" x="{lx + 14}" y="{ly}" width="{cell}" height="{cell}" rx="4" '
                  f'fill="{LIGHT[0]}"/>'
                  f'<circle class="above" cx="{lx + 14 + cell / 2}" cy="{ly + cell / 2}" r="2.6" fill="#ffffff"/>'
                  f'<text class="legend" x="{lx + 14 + cell + 6}" y="{ly + 13}" fill="#5d5f66" '
                  f'font-size="12.5">evidence above its level</text>')
    H = ly + cell + 10
    W = label_w + per_row * pitch
    return (f'<svg class="fig roadmap-map" viewBox="0 0 {W} {H}" role="img" aria-labelledby="fig2-title">'
            f'<title id="fig2-title">The roadmap, one square per card</title>' + ''.join(rows_out) +
            ''.join(legend) + '</svg>')


def short_title(a) -> str:
    return {'std-math': 'std.math functions', 'llvm-ir': 'LLVM IR constructs'}.get(a['id'], a['title'][:26])


def stats(site) -> list[tuple[int, str, str]]:
    ll = [f for f in site.files if f.startswith('tests/corpus/') and f.endswith('.ll')]
    lean = [f for f in site.files if f.startswith('MojoProof/') and f.endswith('.lean')]
    cards = sum(len(a['cards']) for a in site.areas)
    kernels = [c for a in site.areas if a['id'] == 'kernels' for c in a['cards']]
    # a kernel theorem is L2 evidence: count it whether the card has reached L2 or holds it above its level
    proved = [c for c in kernels if int(str(c.get('level', 'L0'))[1:] or 0) >= 2
              or any(lv in c.get('evidence_present', []) for lv in ('L2', 'L3', 'L4'))]
    found = site.root / 'docs' / 'found-bugs.md'
    filed = len(re.findall(r'^\| \[#\d+\]\(https://github\.com/modular/modular/issues/\d+\)', found.read_text(), re.M)) \
        if found.is_file() else 0
    import site_coverage
    cov = site_coverage.summary(site)
    return [(f'{cov["proved"]} of {cov["n"]}', "Modular's GPU kernels with a proved specialization",
             'roadmap/kernels/coverage.html'),
            (len(ll), 'compiled kernels in the corpus', f'{site.tree}tests/corpus'),
            (len(lean), 'Lean modules in the library', f'{site.tree}MojoProof'),
            (len(proved), 'kernels with a kernel theorem', 'roadmap/kernels/index.html'),
            (cards, 'roadmap cards', 'roadmap/index.html')] + \
           ([(filed, 'Mojo and MAX bugs filed', 'docs/found-bugs.html')] if filed else [])


def readme_section(site, heading: str) -> str:
    """The Markdown of the README section `## heading`, rendered as the site renders the README."""
    text = (site.root / 'README.md').read_text()
    m = re.search(rf'^## {re.escape(heading)}\n(.*?)(?=^## |\Z)', text, re.S | re.M)
    return site.render(m.group(1), 'README.md', 'index.html') if m else ''


RESULTS = [  # (title, scope, sentence, [(decl, path)])
    ('Schedule independence', 'every program',
     'From a memory whose pointers name only its own blocks, one run of a launch to its end with no fault, no '
     'data race and no broken invariant-load promise shows that every thread schedule of that launch is safe, race '
     'free, terminates and gives the same result.',
     [('Grid.confluent', 'MojoProof/Sem/Determinism.lean'), ('Grid.start_sound', 'MojoProof/Sem/Determinism.lean')]),
    ('A sound symbolic checker', 'every program',
     'A block, a path or a path to the kernel\'s return that the checker accepts runs as its summary says, '
     'whenever the path\'s conditions hold at its entry.',
     [('Block.sound', 'MojoProof/Sym/Block.lean')]),
    ('Elementwise kernels', 'a family',
     'A kernel with two input buffers, an output buffer and a count meets the kernel theorem when each thread '
     'takes a checked path, and each finite output cell below the count and the thread count is the float '
     'operation applied to the inputs\' cells.',
     [('Kernel.sound_map2', 'MojoProof/Sym/Kernel.lean'), ('Kernel.map2_real', 'MojoProof/Sym/Kernel.lean')]),
    ('Three kernels, end to end', 'three kernels',
     'vector_addition from max/examples, a vector multiply and a vector subtraction, each proved by one '
     'mojo_kernel command from its spec, with no proof lines written by hand.',
     [('vadd', 'MojoProof/Kernels/Vadd.lean'), ('vmul', 'MojoProof/Kernels/Vmul.lean'),
      ('vsub', 'MojoProof/Kernels/Vsub.lean')]),
    ('A kernel with a loop', 'one kernel',
     'Modular\'s naive matrix product meets the kernel theorem for every valid launch, size and input that meets '
     'the matmul precondition: each output cell inside the matrix holds the row-by-column dot loop. Its threads\' '
     'runs are proved by hand from the library\'s lemmas, not yet generated by mojo_kernel.',
     [('NaiveKernel.correct', 'MojoProofTest/NaiveKernel.lean')]),
]


def home_body(site) -> str:
    st = ''.join(f'<a class="stat" href="{esc(h)}"><span class="n">{n}</span><span class="what">{esc(w)}</span></a>'
                 for n, w, h in stats(site))
    results = []
    for title, scope, sentence, decls in RESULTS:
        links = ', '.join(f'<a href="{esc(decl_url(site, p, d))}"><code>{esc(d + (".correct" if "/Kernels/" in p else ""))}</code></a>'
                          for d, p in decls if (site.root / p).is_file())
        results.append(f'<div class="result"><h3>{esc(title)} <span class="scope">{esc(scope)}</span></h3>'
                       f'<p>{esc(sentence)}</p><p class="decls">{links}</p></div>')
    why_mojo = readme_section(site, 'Why Mojo')
    why_ver = readme_section(site, 'Why verification')
    import site_coverage
    cov = site_coverage.summary(site)
    return f'''
<section class="hero">
<h1>MojoProof</h1>
<p class="tagline">Machine-checked proofs for compiled Mojo GPU kernels, in Lean.</p>
<p class="byline">Robert Joseph George · Caltech</p>
<p class="buttons"><a class="button primary" href="{site.repo}">Code on GitHub</a>
<a class="button" href="roadmap/index.html">Roadmap</a>
<a class="button" href="guide/index.html">How to contribute</a></p>
</section>

<figure class="teaser">
{pipeline_svg(site)}
<figcaption><span class="fig">Figure 1.</span> How MojoProof works. The Mojo compiler writes one LLVM IR file per GPU
kernel; MojoProof imports it into Lean, where it has a semantics for threads, memory and floating point (IEEE 754
through FloatLib), and <code>mojo_kernel</code> proves the kernel theorem against a spec stated with TorchLean.
The check mark: every proof is checked by Lean's kernel. Click a box to see its code.</figcaption>
</figure>

<p class="abstract">MojoProof proves things about the code the Mojo compiler actually emits, for every input and
every launch of the shape a theorem states (one-dimensional, for the elementwise kernels), with floating point
modelled bit for bit. It lives outside the compiler, so Mojo itself doesn't
need to change, and every theorem says how far it reaches: every program, a family of kernels, or one kernel.</p>

<div class="stats">{st}</div>

<div class="why">
<section><h2 id="why-mojo">Why Mojo</h2>{why_mojo}</section>
<section><h2 id="why-verification">Why verification</h2>{why_ver}</section>
</div>

<h2 id="what-is-proved">What is proved today</h2>
<div class="results">{''.join(results)}</div>
<p class="note">Each result links to its Lean declaration. Every statement, with all its premises, is in
<a href="docs/proved.html">What is proved</a>, and what the proofs trust is in the
<a href="docs/trust.html">trusted base</a>.</p>

<h2 id="how-much-is-proved">How much is proved</h2>
<p>Modular's open-source code launches {cov["n"]} GPU kernel functions. {cov["proved"]} of them have a proved
specialization (a kernel theorem about one compiled program of the function, from the source at the revision its card
names), {cov["roadmap"]} more are on the roadmap, and {cov["none"]} are not started, so most of the work is ahead: the
tensor-core matmuls, attention, normalization, collectives and quantization.
<a href="roadmap/kernels/coverage.html">The coverage page</a> lists every kernel with its status.</p>
<figure class="map">
{site_coverage.coverage_svg(site, "", "fig2")}
<figcaption><span class="fig">Figure 2.</span> Modular's GPU kernels, one square per kernel function, grouped by area.
Filled squares have a proved specialization (the darkest, L4, also an IEEE error bound or exact bits), outlined ones are on
the roadmap, and grey ones are not started. Hover a square for its function and file, and click it to open its card
or its source.</figcaption>
</figure>
<figure class="map">
{site_coverage.progress_svg(site, "fig3")}
<figcaption><span class="fig">Figure 3.</span> Progress over time: (a) Modular's kernels with a proved specialization, by
day; (b) the <code>theorem</code> and <code>lemma</code> declarations in the source at the last commit of each day, in
the library and in the kernel and test programs (the theorems that commands generate are not counted). The
last day is the tree this site was built from. Hover a point for its numbers.</figcaption>
</figure>

<h2 id="roadmap">The roadmap</h2>
<figure class="map">
{roadmap_svg(site)}
<figcaption><span class="fig">Figure 4.</span> The roadmap, one square per card, grouped by area and coloured by
its level, from L0, a written card, to L4; the <a href="roadmap/index.html">roadmap page</a> says what each
level needs, for a kernel and for a construct. A dot marks a card that already has evidence for a level above its own, for example a kernel theorem
waiting for its recorded GPU run. Levels are computed from the code when the site is built. Hover a square for
its title and click it to open the card.</figcaption>
</figure>

<h2 id="get-involved">Get involved</h2>
<ol class="steps">
<li>Pick a card on the <a href="roadmap/index.html">roadmap</a> whose level can go up.</li>
<li>Follow <a href="guide/new-kernel.html">the guide</a>, or hand <a href="guide/agents.html">AGENTS.md</a> to your
coding agent. Specs are always checked by a human.</li>
<li>Open a pull request. CI checks it, and this site updates itself when it's merged.</li>
</ol>
<p>I'd love help, and I'd love to hear which kernels you want proved. Come say hi on the
<a href="{site.forum}">Modular forum</a> : )</p>
'''


CSS = '''
/* Home page */
section.hero { padding: 1.6rem 0 .6rem; }
section.hero h1 { font-size: 2.6rem; margin: 0 0 .3rem; letter-spacing: -.01em; }
.tagline { font-size: 1.25rem; margin: 0 0 .4rem; }
.byline { color: var(--muted); margin: 0 0 1rem; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; font-size: .95rem; }
.buttons { display: flex; flex-wrap: wrap; gap: .6rem; margin: 0 0 1.2rem; }
.button { font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; font-size: .92rem; padding: .45rem .95rem; border: 1px solid var(--rule); border-radius: 999px; text-decoration: none; color: var(--fg); transition: border-color .15s, background .15s; }
.button:hover { border-color: var(--link); color: var(--link); }
.button.primary { background: var(--link); border-color: var(--link); color: var(--bg); }
.button.primary:hover { filter: brightness(1.08); color: var(--bg); }
figure.teaser, figure.map { margin: 1.4rem 0 2rem; }
svg.fig { width: 100%; height: auto; display: block; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
.pipeline .node rect { stroke-width: 1.6; transition: stroke-width .15s, filter .15s; }
.pipeline .node:hover rect { stroke-width: 3; }
.pipeline .node.mojo rect { fill: var(--mojo-fill); stroke: var(--mojo); }
.pipeline .node.lean rect { fill: var(--lean-fill); stroke: var(--lean); }
.pipeline .node.lib rect { fill: var(--bg); stroke: var(--muted); stroke-dasharray: 5 4; }
.pipeline .node-label { font-size: 17px; font-weight: 600; fill: var(--fg); }
.pipeline .node-sub { font-size: 12.5px; fill: var(--muted); font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
.pipeline .edge { stroke: var(--muted); stroke-width: 1.6; }
.pipeline .edge.main { stroke: var(--fg); stroke-width: 2; }
.pipeline .arrowhead { fill: var(--fg); }
.pipeline .edge-label { font-size: 12.5px; fill: var(--muted); font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
.pipeline .check circle { fill: var(--good); }
.pipeline .check path { fill: none; stroke: #fff; stroke-width: 2.6; stroke-linecap: round; stroke-linejoin: round; }
.pipeline .pulse { fill: var(--mojo); }
@media (prefers-reduced-motion: reduce) { .pipeline .pulse { display: none; } }
.abstract { font-size: 1.12rem; }
.stats { display: flex; flex-wrap: wrap; gap: .8rem; margin: 1.6rem 0; }
.stat { flex: 1 1 8.5rem; min-width: 8.5rem; display: flex; flex-direction: column; padding: .8rem 1rem; border: 1px solid var(--rule); border-radius: 8px; text-decoration: none; color: var(--fg); transition: border-color .15s; }
.stat:hover { border-color: var(--link); }
.stat .n { font-size: 1.9rem; font-weight: 600; font-variant-numeric: tabular-nums; line-height: 1.1; }
.stat .what { font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; font-size: .85rem; color: var(--muted); line-height: 1.35; margin-top: .2rem; }
.why { display: grid; grid-template-columns: 1fr 1fr; gap: 0 2rem; }
.results { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin: 1rem 0; }
.result { border: 1px solid var(--rule); border-radius: 8px; padding: .2rem 1.1rem .4rem; }
.result h3 { margin: .9rem 0 .4rem; font-size: 1.08rem; }
.result p { margin: .45rem 0; }
.scope { font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; font-size: .72rem; font-weight: 600; text-transform: uppercase; letter-spacing: .04em; color: var(--lean, #2a78d6); border: 1px solid var(--lean, #2a78d6); border-radius: 999px; padding: .05rem .5rem; margin-left: .35rem; vertical-align: .15em; white-space: nowrap; }
.decls { font-size: .9rem; }
.roadmap-map .band-label text { font-size: 13.5px; fill: var(--fg); }
.roadmap-map .band-label:hover text { fill: var(--link); }
.roadmap-map .legend { font-size: 12.5px; fill: var(--muted); }
.roadmap-map .card-sq rect { stroke: var(--bg); stroke-width: 1.5; transition: stroke .1s; }
.roadmap-map .card-sq:hover rect { stroke: var(--fg); stroke-width: 2; }
.roadmap-map .above { fill: var(--bg); }
.lv0 { fill: var(--lv0); } .lv1 { fill: var(--lv1); } .lv2 { fill: var(--lv2); } .lv3 { fill: var(--lv3); } .lv4 { fill: var(--lv4); }
:root { --mojo: #eb6834; --mojo-fill: #fdf0ea; --lean: #2a78d6; --lean-fill: #edf4fc; --good: #0ca30c;
  --lv0: #86b6ef; --lv1: #5598e7; --lv2: #2a78d6; --lv3: #1c5cab; --lv4: #104281; }
@media (prefers-color-scheme: dark) {
  :root { --mojo: #d95926; --mojo-fill: #2a1d17; --lean: #3987e5; --lean-fill: #17222f; --good: #0ca30c;
    --lv0: #184f95; --lv1: #256abf; --lv2: #3987e5; --lv3: #6da7ec; --lv4: #9ec5f4; }
}
@media (max-width: 40rem) {
  section.hero h1 { font-size: 2.1rem; }
  .why, .results { grid-template-columns: 1fr; }
}
'''
