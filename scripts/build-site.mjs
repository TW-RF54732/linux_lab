// 文件網站產生器：把 site/content/**/*.md 轉成靜態 HTML，輸出到 dist/。
// 只用 Node.js 內建模組，不需要 npm install。
//
//   node scripts/build-site.mjs
//
// 頁面順序與分類在 site/site.json；版型在 site/template.html。
// Markdown 只支援本站用到的子集，語法說明見 site/README.md。

import { readFile, writeFile, mkdir, copyFile, rm } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

export const root = fileURLToPath(new URL('../', import.meta.url));
const SITE = path.join(root, 'site');
const read = name => readFile(path.join(SITE, name), 'utf8');

const escape = value => String(value).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const CJK = /[　-〿㐀-鿿＀-￯]/;

// ---------------------------------------------------------------- 路徑

// slug → 網址目錄：index → ''、commands/index → 'commands/'、commands/ls → 'commands/ls/'
export const dirOf = slug => slug === 'index' ? '' : slug.endsWith('/index') ? slug.slice(0, -5) : `${slug}/`;

// 從某頁連到站內路徑（以 / 開頭，例如 /commands/ls/#options）的相對網址。
// 用相對路徑，GitHub Pages 的專案網址（/repo/）與自訂網域都能用。
export function relative(fromSlug, target) {
  const depth = dirOf(fromSlug).split('/').filter(Boolean).length;
  const prefix = '../'.repeat(depth);
  const rest = target.replace(/^\//, '');
  return (prefix + rest) || './';
}

// ---------------------------------------------------------------- Markdown 子集

function splitRow(line) {
  // 以 | 分欄，但略過反引號內與 \| 跳脫的 |
  const cells = [];
  let cell = '', code = false;
  const body = line.trim().replace(/^\|/, '').replace(/\|$/, '');
  for (let i = 0; i < body.length; i++) {
    const ch = body[i];
    if (ch === '\\' && body[i + 1] === '|') { cell += '|'; i++; continue; }
    if (ch === '`') code = !code;
    if (ch === '|' && !code) { cells.push(cell.trim()); cell = ''; continue; }
    cell += ch;
  }
  cells.push(cell.trim());
  return cells;
}

export function inline(text, ctx) {
  const codes = [];
  let out = text.replace(/(`+)([\s\S]*?[^`])\1(?!`)/g, (_, ticks, code) => {
    codes.push(`<code>${escape(code.replace(/^ (.*) $/, '$1'))}</code>`);
    return `\u0000${codes.length - 1}\u0000`;
  });
  out = escape(out);
  out = out.replace(/\[\[([^\]]+)\]\]/g, (_, key) => key.split('+').map(k => `<kbd>${k}</kbd>`).join('+'));
  out = out.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, label, href) => {
    const raw = href.replace(/&amp;/g, '&');
    if (raw.startsWith('/')) {
      ctx.links.push(raw);
      return `<a href="${escape(relative(ctx.slug, raw))}">${label}</a>`;
    }
    if (raw.startsWith('#')) ctx.links.push(`/${dirOf(ctx.slug)}${raw}`);
    const external = /^https?:/.test(raw);
    return `<a href="${escape(raw)}"${external ? ' rel="noopener"' : ''}>${label}${external ? ' ↗' : ''}</a>`;
  });
  out = out.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  out = out.replace(/\{lab(?::([^}]+))?\}/g, (_, which) => `<span class="badge">${which ? `第 ${which} 段` : '課程用到'}</span>`);
  return out.replace(/\u0000(\d+)\u0000/g, (_, i) => codes[Number(i)]);
}

const join = lines => lines.reduce((acc, line) => {
  if (!acc) return line;
  return acc + (CJK.test(acc.at(-1)) || CJK.test(line[0]) ? '' : ' ') + line;
}, '');

const KINDS = { command: '指令', output: '輸出', config: '設定檔', reference: '參考', text: '文字' };

export function markdown(source, ctx) {
  const lines = source.replace(/\r\n/g, '\n').split('\n');
  const sections = [];
  let lead = '';
  let html = '';
  let current = null;
  let i = 0;
  const flush = () => { if (current) { current.html = html; sections.push(current); } else lead = html; html = ''; };
  const heading = (raw, level) => {
    const m = raw.match(/^(.*?)\s*\{#([a-z0-9-]+)\}\s*$/);
    if (level === 2 && !m) throw new Error(`${ctx.slug}: ## 標題需要 {#id}：${raw}`);
    return { title: m ? m[1] : raw, id: m ? m[2] : null };
  };

  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) { i++; continue; }

    let m;
    if ((m = line.match(/^## (.+)$/))) {
      flush();
      const { title, id } = heading(m[1], 2);
      if (ctx.ids.has(id)) throw new Error(`${ctx.slug}: 重複的 id ${id}`);
      ctx.ids.add(id);
      current = { id, title };
      i++; continue;
    }
    if ((m = line.match(/^### (.+)$/))) {
      const { title, id } = heading(m[1], 3);
      if (id) { if (ctx.ids.has(id)) throw new Error(`${ctx.slug}: 重複的 id ${id}`); ctx.ids.add(id); }
      html += `<h3${id ? ` id="${id}"` : ''}>${inline(title, ctx)}</h3>`;
      i++; continue;
    }
    if ((m = line.match(/^```(\w*)\s*$/))) {
      const kind = m[1] || 'reference';
      if (!KINDS[kind]) throw new Error(`${ctx.slug}: 未知的程式碼區塊種類 ${kind}`);
      const body = [];
      i++;
      while (i < lines.length && !/^```\s*$/.test(lines[i])) body.push(lines[i++]);
      if (i >= lines.length) throw new Error(`${ctx.slug}: 程式碼區塊沒有結尾`);
      i++;
      const code = escape(body.join('\n'));
      if (kind === 'command') {
        html += `<div class="guide-command"><div class="code-heading"><span>${KINDS[kind]}</span><button type="button" class="copy-command" hidden>複製</button></div><pre tabindex="0"><code>${code}</code></pre><p class="copy-status" role="status" aria-live="polite"></p></div>`;
      } else {
        html += `<div class="doc-example doc-${kind}"><div class="code-heading"><span>${KINDS[kind]}</span></div><pre tabindex="0"><code>${code}</code></pre></div>`;
      }
      continue;
    }
    if (line.startsWith('|')) {
      const rows = [];
      while (i < lines.length && lines[i].startsWith('|')) rows.push(lines[i++]);
      if (rows.length < 2 || !/^\|?\s*:?-{3,}/.test(rows[1])) throw new Error(`${ctx.slug}: 表格缺少分隔列：${rows[0]}`);
      const head = splitRow(rows[0]);
      const body = rows.slice(2).map(splitRow);
      body.forEach(r => { if (r.length !== head.length) throw new Error(`${ctx.slug}: 表格欄數不符：${r.join(' | ')}`); });
      html += `<div class="guide-table"><table><thead><tr>${head.map(c => `<th scope="col">${inline(c, ctx)}</th>`).join('')}</tr></thead><tbody>${body.map(r => `<tr>${r.map((c, k) => k === 0 ? `<th scope="row">${inline(c, ctx)}</th>` : `<td>${inline(c, ctx)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;
      continue;
    }
    if ((m = line.match(/^> ?(\[!(NOTE|WARNING|TIP)\])?\s*(.*)$/))) {
      const kind = (m[2] || 'NOTE').toLowerCase();
      const body = m[3] ? [m[3]] : [];
      i++;
      while (i < lines.length && lines[i].startsWith('>')) body.push(lines[i++].replace(/^> ?/, ''));
      const paragraphs = body.join('\n').split(/\n\s*\n/).map(p => `<p>${inline(join(p.split('\n')), ctx)}</p>`).join('');
      const label = { note: '說明', warning: '注意', tip: '小技巧' }[kind];
      html += `<div class="guide-note note-${kind}"><p class="note-label">${label}</p>${paragraphs}</div>`;
      continue;
    }
    if (/^(- |\d+\. )/.test(line)) {
      const ordered = /^\d+\. /.test(line);
      const marker = ordered ? /^\d+\. / : /^- /;
      const items = [];
      while (i < lines.length && (marker.test(lines[i]) || (/^ {2,}\S/.test(lines[i]) && items.length))) {
        if (marker.test(lines[i])) items.push([lines[i].replace(marker, '')]);
        else items.at(-1).push(lines[i].trim());
        i++;
      }
      const tag = ordered ? 'ol' : 'ul';
      html += `<${tag}>${items.map(it => `<li>${inline(join(it), ctx)}</li>`).join('')}</${tag}>`;
      continue;
    }
    if (line.trim() === '{{index}}') { html += ctx.index; i++; continue; }
    if (line.startsWith('<')) {
      // 原始 HTML 區塊，直到空行
      const body = [];
      while (i < lines.length && lines[i].trim()) body.push(lines[i++]);
      html += body.join('\n');
      continue;
    }
    const para = [];
    while (i < lines.length && lines[i].trim() && !/^(#{2,3} |```|\||>|- |\d+\. |<)/.test(lines[i])) para.push(lines[i++].trim());
    html += `<p>${inline(join(para), ctx)}</p>`;
  }
  flush();
  return { lead, sections };
}

function frontmatter(source, slug) {
  const m = source.match(/^---\n([\s\S]*?)\n---\n/);
  if (!m) throw new Error(`${slug}: 缺少 frontmatter`);
  const data = {};
  for (const line of m[1].split('\n')) {
    const kv = line.match(/^([a-z]+):\s*(.*)$/);
    if (kv) data[kv[1]] = kv[2].trim();
  }
  if (!data.title || !data.description) throw new Error(`${slug}: frontmatter 需要 title 與 description`);
  return { data, body: source.slice(m[0].length) };
}

// ---------------------------------------------------------------- 組頁

export async function buildSite() {
  const output = path.join(root, 'dist');
  const site = JSON.parse(await read('site.json'));
  const template = await read('template.html');
  const order = site.nav.flatMap(group => group.pages.map(slug => ({ slug, group: group.title })));
  const seen = new Set();
  for (const { slug } of order) { if (seen.has(slug)) throw new Error(`site.json 重複的頁面：${slug}`); seen.add(slug); }

  const pages = [];
  for (const entry of order) {
    const source = (await read(`content/${entry.slug}.md`)).replace(/\r\n/g, '\n');
    const { data, body } = frontmatter(source, entry.slug);
    pages.push({ ...entry, data, body });
  }
  const bySlug = Object.fromEntries(pages.map(p => [p.slug, p]));
  const navTitle = p => p.data.nav || p.data.title;

  const indexFor = slug => site.nav.map(group => `<div class="index-group"><h3>${escape(group.title)}</h3><ul>${group.pages.map(s => `<li><a href="${escape(relative(slug, '/' + dirOf(s)))}">${escape(navTitle(bySlug[s]))}</a>${bySlug[s].data.summary ? ` — ${escape(bySlug[s].data.summary)}` : ''}</li>`).join('')}</ul></div>`).join('');

  const allIds = {};
  const allLinks = [];
  const rendered = [];
  for (const [n, page] of pages.entries()) {
    const ctx = { slug: page.slug, links: [], ids: new Set(), index: indexFor(page.slug) };
    const { lead, sections } = markdown(page.body, ctx);
    allIds[dirOf(page.slug)] = ctx.ids;
    allLinks.push(...ctx.links.map(link => [page.slug, link]));

    const bodyHtml = lead +
      sections.map(s => `<section class="guide-section" id="${s.id}"><h2>${inline(s.title, ctx)}</h2>${s.html}</section>`).join('');
    const toc = sections.map(s => `<a href="#${s.id}">${escape(s.title.replace(/`/g, ''))}</a>`).join('');

    const link = (target, current) => `<a href="${escape(relative(page.slug, '/' + dirOf(target.slug)))}"${current ? ' aria-current="page"' : ''}>${escape(navTitle(target))}</a>`;
    const sidebar = site.nav.map(group => `<div class="nav-group"><p class="nav-label">${escape(group.title)}</p>${group.pages.map(s => link(bySlug[s], s === page.slug)).join('')}</div>`).join('');
    const prev = pages[n - 1], next = pages[n + 1];
    const pagination = [prev && `<a href="${escape(relative(page.slug, '/' + dirOf(prev.slug)))}"><span>上一頁</span>${escape(navTitle(prev))}</a>`, next && `<a class="next" href="${escape(relative(page.slug, '/' + dirOf(next.slug)))}"><span>下一頁</span>${escape(navTitle(next))}</a>`].filter(Boolean).join('');
    const home = relative(page.slug, '/');
    const headerPath = page.slug === 'index'
      ? `<span aria-current="page">文件</span>`
      : `<a href="${escape(home)}">文件</a><span aria-hidden="true">/</span><span>${escape(page.group)}</span><span aria-hidden="true">/</span><span aria-current="page">${escape(navTitle(page))}</span>`;
    const asset = name => escape(relative(page.slug, '/' + name));
    const canonical = site.origin ? `<link rel="canonical" href="${escape(site.origin + '/' + dirOf(page.slug))}">` : '';
    const values = {
      title: escape(page.slug === 'index' ? site.title : `${page.data.title} — ${site.title}`),
      description: escape(page.data.description),
      canonical, styles: asset('styles.css'), script: asset('docs.js'), favicon: asset('favicon.svg'),
      home: escape(home), siteName: escape(site.title), headerPath,
      repository: site.repository ? `<nav class="header-links" aria-label="外部連結"><a href="${escape(site.repository)}" rel="noopener">GitHub ↗</a></nav>` : '',
      heading: escape(page.data.title), lede: inline(page.data.description, ctx),
      sidebar, toc: toc ? `<nav class="page-toc" aria-label="本頁內容"><p class="eyebrow">本頁內容</p>${toc}</nav>` : '',
      body: bodyHtml, pagination, footer: escape(site.footer || site.title)
    };
    const html = template.replace(/{{([a-zA-Z]+)}}/g, (_, key) => {
      if (!(key in values)) throw new Error(`template.html 未知的欄位 {{${key}}}`);
      return values[key];
    });
    rendered.push([path.join(dirOf(page.slug), 'index.html'), html]);
  }

  // 站內連結與錨點檢查：連到不存在的頁面或 #id 時直接中止
  for (const [from, link] of allLinks) {
    const [p, hash] = link.split('#');
    const dir = p.replace(/^\//, '');
    if (!(dir in allIds)) throw new Error(`${from}: 連結到不存在的頁面 ${link}`);
    if (hash && !allIds[dir].has(hash)) throw new Error(`${from}: 連結到不存在的錨點 ${link}`);
  }

  await rm(output, { recursive: true, force: true });
  for (const [name, content] of rendered) {
    await mkdir(path.dirname(path.join(output, name)), { recursive: true });
    await writeFile(path.join(output, name), content);
  }
  // 404 頁可能出現在任何深度的網址，所以資源一律用 site.base 開頭的絕對路徑
  const base = site.base || '/';
  await writeFile(path.join(output, '404.html'), `<!doctype html><html lang="zh-Hant"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex"><title>找不到頁面 — ${escape(site.title)}</title><link rel="stylesheet" href="${escape(base)}styles.css"></head><body><main class="container error-page"><h1>404</h1><p>找不到這個頁面，可能已經改名或移動。</p><p><a class="text-link" href="${escape(base)}">回到文件首頁</a></p></main></body></html>\n`);
  await writeFile(path.join(output, '.nojekyll'), '');
  if (site.origin) {
    const urls = pages.map(p => `<url><loc>${escape(site.origin + '/' + dirOf(p.slug))}</loc></url>`).join('');
    await writeFile(path.join(output, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls}</urlset>\n`);
  }
  for (const asset of ['styles.css', 'docs.js', 'favicon.svg']) await copyFile(path.join(SITE, asset), path.join(output, asset));
  return { output, count: rendered.length };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { count } = await buildSite();
  console.log(`已產生 ${count} 頁到 dist/`);
}
