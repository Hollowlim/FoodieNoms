// Serves the built check page, opens it in headless Chrome and relays its results.
const http = require('node:http'), fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const {spawn} = require('node:child_process');
const root = process.argv[2];
const types = {'.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm'};
const server = http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(req.url.split('?')[0]).replace(/\/$/, '/index.html'));
  if (!file.startsWith(root) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, {'content-type': types[path.extname(file)] || 'application/octet-stream'});
  fs.createReadStream(file).pipe(res);
});
server.listen(0, '127.0.0.1', () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'client-check-'));
  const chrome = spawn(process.env.CHROME_EXECUTABLE || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
    '--headless=new', '--disable-gpu', '--no-first-run', '--enable-logging=stderr', `--user-data-dir=${profile}`,
    `http://127.0.0.1:${server.address().port}/`]);
  const finish = code => { chrome.once('exit', () => { fs.rmSync(profile, {recursive: true, force: true, maxRetries: 5}); process.exit(code); }); chrome.kill(); server.close(); };
  const timer = setTimeout(() => { console.error('Timed out with no result.'); finish(2); }, 120000);
  let buffer = '';
  chrome.stderr.on('data', chunk => {
    buffer += chunk;
    const lines = buffer.split('\n');
    buffer = lines.pop();
    for (const line of lines) {
      const match = line.match(/CLIENT_CHECK[^"]*/);
      if (!match) continue;
      console.log(match[0]);
      const done = match[0].match(/DONE failed=(\d+)/);
      if (done) { clearTimeout(timer); finish(done[1] === '0' ? 0 : 1); }
    }
  });
});
