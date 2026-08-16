import fs from 'fs';

const raw = fs.readFileSync('D:/code-project/good-notes-replica/tool_design_extract.html', 'utf8');
// File may be a JSON-escaped string starting with quote
let html = raw;
if (html.startsWith('"')) {
  try { html = JSON.parse(html); } catch (_) {
    html = raw.replace(/^"|"$/g, '').replace(/\\n/g, '\n').replace(/\\"/g, '"').replace(/\\u002F/g, '/');
  }
}
fs.writeFileSync('D:/code-project/good-notes-replica/tool_design_pretty.html', html);
console.log('pretty length', html.length);

const texts = [...html.matchAll(/>([A-Za-z][^<]{1,60})</g)]
  .map(m => m[1].trim())
  .filter(t => t && !t.startsWith('{') && t.length < 50);
console.log('--- sample texts ---');
console.log([...new Set(texts)].slice(0, 120).join('\n'));

const media = [...html.matchAll(/@media[^{]+\{/g)].map(m => m[0]);
console.log('--- media ---');
console.log(media.slice(0, 40).join('\n'));

const cls = [...new Set([...html.matchAll(/class="([^"]+)"/g)].flatMap(m => m[1].split(/\s+/)))]
  .filter(c => /tool|bar|side|dock|nav|lib|edit|phone|mobile|desk|sheet|card|rail|top|bottom/i.test(c));
console.log('--- classes ---');
console.log(cls.slice(0, 120).join('\n'));
