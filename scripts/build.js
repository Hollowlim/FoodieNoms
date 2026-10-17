import { cp, mkdir, rm, readFile, writeFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
const root = new URL('../', import.meta.url);
const output = new URL('dist/', root);
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
for (const name of ['index.html', 'src']) {
  await cp(new URL(name, root), new URL(name, output), { recursive: true });
}
// Package the same source as a single offline HTML file for client presentations.
const dataURI = async (name, mime) => `data:${mime};base64,${(await readFile(new URL(name, root))).toString('base64')}`;
const icons = {};
for (const name of await readdir(new URL('src/assets/icons/', root))) {
  if (name.endsWith('.svg')) icons[name.slice(0, -4)] = await dataURI('src/assets/icons/' + name, 'image/svg+xml');
}
let css = await readFile(new URL('src/style.css', root), 'utf8');
let js = await readFile(new URL('src/app.js', root), 'utf8');
const store = await readFile(new URL('src/store.js', root), 'utf8');
for (const name of ['logo.png', 'food-sheet.png', 'map.png', 'avatar.png']) {
  const uri = await dataURI('src/assets/' + name, 'image/png');
  css = css.replaceAll('./assets/' + name, uri);
  js = js.replaceAll('./src/assets/' + name, uri);
}
let html = await readFile(new URL('index.html', root), 'utf8');
html = html.replace('<link rel="stylesheet" href="./src/style.css">', `<style>${css}</style>`)
  .replace('<script src="./src/store.js"></script>', `<script>globalThis.FoodieAssets=${JSON.stringify(icons)};${store}</script>`)
  .replace('<script src="./src/app.js"></script>', `<script>${js}</script>`);
await writeFile(new URL('FoodieNoms-demo.html', root), html);
await writeFile(new URL('FoodieNoms-demo.html', output), html);
console.log('Built static website: ' + fileURLToPath(output));
console.log('Built offline presentation: ' + fileURLToPath(new URL('FoodieNoms-demo.html', root)));
