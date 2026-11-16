// 本機預覽 dist/：node scripts/preview-site.mjs [port]
// 行為接近 GitHub Pages：目錄自動找 index.html，找不到的路徑回 404.html。
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const dist = fileURLToPath(new URL('../dist/', import.meta.url));
const port = Number(process.argv[2] || process.env.PORT || 4173);
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.svg': 'image/svg+xml', '.xml': 'application/xml' };

createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  let file = path.join(dist, decodeURIComponent(url.pathname));
  if (!file.startsWith(dist)) { res.writeHead(403).end(); return; }
  try {
    const info = await stat(file);
    if (info.isDirectory()) {
      if (!url.pathname.endsWith('/')) { res.writeHead(301, { Location: url.pathname + '/' + url.search }).end(); return; }
      file = path.join(file, 'index.html');
    }
    const body = await readFile(file);
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' }).end(body);
  } catch {
    res.writeHead(404, { 'Content-Type': types['.html'] }).end(await readFile(path.join(dist, '404.html')).catch(() => 'Not found'));
  }
}).listen(port, '127.0.0.1', () => console.log(`預覽：http://127.0.0.1:${port}/`));
