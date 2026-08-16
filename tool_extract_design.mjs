import fs from 'fs';

const src = 'C:/Users/Ren/Downloads/Annotate Redesign.html';
const out = 'D:/code-project/good-notes-replica/tool_design_extract.html';
const s = fs.readFileSync(src, 'utf8');
console.log('source bytes', s.length);

const markers = [
  'type="__bundler/template"',
  "type='__bundler/template'",
  '__bundler/template',
  'id="__bundler_template"',
];
for (const m of markers) {
  console.log(m, s.indexOf(m));
}

let start = s.indexOf('<script type="__bundler/template">');
if (start < 0) start = s.indexOf("<script type='__bundler/template'>");
if (start < 0) {
  // Fall back: dump head-ish text samples around "library" / "editor"
  const i = s.toLowerCase().indexOf('table of contents');
  console.log('toc idx', i);
  fs.writeFileSync(out + '.sample.txt', s.slice(Math.max(0, i - 500), i + 5000));
  process.exit(1);
}

const openEnd = s.indexOf('>', start) + 1;
const close = s.indexOf('</script>', openEnd);
const html = s.slice(openEnd, close);
fs.writeFileSync(out, html);
console.log('wrote', out, html.length);
