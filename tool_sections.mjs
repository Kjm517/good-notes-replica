import fs from 'fs';

const html = fs.readFileSync('D:/code-project/good-notes-replica/tool_design_pretty.html', 'utf8');

function sectionAround(label, radius = 2500) {
  const i = html.indexOf(label);
  if (i < 0) return `MISSING ${label}`;
  return `\n===== ${label} @${i} =====\n` + html.slice(i, i + radius).replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 1500);
}

for (const label of [
  'Android · Reader',
  'Android · Library',
  'Desktop · light',
  'Reader · annotation toolbar',
  'Mobile · dark',
  'Document settings',
  'Pages',
  'Outline',
  'Create',
]) {
  console.log(sectionAround(label));
}
