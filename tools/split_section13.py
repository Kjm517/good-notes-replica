import re

path = r"d:\code-project\good-notes-replica\tools\section13_extract.html"
with open(path, "r", encoding="utf-8") as f:
    raw = f.read()

text = raw.replace("\\n", "\n").replace("\\u002F", "/").replace('\\"', '"')

markers = [
    "SIGN IN",
    "OVERVIEW",
    "USERS",
    "SUBSCRIPTIONS",
    "VOUCHERS",
    "BUG REPORTS",
    "AI USAGE",
    "DOCUMENTS",
]

positions = []
for label in markers:
    pat = rf"<!--\s*-+\s*{re.escape(label)}"
    m = re.search(pat, text, re.I)
    if m:
        positions.append((label, m.start()))

positions.sort(key=lambda x: x[1])
for i, (label, start) in enumerate(positions):
    end = positions[i + 1][1] if i + 1 < len(positions) else len(text)
    chunk = text[start:end]
    out = rf"d:\code-project\good-notes-replica\tools\section13_{label.split()[0].lower()}.txt"
    # strip tags for readability
    plain = re.sub(r"<[^>]+>", " ", chunk)
    plain = re.sub(r"\s+", " ", plain)[:4000]
    with open(out, "w", encoding="utf-8") as f:
        f.write(plain)
    print(label, len(chunk), "->", out)
