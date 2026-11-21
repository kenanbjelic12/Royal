#!/usr/bin/env python3
"""Builds the browser test version of Royal Arena.

1. Godot export with the "Web" preset into build/web/
2. gzip + split index.wasm / index.pck into <12 MB chunks (*.wasm names so any
   static host serves them), and write build/webpub/index.html from
   Tools/web_shell.html (branded loader with real download progress).

Usage: python3 Tools/build_web.py [path/to/godot]
"""
import gzip, json, os, re, shutil, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GODOT = sys.argv[1] if len(sys.argv) > 1 else "godot"
WEB = os.path.join(ROOT, "build", "web")
PUB = os.path.join(ROOT, "build", "webpub")
CHUNK = 12 * 1024 * 1024

os.makedirs(WEB, exist_ok=True)
subprocess.run([GODOT, "--headless", "--path", ROOT, "--export-release", "Web", os.path.join(WEB, "index.html")], check=True)
shutil.rmtree(PUB, ignore_errors=True)
os.makedirs(PUB)
html = open(os.path.join(WEB, "index.html")).read()
config = json.loads(re.search(r"const GODOT_CONFIG = (\{.*?\});", html).group(1))
config["ensureCrossOriginIsolationHeaders"] = False
for f in ("index.js", "index.audio.worklet.js"):
    shutil.copy(os.path.join(WEB, f), PUB)
shutil.copy(os.path.join(ROOT, "Assets", "UI", "loading_bg.jpg"), PUB)
chunks, sizes = {}, {}
for name in ("index.wasm", "index.pck"):
    data = gzip.compress(open(os.path.join(WEB, name), "rb").read(), 9)
    kind = name.split(".")[1]
    parts = []
    for i in range(0, len(data), CHUNK):
        part = "gz_%s_%02d.wasm" % (kind, i // CHUNK)
        open(os.path.join(PUB, part), "wb").write(data[i:i + CHUNK])
        parts.append(part)
    chunks[name] = parts
    sizes[name] = len(data)
shell = open(os.path.join(ROOT, "Tools", "web_shell.html")).read()
shell = shell.replace("{{CHUNKS}}", json.dumps(chunks)).replace("{{SIZES}}", json.dumps(sizes)).replace("{{GODOT_CONFIG}}", json.dumps(config))
open(os.path.join(PUB, "index.html"), "w").write(shell)
print("web build ready in", PUB)
for f in sorted(os.listdir(PUB)):
    print("  %-26s %8d KB" % (f, os.path.getsize(os.path.join(PUB, f)) // 1024))
