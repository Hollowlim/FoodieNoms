/* Optional developer build. Live Server users do not need to run this. */
import { cp, mkdir, rm } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
const source = new URL('../fresh-webapp/', import.meta.url);
const output = new URL('../dist/', import.meta.url);
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
for (const file of ['index.html','styles.css','app.js','data.js','preview.html','preview.js','preview.css','manifest.webmanifest','sw.js','assets']) {
  await cp(new URL(file, source), new URL(file, output), { recursive: true });
}
console.log('Fresh FoodieNoms web app built in ' + fileURLToPath(output));
