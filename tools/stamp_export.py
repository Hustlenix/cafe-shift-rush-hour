"""Record the source commit and byte hashes for a locally exported Web build."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument("--directory", type=Path, default=ROOT / "builds" / "web")
args = p.parse_args()
files = ["index.html", "index.js", "index.wasm", "index.pck",
         "index.audio.worklet.js", "index.audio.position.worklet.js"]
commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
if subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip():
    raise SystemExit("Commit source changes before stamping a release.")
manifest = {}
for name in files:
    data = (args.directory / name).read_bytes()
    manifest[name] = {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
report = {"source_commit": commit,
          "source_url": "https://github.com/Hustlenix/cafe-shift-rush-hour/tree/" + commit,
          "built_at_utc": datetime.now(timezone.utc).isoformat(),
          "godot": "4.7.1", "files": manifest}
(args.directory / "release.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf8")
print("Stamped", commit, "with", len(manifest), "runtime file hashes.")
