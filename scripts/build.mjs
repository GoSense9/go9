import { mkdir, copyFile, rm } from 'node:fs/promises';

await rm('dist', { recursive: true, force: true });
await mkdir('dist/src', { recursive: true });
await copyFile('index.html', 'dist/index.html');
await copyFile('src/styles.css', 'dist/src/styles.css');
console.log('Built static GoSense9 UI into dist/');
