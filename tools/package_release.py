"""Package only compiled Web game files, with a SHA-256 manifest."""
from pathlib import Path
import argparse, hashlib, json, zipfile

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--out',type=Path,default=ROOT/'builds'/'release')
args = p.parse_args()
source = ROOT/'builds'/'web'
required = ['index.html','index.js','index.wasm','index.pck']
for name in required:
    if not (source/name).is_file(): raise SystemExit('Missing exported game file: '+name)
files = sorted(f for f in source.iterdir() if f.suffix in ['.html','.js','.wasm','.pck','.png'])
args.out.mkdir(parents=True,exist_ok=True)
archive = args.out/'cafe-shift-rush-hour-web.zip'
instructions = ('CAFÉ SHIFT — Rush Hour\n\nPlay: https://cafe-shift-rush-hour.vercel.app/\n'
    'Source: https://github.com/Hustlenix/cafe-shift-rush-hour\n\n'
    'To run this compiled Web build locally, extract it and run:\n'
    '  python -m http.server 8787\nThen visit http://localhost:8787\n'
    'Godot Web requires an HTTP server; double-clicking index.html is insufficient.\n\n'
    'Paid artwork: Modern Interiors by LimeZu. Artwork is embedded in the compiled game.\n'
    'Do not extract or redistribute the paid artwork as an asset pack.\n'
    'AI assistance and verification evidence are documented in the source README.\n')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for file in files: z.write(file,file.name)
    z.writestr('PLAY.txt',instructions)
manifest = {file.name:{'bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()} for file in files}
manifest[archive.name]={'bytes':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()}
(args.out/'sha256.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
with zipfile.ZipFile(archive) as z:
    if z.testzip() is not None: raise SystemExit('Archive validation failed.')
print('PASS: packaged and checked',archive)
