import { readFile } from 'node:fs/promises';

const html = await readFile('index.html', 'utf8');
const css = await readFile('src/styles.css', 'utf8');
const required = ['GoSense9', 'Overview', 'Pipeline', 'Insights', 'Compliance', 'Milestone M0'];
const missing = required.filter((text) => !html.includes(text));
if (missing.length) {
  console.error(`Missing required UI text: ${missing.join(', ')}`);
  process.exit(1);
}
if (!css.includes('@media') || !css.includes(':focus-visible')) {
  console.error('Styles must include responsive and focus-visible rules.');
  process.exit(1);
}
console.log('Static UI checks passed.');
