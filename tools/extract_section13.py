import re
import sys

path = r"c:\Users\Ren\Downloads\Annotate Redesign (3).html"
with open(path, "r", encoding="utf-8", errors="replace") as f:
    text = f.read()

# Section comments like <!-- ============ 13 SETTINGS ============ -->
sections = list(re.finditer(r"<!--\s*=+\s*(\d+)\s+([^=]+?)\s*=+\s*-->", text))
print(f"Found {len(sections)} section markers")
for m in sections:
    num = m.group(1)
    title = m.group(2).strip()
    print(f"  {num}: {title}")

if not sections:
    sys.exit(1)

# Find section 13
s13 = next((m for m in sections if m.group(1) == "13"), None)
if not s13:
    print("Section 13 not found")
    sys.exit(1)

start = s13.start()
s14 = next((m for m in sections if m.group(1) == "14"), None)
end = s14.start() if s14 else start + 200000

chunk = text[start:end]
out = r"d:\code-project\good-notes-replica\tools\section13_extract.html"
with open(out, "w", encoding="utf-8") as f:
    f.write(chunk)
print(f"\nWrote {len(chunk)} chars to {out}")
print("\n--- PREVIEW (first 8000 chars) ---")
print(chunk[:8000])
