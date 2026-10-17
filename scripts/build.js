import { cp, mkdir, rm } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
const output = new URL('../dist/', import.meta.url);
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
for (const name of ['index.html', 'src']) {
  await cp(new URL('../' + name, import.meta.url), new URL(name, output), { recursive: true });
}
console.log('Static website built in ' + fileURLToPath(output));
