import json, gzip, base64, re, pathlib

html = pathlib.Path(r"c:\Users\Ren\Downloads\Annotate Redesign (3).html").read_text(
    encoding="utf-8"
)
out = pathlib.Path(r"d:\code-project\good-notes-replica\tools\annotate_redesign_unpacked")
out.mkdir(parents=True, exist_ok=True)

m = re.search(r'<script type="__bundler/template">(.*?)</script>', html, re.S)
template = json.loads(m.group(1))
(out / "template.html").write_text(template, encoding="utf-8")
print("template bytes", len(template))

mm = re.search(r'<script type="__bundler/manifest">(.*?)</script>', html, re.S)
manifest = json.loads(mm.group(1))
print("manifest entries", len(manifest))

ext_map = {
    "text/javascript": ".js",
    "text/css": ".css",
    "text/html": ".html",
    "image/png": ".png",
    "image/svg+xml": ".svg",
    "image/jpeg": ".jpg",
    "font/woff2": ".woff2",
    "font/ttf": ".ttf",
}

for uid, meta in manifest.items():
    raw = base64.b64decode(meta["data"])
    if meta.get("compressed"):
        raw = gzip.decompress(raw)
    ext = ext_map.get(meta.get("mime"), ".bin")
    path = out / f"{uid[:12]}{ext}"
    path.write_bytes(raw)
    print(uid[:12], meta.get("mime"), len(raw), "->", path.name)

# Also unpack nested pages if present
po = re.search(r'<script type="__bundler/page_order">(.*?)</script>', html, re.S)
if po:
    order = json.loads(po.group(1))
    print("page_order", len(order))
    for uid in order:
        if uid in manifest:
            continue
        # pages may be in template markers only; check ext_resources
        pass

er = re.search(r'<script type="__bundler/ext_resources">(.*?)</script>', html, re.S)
if er:
    (out / "ext_resources.json").write_text(er.group(1), encoding="utf-8")
    print("wrote ext_resources.json")
