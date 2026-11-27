#!/usr/bin/env python3
"""site.py: the project's website, written from the repository's own files.

  python3 scripts/site.py --out <dir>     write the site into <dir>
  python3 scripts/site.py --check <dir>   check a written site; exit 1 on any problem

The pages:

* Home (index.html): README.md, then links to the other sections.
* Roadmap (roadmap/): the summary of roadmap/status.yaml; one page per area, its README.md and a
  table of its cards; one page per card, its front matter as a definition list and then its body;
  roadmap/README.md as roadmap/format.html. Levels, evidence and what the next level needs come
  only from roadmap/status.yaml and the card files, which scripts/roadmap_status.py computes from
  the code (run it first). If status.yaml names an area's README.md or a card file that does not
  exist, site.py prints each one and exits 1, writing nothing.
* Guide (guide/): how to contribute, docs/new-kernel.md, CONTRIBUTING.md and AGENTS.md.
* Docs (docs/): every other docs/*.md and every docs/proofs/*.md, and docs/graphs.html with
  docs/deps/{packages,modules,claims}.svg and roadmap/graph.svg as numbered figures.

A link between two Markdown files of the repository goes to the second one's page. A link to any
other file of the repository goes to that file on GitHub, and so does a code span or a path in the
text that names one; `<path>:<n>` goes to line <n>. docs/UPSTREAM.md is not published: it gets no
page and no link.

--check reads every written page and fails if an internal link or anchor does not resolve to a
written file, an image is missing, a page is empty, an external link is not a well-formed http(s)
URL, or there is any JavaScript (a .js file, a <script> element or an on* attribute).

The output depends only on the tracked files of the repository (`git ls-files`): it is sorted and
has no timestamps. Lean code is highlighted with Pygments' lean4 lexer into static HTML styled by
the one stylesheet, site.css. Needs markdown and pygments (scripts/site-requirements.txt).
"""
import argparse
import html
import pathlib
import posixpath
import re
import subprocess
import sys
import xml.etree.ElementTree as etree
from html.parser import HTMLParser
from urllib.parse import quote, unquote, urlsplit

import markdown
from markdown.extensions import Extension
from markdown.preprocessors import Preprocessor
from markdown.treeprocessors import Treeprocessor
from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_by_name
from pygments.util import ClassNotFound

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'scripts'))
sys.dont_write_bytecode = True
import roadmap_status as rs  # noqa: E402  (card front matter, evidence and the ladders)

REPO = 'https://github.com/Robertboy18/MojoProof'
BLOB = REPO + '/blob/main/'
TREE = REPO + '/tree/main/'
FORUM = 'https://forum.modular.com/'
UNPUBLISHED = {'docs/UPSTREAM.md'}
# Pages a link may name by another file: the status table is the roadmap's summary page.
ALIASES = {'roadmap/STATUS.md': 'roadmap/index.html'}
# The figures of docs/graphs.html, in order. An SVG larger than BIG is linked, not shown.
FIGURES = [
    ('docs/deps/packages.svg', 'The packages',
     'The packages MojoProof builds on, directly or through another package, each with the '
     'revision it is pinned at and how many of its modules the audit loads. An arrow is a '
     'require in a lakefile.'),
    ('docs/deps/modules.svg', 'The modules',
     'The modules of MojoProof and MojoProofTest, and the modules of other packages they import, '
     'grouped by package. An arrow goes from a module to a module it imports.'),
    ('docs/deps/claims.svg', 'The claims',
     'The headline theorems of scripts/targets.txt, one box per group of theorems that reach the '
     'same modules, packages, axioms and items of the trusted base. An arrow goes from a box to '
     'each module (ellipse), package (folder), axiom (diamond) and trusted item (octagon) it '
     'reaches.'),
    ('roadmap/graph.svg', 'The roadmap',
     'The roadmap at a glance: every card, grouped by area and labelled with its level. An arrow '
     'goes from a card to a card it depends on.'),
]
BIG = 500_000
# The order of docs/*.md on the Docs page; other files follow by name.
DOC_ORDER = ['docs/proved.md', 'docs/found-bugs.md', 'docs/TRUST.md', 'docs/kernel.md', 'docs/tactics.md', 'docs/automation.md',
             'docs/BUGS.md', 'docs/DEPENDENCIES.md']
NAV = [('home', 'Home', 'index.html'), ('roadmap', 'Roadmap', 'roadmap/index.html'),
       ('guide', 'Guide', 'guide/index.html'), ('docs', 'Docs', 'docs/index.html')]
WRITTEN = ('.html', '.css', '.svg')   # the kinds of file the site writes, and may remove

FENCE = re.compile(r'^( *)(`{3,}|~{3,})[ \t]*([\w+-]*)[^`]*$')
MARKER = re.compile(r'^([-*+]|\d{1,9}[.)])( +|$)')
CODE_PATH = re.compile(r'^([\w.\-/]+?)(?::(\d+)(?:-(\d+))?)?$')
TEXT_PATH = re.compile(
    r'(?<![\w/.\-])((?:(?:GPUProof|MojoProof|MojoProofTest|scripts|tests|docs|roadmap)/'
    r'[\w./\-]*[\w/])'
    r'|(?:README|CONTRIBUTING|AGENTS)\.md)(?::(\d+)(?:-(\d+))?)?')
EXTENSIONS = ('.md', '.lean', '.py', '.tsv', '.txt', '.mojo', '.ll', '.yaml', '.dot', '.svg',
              '.pdf', '.json', '.toml')
GH_REF = re.compile(r'^([\w.-]+/[\w.-]+)@([0-9a-f]{7,40}):([^:#\s]+)(?::(\d+))?$')
REPO_REF = re.compile(r'^repo:([^:\s]+)(?::(\d+))?$')


def rel(frm: str, to: str) -> str:
    """The relative URL of the site file `to` from the page `frm` (both site paths)."""
    return posixpath.relpath(to, posixpath.dirname(frm) or '.')


def esc(s: str) -> str:
    return html.escape(s, quote=True)


def inline(s: str) -> str:
    """One line of Markdown with code spans only, as HTML."""
    return re.sub(r'`([^`]+)`', r'<code>\1</code>', esc(s))


def plain(s: str) -> str:
    return s.replace('`', '')


def slug(text: str) -> str:
    """GitHub's heading anchor: lower case, punctuation dropped, spaces to hyphens."""
    return re.sub(r'[^\w\- ]', '', text.strip().lower()).replace(' ', '-')


def tracked() -> list[str]:
    try:
        out = subprocess.run(['git', '-C', str(ROOT), 'ls-files', '-z'], capture_output=True,
                             check=True, timeout=60).stdout.decode()
        files = [f for f in out.split('\0') if f]
    except (OSError, subprocess.SubprocessError):
        files = [p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*') if p.is_file()
                 and not any(x.startswith('.') or x == '_site' for x in p.relative_to(ROOT).parts)]
    return sorted(f for f in files if f not in UNPUBLISHED and (ROOT / f).is_file())


def code_block(code: str, lang: str) -> str:
    lang = {'lean': 'lean4'}.get(lang.lower(), lang.lower())
    try:
        lexer = get_lexer_by_name(lang) if lang else None
    except ClassNotFound:
        lexer = None
    if lexer is None:
        return f'<div class="highlight"><pre><code>{html.escape(code)}</code></pre></div>'
    return highlight(code, lexer, HtmlFormatter(cssclass='highlight', wrapcode=True)).strip()


def normalize(lines: list[str]) -> list[str]:
    """GitHub-style Markdown lists for Python-Markdown: each nested level indented by four spaces,
    and a blank line before a list item or a table in a block that does not start with one, and
    before a line less indented than the first line of its block (Python-Markdown would read
    either as part of the block's text). Fenced code keeps its indentation relative to its
    fence."""
    out: list[str] = []
    stack: list[tuple[int, int]] = []   # (content column in the source, in the output)
    fence = None                        # (closing fence pattern, indent offset) in fenced code
    start = None                        # the output indentation of the block's first line
    listed = False                      # whether that line is a list item

    def put(indent: int, body: str, item: bool):
        nonlocal start, listed
        if start is not None and (indent < start or item and not listed):
            out.append('')
            start = None
        if start is None:
            start, listed = indent, item
        out.append(' ' * indent + body)

    for line in lines:
        if fence:
            close, offset = fence
            ind = len(line) - len(line.lstrip(' '))
            out.append(' ' * max(0, ind + offset) + line.lstrip(' ') if line.strip() else '')
            if close.match(line):
                fence = None
            continue
        if not line.strip():
            out.append('')
            start = None
            continue
        blank = start is None
        ind = len(line) - len(line.lstrip(' '))
        body = line[ind:]
        m = MARKER.match(body)
        if (stack and ind < stack[-1][0] and not blank and not m
                and not body.startswith(('#', '|', '```', '~~~', '>'))):
            out.append(' ' * stack[-1][1] + body)   # a lazy continuation of the item's text
            continue
        while stack and ind < stack[-1][0]:
            stack.pop()
        src, dst = stack[-1] if stack else (0, 0)
        r = ind - src
        if m and r < 4:
            width = len(m.group(0)) if m.group(2) else len(m.group(1)) + 1
            stack.append((ind + width, dst + 4))
            put(dst, body, True)
        else:
            if body.startswith('|') and not blank and not out[-1].lstrip().startswith('|'):
                out.append('')
                start = None
            new = dst + r
            f = FENCE.match(line)
            if f:
                ch = re.escape(f.group(2)[0])
                fence = (re.compile(rf'^ *{ch}{{{len(f.group(2))},}}\s*$'), new - ind)
            put(new, body, False)
    return out


class Prep(Preprocessor):
    """Lists normalized, then each fenced code block highlighted and stashed as raw HTML."""

    def run(self, lines):
        lines = normalize(lines)
        out, i = [], 0
        while i < len(lines):
            f = FENCE.match(lines[i])
            if not f:
                out.append(lines[i])
                i += 1
                continue
            ind = len(f.group(1))
            ch = re.escape(f.group(2)[0])
            close = re.compile(rf'^ *{ch}{{{len(f.group(2))},}}\s*$')
            code, j = [], i + 1
            while j < len(lines) and not close.match(lines[j]):
                ln = lines[j]
                code.append(ln[ind:] if not ln[:ind].strip() else ln.lstrip(' '))
                j += 1
            placeholder = self.md.htmlStash.store(code_block('\n'.join(code) + '\n', f.group(3)))
            if out and out[-1].strip():
                out.append('')
            out += [' ' * ind + placeholder, '']
            i = j + 1
        return out


class Tree(Treeprocessor):
    """Heading anchors as GitHub makes them, links to pages or to GitHub, wrapped tables."""

    def __init__(self, md, site, src, page):
        super().__init__(md)
        self.site, self.src, self.page = site, src, page

    def run(self, root):
        seen: dict[str, int] = {}
        for el in root.iter():
            if el.tag in ('h1', 'h2', 'h3', 'h4', 'h5', 'h6'):
                s = slug(''.join(el.itertext()))
                n = seen.get(s, 0)
                seen[s] = n + 1
                el.set('id', s if n == 0 else f'{s}-{n}')
        self.walk(root, False)
        for parent in list(root.iter()):
            for k, child in enumerate(list(parent)):
                if child.tag == 'table':
                    div = etree.Element('div', {'class': 'table-wrap'})
                    div.tail, child.tail = child.tail, None
                    parent[k] = div
                    div.append(child)

    def walk(self, el, in_link):
        if el.tag == 'a':
            href = self.site.href(el.get('href', ''), self.src, self.page)
            if href is None:
                el.tag = 'span'
                el.attrib.pop('href', None)
            else:
                el.set('href', href)
            in_link = True
        if el.tag in ('pre', 'code'):
            return
        children = list(el)   # before the links made below, which need no walk
        if not in_link and el.text:
            head, links = self.split(el.text)
            if links:
                el.text = head
                for k, a in enumerate(links):
                    el.insert(k, a)
        for child in children:
            if child.tag == 'code' and not in_link:
                child = self.link_code(el, child)
            else:
                self.walk(child, in_link)
            if not in_link and child.tail:
                head, links = self.split(child.tail)
                if links:
                    child.tail = head
                    at = list(el).index(child) + 1
                    for k, a in enumerate(links):
                        el.insert(at + k, a)

    def link_code(self, parent, code):
        """Wrap a code span that names a file or directory of the repository in a link."""
        m = CODE_PATH.match(code.text or '')
        if not m or ('/' not in m.group(1) and not m.group(1).endswith(EXTENSIONS)):
            return code
        href = None
        for base in (posixpath.dirname(self.src), ''):
            target = posixpath.normpath(posixpath.join(base, m.group(1)))
            href = self.site.target(target, '', self.page, m.group(2), m.group(3), strict=True)
            if href:
                break
        if not href:
            return code
        a = etree.Element('a', {'href': href})
        a.tail, code.tail = code.tail, None
        parent[list(parent).index(code)] = a
        a.append(code)
        return a

    def split(self, text):
        """`text` up to its first path of the repository, and a link for each such path, each
        with the text after it as its tail."""
        links, head, last = [], None, 0
        for m in TEXT_PATH.finditer(text):
            href = self.site.target(posixpath.normpath(m.group(1)), '', self.page, m.group(2),
                                    m.group(3), strict=True)
            if not href:
                continue
            before = text[last:m.start()]
            if links:
                links[-1].tail = before
            else:
                head = before
            a = etree.Element('a', {'href': href})
            a.text = m.group(0)
            links.append(a)
            last = m.end()
        if links:
            links[-1].tail = text[last:]
        return head, links


class SiteExt(Extension):
    def __init__(self, site, src, page):
        super().__init__()
        self.site, self.src, self.page = site, src, page

    def extendMarkdown(self, md):
        md.preprocessors.deregister('html_block')   # raw HTML is shown as text
        md.inlinePatterns.deregister('html')
        md.preprocessors.register(Prep(md), 'site_prep', 25)
        md.treeprocessors.register(Tree(md, self.site, self.src, self.page), 'site_tree', -10)


def read_status() -> list[dict]:
    """roadmap/status.yaml, as scripts/roadmap_status.py writes it: the areas, each with its
    cards."""
    def value(v: str):
        v = v.strip()
        if v.startswith('"'):
            return re.sub(r'\\(.)', r'\1', v[1:-1])
        if v.startswith('['):
            return [x.strip() for x in v[1:-1].split(',') if x.strip()]
        if v.startswith('{'):   # counts, or quoted texts that may hold commas
            return {k: value(x) for k, x in
                    re.findall(r'(\w+):\s*("(?:[^"\\]|\\.)*"|[^,}]+)', v[1:-1])}
        return int(v) if v.isdigit() else v

    areas: list[dict] = []
    for line in (ROOT / 'roadmap' / 'status.yaml').read_text().split('\n'):
        m = re.match(r'^( *)(- )?([a-z_]+):(.*)$', line)
        if not m or m.group(3) == 'areas':
            continue
        ind, dash, key, v = len(m.group(1)), m.group(2), m.group(3), m.group(4)
        if ind == 2 and dash:
            areas.append({'cards': []})
        elif ind == 6 and dash:
            areas[-1]['cards'].append({})
        if key == 'cards' and ind == 4:
            continue
        (areas[-1] if ind < 6 else areas[-1]['cards'][-1])[key] = value(v)
    return areas


class Site:
    def __init__(self):
        self.files = set(tracked())
        self.dirs = {posixpath.dirname(f) for f in self.files}
        for d in list(self.dirs):
            while d:
                self.dirs.add(d)
                d = posixpath.dirname(d)
        self.dirs.discard('')
        self.areas = read_status()
        self.pages: dict[str, tuple[str, str, str, str]] = {}   # page: title, section, body, source
        self.md_page: dict[str, str] = {
            'README.md': 'index.html', 'CONTRIBUTING.md': 'guide/contributing.html',
            'AGENTS.md': 'guide/agents.html', 'docs/new-kernel.md': 'guide/new-kernel.html',
            'roadmap/README.md': 'roadmap/format.html'}
        for f in sorted(self.files):
            if re.fullmatch(r'docs/[^/]+\.md', f) and f not in self.md_page:
                self.md_page[f] = 'docs/' + posixpath.basename(f)[:-3].lower() + '.html'
            elif re.fullmatch(r'docs/proofs/[^/]+\.md', f):
                stem = posixpath.basename(f)[:-3]
                self.md_page[f] = f'docs/proofs/{"overview" if stem == "README" else stem}.html'
        for a in self.areas:
            self.md_page[f'roadmap/{a["id"]}/README.md'] = f'roadmap/{a["id"]}/index.html'
            for c in a['cards']:
                self.md_page[f'roadmap/{a["id"]}/cards/{c["id"]}.md'] = \
                    f'roadmap/{a["id"]}/{c["id"]}.html'
        outs = list(self.md_page.values()) + ['roadmap/index.html', 'guide/index.html',
                                              'docs/index.html', 'docs/graphs.html',
                                              'roadmap/kernels/coverage.html']
        dup = sorted({o for o in outs if outs.count(o) > 1})
        if dup:
            raise SystemExit(f'two sources for the pages {", ".join(dup)}')
        self.assets = {f: f for f, _, _ in FIGURES if f in self.files}

    # Links.

    def href(self, href: str, src: str, page: str) -> str | None:
        """A link of the Markdown file `src`, as a link of `page`; None to drop it."""
        if not href or href.startswith('#') or re.match(r'^[a-zA-Z][\w+.-]*:', href):
            return href
        path, _, frag = href.partition('#')
        target = posixpath.normpath(posixpath.join(posixpath.dirname(src), unquote(path)))
        m = re.fullmatch(r'(.+?):(\d+)(?:-(\d+))?', target)
        if m and m.group(1) in self.files:
            return self.target(m.group(1), frag, page, m.group(2), m.group(3))
        return self.target(target, frag, page)

    def target(self, target: str, frag: str, page: str, line=None, end=None,
               strict=False) -> str | None:
        """The URL of the repository path `target` from `page`: its page, its copy in the site, or
        the file or directory on GitHub. None for an unpublished file, and with `strict` for a
        path that is not in the repository."""
        if target in UNPUBLISHED:
            return None
        frag = '#' + frag if frag else ''
        if target in self.md_page or target in ALIASES:
            return rel(page, self.md_page.get(target) or ALIASES[target]) + frag
        if target in self.assets and not line:
            return rel(page, self.assets[target]) + frag
        if target in self.files:
            if line:
                frag = f'#L{line}' + (f'-L{end}' if end else '')
            return BLOB + quote(target) + frag
        if target in self.dirs and not line:
            return TREE + quote(target)
        return None if strict else target

    # Pages.

    def render(self, text: str, src: str, page: str) -> str:
        md = markdown.Markdown(extensions=['tables', 'sane_lists', SiteExt(self, src, page)])
        return md.convert(text)

    def add(self, page: str, title: str, section: str, body: str, source: str):
        self.pages[page] = (title, section, body, source)

    def add_md(self, src: str, section: str, before: str = '', after: str = ''):
        page = self.md_page[src]
        body = self.render((ROOT / src).read_text(), src, page)
        self.add(page, plain(self.title_of(src)), section, before + body + after, src)

    def title_of(self, src: str) -> str:
        """The text of the Markdown file's first `# ` heading."""
        text = (ROOT / src).read_text()
        return next((ln[2:] for ln in text.split('\n') if ln.startswith('# ')), src)

    def build(self):
        self.home()
        self.roadmap()
        self.guide()
        self.docs()

    def home(self):
        """The home page: scripts/site_home.py."""
        import site_home
        self.root, self.blob, self.tree, self.repo, self.forum = ROOT, BLOB, TREE, REPO, FORUM
        self.add('index.html', 'MojoProof', 'home', site_home.home_body(self), 'scripts/site_home.py')

    def roadmap(self):
        page = 'roadmap/index.html'
        cards = {f'{a["id"]}/{c["id"]}': (a, c) for a in self.areas for c in a['cards']}
        named = [f'roadmap/{a["id"]}/README.md' for a in self.areas] + \
            [f'roadmap/{a["id"]}/cards/{c["id"]}.md' for a, c in cards.values()]
        if missing := [f for f in named if not (ROOT / f).is_file()]:
            raise Stale(missing)
        runs = set()
        fronts = {}
        for key, (a, c) in cards.items():
            keys, body = rs.front_matter((ROOT / 'roadmap' / a['id'] / 'cards' /
                                          f'{c["id"]}.md').read_text())
            ev = rs.parse_evidence(keys.get('evidence', ''))
            runs |= set(ev.get(rs.GPU_LEVEL[keys['kind']], []))
            fronts[key] = (keys, body, ev)
        rows = []
        total = [0] * 6
        for a in self.areas:
            counts = [len(a['cards'])] + [a['levels'].get(f'L{i}', 0) for i in range(5)]
            total = [x + y for x, y in zip(total, counts)]
            rows.append(f'<tr><td><a href="{a["id"]}/index.html">{esc(a["title"])}</a></td>' +
                        ''.join(f'<td class="num">{n}</td>' for n in counts) + '</tr>')
        rows.append('<tr class="total"><td>All areas</td>' +
                    ''.join(f'<td class="num">{n}</td>' for n in total) + '</tr>')
        ladders = []
        for kind, ladder in sorted(rs.LADDER.items()):
            ladders.append(f'<h3 id="the-{kind}-ladder">The {kind} ladder</h3>\n'
                           '<div class="table-wrap"><table><thead><tr><th>Level</th>'
                           '<th>Meaning</th><th>Evidence</th></tr></thead><tbody>' +
                           ''.join(f'<tr><td class="level">{lv}</td><td>{esc(m)}</td>'
                                   f'<td>{esc(e)}</td></tr>' for lv, m, e in ladder) +
                           '</tbody></table></div>')
        levels = ''.join(f'<th class="num">L{i}</th>' for i in range(5))
        n_runs = len(runs)
        runs_line = (f'Records of GPU runs the cards cite: {n_runs}.' if n_runs else
                     'No card cites a record of a GPU run yet. Kernel L1 and construct L2 need '
                     'one, so for now no kernel card is past L0 and no construct card is past '
                     'L1; each card lists the evidence it already has above its level.')
        body = f'''<h1>Roadmap</h1>
<p>This is what MojoProof means to prove, one card per item, and how far each item has come so
far. The levels are computed from the code by
<a href="{BLOB}scripts/roadmap_status.py"><code>scripts/roadmap_status.py</code></a>, not written
by hand, so nothing on this page is a promise : )</p>
<p>Want to help? Pick a card whose level can go up, and <a href="../guide/index.html">How to
contribute</a> says the rest. <a href="format.html">How the roadmap works</a> explains the cards
and the levels, and <a href="../docs/graphs.html#figure-4">Figure 4</a> draws every card with its
dependencies.</p>
<h2 id="summary">Summary</h2>
<p>Cards per area, by level.</p>
<div class="table-wrap"><table><thead><tr><th>Area</th><th class="num">Cards</th>{levels}</tr></thead>
<tbody>{"".join(rows)}</tbody></table></div>
<p>{esc(runs_line)}</p>
<h2 id="the-levels">The levels</h2>
<p>A card's level is the highest level whose evidence is present together with the evidence of
every level below it.</p>
{"".join(ladders)}'''
        self.add(page, 'Roadmap', 'roadmap', body, 'roadmap/status.yaml')
        self.add_md('roadmap/README.md', 'roadmap',
                    before='<p class="crumbs"><a href="index.html">Roadmap</a></p>')
        for a in self.areas:
            self.area(a, fronts)
            for c in a['cards']:
                self.card(a, c, fronts[f'{a["id"]}/{c["id"]}'], cards)
        import site_coverage
        self.add('roadmap/kernels/coverage.html', "How much of Modular's GPU code is proved", 'roadmap',
                 site_coverage.coverage_page(self), 'scripts/site_coverage.py')

    def area(self, a: dict, fronts: dict):
        src = f'roadmap/{a["id"]}/README.md'
        rows = []
        for c in a['cards']:
            present = ', '.join(c['evidence_present']) or '-'
            rows.append(f'<tr><td><a href="{c["id"]}.html">{esc(c["id"])}</a>: '
                        f'{inline(fronts[a["id"] + "/" + c["id"]][0]["title"])}</td>'
                        f'<td>{esc(c["kind"])}</td><td class="level">{esc(c["level"])}</td>'
                        f'<td>{esc(present)}</td><td>{esc(c["next"])}</td>'
                        f'<td class="num">{c["corpus_kernels"]}</td></tr>')
        table = ('<h2 id="status-of-the-cards">Status of the cards</h2>\n'
                 f'<p>From <a href="{BLOB}roadmap/status.yaml"><code>roadmap/status.yaml</code></a>, '
                 'which the roadmap script writes from the code.</p>\n'
                 '<div class="table-wrap"><table><thead><tr><th>Card</th><th>Kind</th>'
                 '<th>Level</th><th>Evidence above the level</th><th>Next</th>'
                 '<th class="num">Corpus kernels</th></tr></thead><tbody>' + ''.join(rows) +
                 '</tbody></table></div>' if rows else
                 '<p>No cards in this area yet.</p>')
        if a['id'] == 'kernels':
            import site_coverage
            s = site_coverage.summary(self)
            table = (f'<p>These cards are a start: Modular\'s open-source code launches {s["n"]} GPU kernel functions, '
                     f'and {s["proved"]} of them have a proved specialization. <a href="coverage.html">How much of '
                     'Modular\'s GPU code is proved</a> lists every one with its status.</p>\n') + table
        self.add_md(src, 'roadmap', before='<p class="crumbs"><a href="../index.html">Roadmap</a>'
                    '</p>', after=table)

    def card(self, a: dict, c: dict, front, cards: dict):
        keys, body, ev = front
        page = self.md_page[f'roadmap/{a["id"]}/cards/{c["id"]}.md']
        src = f'roadmap/{a["id"]}/cards/{c["id"]}.md'
        lines = body.lstrip('\n').split('\n')
        h1 = keys['title']
        if lines and lines[0].startswith('# '):
            h1, lines = lines[0][2:], lines[1:]
        kind = keys['kind']

        def code_list(names, empty):
            if not names:
                return f'<span class="none">{empty}</span>'
            return '<ul>' + ''.join(f'<li><code>{esc(n)}</code></li>' for n in names) + '</ul>'

        def card_link(key):
            area, cid = key.split('/')
            url = rel(page, self.md_page[f'roadmap/{area}/cards/{cid}.md'])
            return f'<a href="{esc(url)}">{esc(key)}</a>'

        def resolve(ref):
            if '/' in ref:
                return ref if ref in cards else None
            if f'{a["id"]}/{ref}' in cards:
                return f'{a["id"]}/{ref}'
            same = [k for k in cards if k.split('/')[1] == ref]
            return same[0] if len(same) == 1 else None

        ref = keys['ref']
        if m := GH_REF.match(ref):
            url = f'https://github.com/{m.group(1)}/blob/{m.group(2)}/{quote(m.group(3))}' + \
                (f'#L{m.group(4)}' if m.group(4) else '')
            ref_html = f'<a href="{esc(url)}"><code>{esc(ref)}</code></a>'
        elif (m := REPO_REF.match(ref)) and m.group(1) in self.files:
            url = self.target(m.group(1), '', page, m.group(2))
            ref_html = f'<a href="{esc(url)}"><code>{esc(ref)}</code></a>'
        else:
            ref_html = f'<code>{esc(ref)}</code>'
        q = keys['quote']
        quote_text = q[1:-1].replace('\\"', '"').replace('\\\\', '\\') if len(q) >= 2 else ''
        quote_html = (f'<blockquote class="quote">{esc(quote_text)}</blockquote>' if quote_text
                      else '<span class="none">No quote yet.</span>')
        lean = [] if keys['lean'] == rs.NONE['lean'] else rs.items(keys['lean'])
        tests = [] if keys['tests'] == rs.NONE['tests'] else rs.items(keys['tests'])
        corpus = [] if keys['corpus'] == rs.NONE['corpus'] else rs.items(keys['corpus'])
        corpus_items = []
        for p in corpus:
            base = p.split('*')[0].rstrip('/') if '*' in p else p.rstrip('/')
            if '*' in p:
                base = posixpath.dirname(base) if base not in self.dirs else base
            url = self.target(base, '', page, strict=True)
            corpus_items.append(f'<li><a href="{esc(url)}"><code>{esc(p)}</code></a></li>' if url
                                else f'<li><code>{esc(p)}</code></li>')
        corpus_html = ('<ul>' + ''.join(corpus_items) + '</ul>' if corpus_items else
                       '<span class="none">None yet.</span>')
        n = c['corpus_kernels']
        corpus_html += (f'<p class="note">{n} kernel file{"" if n == 1 else "s"} '
                        '(<code>.ll</code>) in the corpus.</p>')
        up = keys['upstream']
        if up.startswith('http'):
            up_html = f'<a href="{esc(up)}">{esc(up)}</a>'
        elif up:
            up_html = esc(up)
        else:
            up_html = '<span class="none">None filed.</span>'
        deps = c['depends']
        deps_html = (', '.join(card_link(d) for d in deps) if deps else
                     '<span class="none">No other card.</span>')
        ev_items = []
        for lv, its in sorted(ev.items()):
            if lv == rs.GPU_LEVEL[kind]:
                shown = [f'<a href="{esc(self.target(p, "", page) or p)}"><code>{esc(p)}</code></a>'
                         for p in its]
            elif kind == 'construct' and lv == 'L3':
                shown = [card_link(k) if (k := resolve(i)) else esc(i) for i in its]
            else:
                shown = [f'<code>{esc(i)}</code>' for i in its]
            ev_items.append(f'<li>{lv}: {", ".join(shown)}</li>')
        present = c['evidence_present']
        present_html = (esc(', '.join(present)) + ' <span class="note">(shown, not counted, '
                        'until the levels below have their evidence)</span>' if present else
                        '<span class="none">None above the level.</span>')
        level_html = (f'<span class="level">{esc(c["level"])}</span> '
                      f'({esc(rs_meaning(kind, c["level"]))}). Next: {esc(c["next"])}.'
                      if c['next'] != 'top level' else
                      f'<span class="level">{esc(c["level"])}</span>, the top level.')
        dl = [('Area', f'<a href="index.html">{esc(a["title"])}</a>'),
              ('Kind', esc(kind)),
              ('Level', level_html),
              ('Evidence present above the level', present_html)]
        if ev_items:
            dl.append(('Evidence', '<ul>' + ''.join(ev_items) + '</ul>'))
        if c.get('evidence_scope'):
            dl.append(('Scope of the cited theorems', '<ul>' + ''.join(
                f'<li>{lv}: {esc(sc)}</li>' for lv, sc in sorted(c['evidence_scope'].items()))
                + '</ul>'))
        dl += [('Reference', ref_html), ('Quote', quote_html),
               ('Lean declarations', code_list(lean, 'Not stated yet.')),
               ('Corpus files', corpus_html),
               ('Tests', code_list(tests, 'None yet.')),
               ('Upstream issue', up_html),
               ('Depends on', deps_html)]
        head = (f'<p class="crumbs"><a href="../index.html">Roadmap</a> / '
                f'<a href="index.html">{esc(a["title"])}</a></p>\n'
                f'<h1>{inline(h1)}</h1>\n' +
                (f'<p class="lede">{inline(keys["title"])}</p>\n' if h1 != keys['title'] else '') +
                '<dl class="card">' + ''.join(f'<dt>{k}</dt><dd>{v}</dd>' for k, v in dl) +
                '</dl>\n')
        self.add(page, plain(h1), 'roadmap', head + self.render('\n'.join(lines), src, page), src)

    def guide(self):
        body = f'''<h1>How to contribute</h1>
<p>I'd love help with MojoProof! Changes of every size are welcome, and here is how it works.</p>
<ol class="steps">
<li><strong>Pick a card.</strong> Find a card on the <a href="../roadmap/index.html">roadmap</a>
whose level can go up.</li>
<li><strong>Follow the guide.</strong> <a href="new-kernel.html">Proving a new kernel</a> takes one
kernel from its Mojo source to its theorem, and <a href="contributing.html">Contributing</a> says
how to build, test and check a change. Or hand <a href="agents.html">AGENTS.md</a> to your coding
agent.</li>
<li><strong>Open a pull request</strong> on <a href="{REPO}/pulls">GitHub</a>.</li>
<li><strong>CI checks it.</strong> It runs the build, the tests and the audit on your pull
request, and the site updates itself when it's merged.</li>
</ol>
<p>If you get stuck, <a href="{REPO}/issues">open an issue</a> and I'll help : )</p>
<h2 id="the-guide">The guide</h2>
<ul>
<li><a href="new-kernel.html">{inline(self.title_of("docs/new-kernel.md"))}</a></li>
<li><a href="contributing.html">{inline(self.title_of("CONTRIBUTING.md"))}</a></li>
<li><a href="agents.html">{inline(self.title_of("AGENTS.md"))}</a></li>
</ul>'''
        self.add('guide/index.html', 'How to contribute', 'guide', body, 'scripts/site.py')
        crumbs = '<p class="crumbs"><a href="index.html">Guide</a></p>'
        for src in ('docs/new-kernel.md', 'CONTRIBUTING.md', 'AGENTS.md'):
            self.add_md(src, 'guide', before=crumbs)

    def docs(self):
        docs = sorted((f for f in self.md_page if re.fullmatch(r'docs/[^/]+\.md', f)
                       and f != 'docs/new-kernel.md'),
                      key=lambda f: (DOC_ORDER.index(f) if f in DOC_ORDER else len(DOC_ORDER), f))
        proofs = sorted((f for f in self.md_page if f.startswith('docs/proofs/')),
                        key=lambda f: (not f.endswith('/README.md'), f))
        for f in docs:
            self.add_md(f, 'docs', before='<p class="crumbs"><a href="index.html">Docs</a></p>')
        for f in proofs:
            self.add_md(f, 'docs', before='<p class="crumbs"><a href="../index.html">Docs</a> / '
                        '<a href="overview.html">Proofs</a></p>')

        def item(f):
            return (f'<li><a href="{rel("docs/index.html", self.md_page[f])}">'
                    f'{inline(self.title_of(f))}</a></li>')

        figs = ''.join(f'<li><a href="graphs.html#figure-{k}">Figure {k}</a>: {esc(t)}</li>'
                       for k, (f, t, _) in enumerate(FIGURES, 1) if f in self.assets)
        body = f'''<h1>Docs</h1>
<p>The project's documents, rendered from the repository. If something here is unclear, that's
a bug in the docs, and I'd be glad to hear about it.</p>
<h2 id="start-here">Start here</h2>
<ul>{item("docs/new-kernel.md")}{item("roadmap/README.md")}</ul>
<h2 id="reference">Reference</h2>
<ul>{"".join(item(f) for f in docs)}</ul>
<h2 id="proofs">Proofs written out</h2>
<p>Each document gives the informal proof of one family of theorems, with its premises and scope.
The Lean statement is the reference.</p>
<ul>{"".join(item(f) for f in proofs)}</ul>
<h2 id="graphs">Graphs</h2>
<ul>{figs}</ul>'''
        self.add('docs/index.html', 'Docs', 'docs', body, 'scripts/site.py')
        self.graphs()

    def graphs(self):
        page = 'docs/graphs.html'
        out = ['<p class="crumbs"><a href="index.html">Docs</a></p>', '<h1>Graphs</h1>',
               '<p>Four pictures of the project. The first three are drawn from the audit; '
               f'<a href="{rel(page, self.md_page["docs/DEPENDENCIES.md"])}">Dependencies</a> '
               'has the same facts as tables. The last one is the roadmap. Click a figure to open '
               'it at full size.</p>']
        for k, (f, title, caption) in enumerate(FIGURES, 1):
            if f not in self.assets:
                continue
            url = rel(page, self.assets[f])
            size = (ROOT / f).stat().st_size
            if size > BIG:
                shown = (f'<p class="big"><a href="{url}">Open {title.lower()} graph</a> '
                         f'(SVG, {size / 1e6:.1f} MB, too large to show on this page).</p>')
            else:
                shown = f'<a href="{url}"><img src="{url}" alt="{esc(title)} graph"></a>'
            out.append(f'<figure id="figure-{k}">\n{shown}\n<figcaption><span class="fig">Figure '
                       f'{k}.</span> {esc(caption)}</figcaption>\n</figure>')
        self.add(page, 'Graphs', 'docs', '\n'.join(out), 'scripts/site.py')

    # Output.

    def html_page(self, page: str, title: str, section: str, body: str, source: str) -> str:
        up = '../' * page.count('/')
        nav = ''.join(f'<li><a href="{up}{href}"' + (' aria-current="page"' if key == section
                                                      else '') + f'>{name}</a></li>'
                      for key, name, href in NAV)
        full = 'MojoProof' if page == 'index.html' else f'{esc(title)} | MojoProof'
        return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{full}</title>
<link rel="stylesheet" href="{up}site.css">
</head>
<body>
<header class="site"><nav><a class="brand" href="{up}index.html">MojoProof</a>
<ul>{nav}<li><a href="{REPO}">GitHub</a></li></ul></nav></header>
<main>
{body}
</main>
<footer class="site"><p>Made with Lean and a lot of Mojo love by Robert.
<a href="{BLOB}{quote(source)}">Source of this page</a>.</p></footer>
</body>
</html>
'''

    def write(self, out: pathlib.Path):
        written = {}
        for page, (title, section, body, source) in sorted(self.pages.items()):
            written[page] = self.html_page(page, title, section, body, source).encode()
        written['site.css'] = css().encode()
        for f, dest in sorted(self.assets.items()):
            written[dest] = (ROOT / f).read_bytes()
        for path, data in written.items():
            p = out / path
            p.parent.mkdir(parents=True, exist_ok=True)
            if not p.is_file() or p.read_bytes() != data:
                p.write_bytes(data)
        for p in sorted(out.rglob('*'), reverse=True):
            name = p.relative_to(out).as_posix()
            if p.is_file() and p.suffix in WRITTEN and name not in written:
                p.unlink()
            elif p.is_dir() and not any(p.iterdir()):
                p.rmdir()
        return written


def rs_meaning(kind: str, level: str) -> str:
    return next(m for lv, m, _ in rs.LADDER[kind] if lv == level)


STYLE = '''
:root {
  color-scheme: light dark;
  --fg: #1f2023; --muted: #5d5f66; --bg: #fdfcf9; --rule: #dcdad3; --link: #1d5aa8;
  --code-bg: #f3f1ec; --head-bg: #f4f2ed; --fig-bg: #ffffff;
}
@media (prefers-color-scheme: dark) {
  :root {
    --fg: #e4e2dd; --muted: #a6a49e; --bg: #16171a; --rule: #393b40; --link: #8db7f5;
    --code-bg: #212226; --head-bg: #1f2024; --fig-bg: #f4f3ef;
  }
}
* { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%; text-size-adjust: 100%; }
body {
  margin: 0; background: var(--bg); color: var(--fg); line-height: 1.6; font-size: 1.0625rem;
  font-family: "Iowan Old Style", "Palatino Linotype", Palatino, "Book Antiqua", Georgia,
    "Times New Roman", serif;
}
header.site, main, footer.site { max-width: 50rem; margin: 0 auto; padding-left: 1.25rem; padding-right: 1.25rem; }
header.site nav, .crumbs, table, figcaption, footer.site, dl.card dt {
  font-family: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
}
header.site { border-bottom: 1px solid var(--rule); }
header.site nav { display: flex; flex-wrap: wrap; align-items: baseline; gap: .3rem 1.5rem; padding: .9rem 0; font-size: .95rem; }
header.site .brand { font-weight: 700; color: var(--fg); text-decoration: none; margin-right: auto; }
header.site ul { list-style: none; margin: 0; padding: 0; display: flex; flex-wrap: wrap; gap: .3rem 1.2rem; }
header.site ul a { color: var(--fg); text-decoration: none; padding-bottom: .1rem; }
header.site ul a:hover { color: var(--link); }
header.site ul a[aria-current="page"] { color: var(--link); border-bottom: 2px solid var(--link); }
main { padding-top: 1.25rem; padding-bottom: 3rem; }
h1, h2, h3, h4, h5, h6 { line-height: 1.25; font-weight: 600; }
h1 { font-size: 2rem; margin: .4rem 0 1rem; }
h2 { font-size: 1.45rem; margin: 2.2rem 0 .8rem; padding-bottom: .25rem; border-bottom: 1px solid var(--rule); }
h3 { font-size: 1.2rem; margin: 1.8rem 0 .6rem; }
h4, h5, h6 { font-size: 1.05rem; margin: 1.5rem 0 .5rem; }
a { color: var(--link); text-underline-offset: 2px; }
p, ul, ol, dl, blockquote { margin: .8rem 0; }
li { margin: .2rem 0; }
li > ul, li > ol { margin: .2rem 0; }
code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "DejaVu Sans Mono", "Liberation Mono", monospace; font-size: .86em; }
:not(pre) > code { background: var(--code-bg); padding: .06em .3em; border-radius: 3px; overflow-wrap: anywhere; }
a > code { color: var(--link); }
pre { padding: .8rem 1rem; overflow-x: auto; border-radius: 4px; line-height: 1.45; margin: 1rem 0; }
.highlight, .highlight pre { background: var(--code-bg); }
.highlight { border-radius: 4px; margin: 1rem 0; }
.highlight pre { margin: 0; }
blockquote { padding: .1rem 1rem; border-left: 3px solid var(--rule); color: var(--muted); }
blockquote.quote { margin: 0; color: var(--fg); font-style: italic; }
hr { border: 0; border-top: 1px solid var(--rule); margin: 2rem 0; }
.table-wrap { overflow-x: auto; margin: 1rem 0; }
table { border-collapse: collapse; font-size: .88rem; line-height: 1.45; }
th, td { border-bottom: 1px solid var(--rule); padding: .4rem .65rem; text-align: left; vertical-align: top; }
th { background: var(--head-bg); font-weight: 600; border-bottom: 2px solid var(--rule); }
td code, th code { font-size: .92em; }
.num { text-align: right; font-variant-numeric: tabular-nums; }
tr.total td { font-weight: 600; }
.level { font-variant-numeric: tabular-nums; white-space: nowrap; font-weight: 600; }
.crumbs { font-size: .9rem; color: var(--muted); margin: 0 0 .25rem; }
.lede { color: var(--muted); font-size: 1.08rem; margin-top: -.4rem; }
.none, .note { color: var(--muted); }
.note { font-size: .92rem; margin: .3rem 0 0; }
dl.card { display: grid; grid-template-columns: minmax(9rem, max-content) 1fr; gap: .55rem 1.25rem; padding: 1rem 1.1rem; border: 1px solid var(--rule); border-radius: 6px; margin: 1.25rem 0 2rem; }
dl.card dt { font-weight: 600; font-size: .9rem; padding-top: .1rem; }
dl.card dd { margin: 0; min-width: 0; }
dl.card ul { margin: 0; padding-left: 1.1rem; }
ol.steps li { margin: .55rem 0; }
figure { margin: 2.25rem 0; }
figure img { display: block; max-width: 100%; height: auto; background: var(--fig-bg); padding: .5rem; border: 1px solid var(--rule); border-radius: 4px; }
figcaption { font-size: .92rem; color: var(--muted); margin-top: .6rem; line-height: 1.5; }
figcaption .fig { font-weight: 600; color: var(--fg); }
.big { padding: 1rem; border: 1px dashed var(--rule); border-radius: 4px; margin: 0; }
section.next { margin-top: 2.5rem; }
footer.site { border-top: 1px solid var(--rule); padding-top: 1.1rem; padding-bottom: 2.5rem; color: var(--muted); font-size: .88rem; }
@media (max-width: 40rem) {
  body { font-size: 1rem; }
  h1 { font-size: 1.6rem; }
  h2 { font-size: 1.3rem; }
  header.site nav { gap: .2rem 1rem; }
  dl.card { grid-template-columns: 1fr; gap: .15rem; }
  dl.card dd { margin-bottom: .55rem; }
}
'''


def css() -> str:
    light = HtmlFormatter(style='default').get_style_defs('.highlight')
    dark = HtmlFormatter(style='github-dark').get_style_defs('.highlight')
    dark = '\n'.join('  ' + ln for ln in dark.split('\n'))
    return ('/* MojoProof site: written by scripts/site.py. Code colours from Pygments. */\n' +
            light + '\n@media (prefers-color-scheme: dark) {\n' + dark + '\n}\n' +
            STYLE.lstrip('\n') + __import__('site_home').CSS.lstrip('\n') +
            __import__('site_coverage').CSS.lstrip('\n'))


# The check.

class Scan(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids: set[str] = set()
        self.links: list[tuple[str, str]] = []   # (tag, url)
        self.problems: list[str] = []
        self.title = ''
        self.main_text = []
        self.in_title = self.in_main = False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == 'script':
            self.problems.append('a <script> element')
        for k, _ in attrs:
            if k.lower().startswith('on'):
                self.problems.append(f'an {k} attribute on <{tag}>')
        if 'id' in a:
            self.ids.add(a['id'])
        if tag == 'a' and 'name' in a:
            self.ids.add(a['name'])
        if tag in ('a', 'link') and a.get('href') is not None:
            self.links.append((tag, a['href']))
        if tag in ('img', 'source', 'iframe', 'embed', 'object') and \
                (a.get('src') or a.get('data')) is not None:
            self.links.append(('img', a.get('src') or a.get('data')))
        if tag == 'title':
            self.in_title = True
        if tag == 'main':
            self.in_main = True

    def handle_endtag(self, tag):
        if tag == 'title':
            self.in_title = False
        if tag == 'main':
            self.in_main = False

    def handle_data(self, data):
        if self.in_title:
            self.title += data
        if self.in_main:
            self.main_text.append(data)


def external_ok(url: str) -> bool:
    try:
        u = urlsplit(url)
        u.port  # noqa: B018  (raises on a malformed port)
    except ValueError:
        return False
    return (u.scheme in ('http', 'https') and re.fullmatch(r'[A-Za-z0-9.-]+\.[A-Za-z]{2,}', u.netloc
                                                           or '') is not None
            and not re.search(r'[\s<>"{}|\\^`]', url))


def check(out: pathlib.Path) -> int:
    problems: list[str] = []
    if not (out / 'index.html').is_file():
        problems.append('no index.html')
    files = sorted(p for p in out.rglob('*') if p.is_file())
    scans: dict[pathlib.Path, Scan] = {}
    for p in files:
        name = p.relative_to(out).as_posix()
        if p.suffix.lower() in ('.js', '.mjs', '.cjs'):
            problems.append(f'{name}: a JavaScript file')
        if p.suffix == '.svg' and b'<script' in p.read_bytes().lower():
            problems.append(f'{name}: a <script> element')
        if p.suffix == '.html':
            s = Scan()
            s.feed(p.read_text())
            s.close()
            scans[p.resolve()] = s
            problems += [f'{name}: {x}' for x in s.problems]
            if not s.title.strip():
                problems.append(f'{name}: no title')
            if len(''.join(s.main_text).split()) < 5:
                problems.append(f'{name}: empty page')
    root = out.resolve()
    links = 0
    for p, s in sorted(scans.items()):
        name = p.relative_to(root).as_posix()
        for tag, url in s.links:
            links += 1
            if re.match(r'^[a-zA-Z][\w+.-]*:', url):
                if url.startswith('mailto:') and tag == 'a':
                    continue
                if tag == 'img' or not external_ok(url):
                    problems.append(f'{name}: bad external link {url!r}')
                continue
            path, _, frag = url.partition('#')
            target = (p.parent / unquote(path)).resolve() if path else p
            if root not in target.parents and target != root:
                problems.append(f'{name}: link {url!r} leaves the site')
            elif not target.is_file():
                problems.append(f'{name}: link {url!r} names no written file')
            elif frag and tag == 'a':
                if target.suffix != '.html':
                    continue
                if unquote(frag) not in scans[target].ids:
                    problems.append(f'{name}: link {url!r}: no anchor #{frag}')
    for x in problems:
        print(x)
    pages = len(scans)
    size = sum(p.stat().st_size for p in files)
    print(f'site: {pages} pages, {len(files)} files, {size / 1e6:.1f} MB, {links} links, '
          f'{len(problems)} problems')
    return 1 if problems else 0


class Stale(Exception):
    """The files that roadmap/status.yaml names and the repository does not have."""


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description='Write or check the project website.')
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--out', type=pathlib.Path, help='write the site into this directory')
    g.add_argument('--check', type=pathlib.Path, help='check the site in this directory')
    args = ap.parse_args(argv[1:])
    if args.check:
        return check(args.check)
    site = Site()
    try:
        site.build()
    except Stale as e:
        for f in e.args[0]:
            print(f'site: roadmap/status.yaml names {f}, which does not exist '
                  '(run scripts/roadmap_status.py)')
        return 1
    args.out.mkdir(parents=True, exist_ok=True)
    written = site.write(args.out)
    print(f'site: {len(site.pages)} pages, {len(written)} files written to {args.out}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
