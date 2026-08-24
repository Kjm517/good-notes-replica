import re

path = r"d:\code-project\good-notes-replica\tools\section13_extract.html"
with open(path, "r", encoding="utf-8") as f:
    text = f.read().replace("\\n", "\n").replace("\\u002F", "/")

# subsection headers
for m in re.finditer(r"<!--\s*-+\s*([^-]+?)\s*-+\s*-->", text):
    print("SUB:", m.group(1).strip())

print("\n--- data-screen-label ---")
for m in re.finditer(r'data-screen-label="([^"]+)"', text):
    print(m.group(1))

print("\n--- nav items ---")
for m in re.finditer(r">([A-Z][a-z][^<]{2,30})</div>\s*\n\s*<div style=\"font-family:'Space Mono'[^>]*>([^<]+)", text):
    print(m.group(1), "|", m.group(2))
