"""Compare hosted runtime files with the export; browser gameplay QA is separate."""
from pathlib import Path
import argparse, hashlib, json, urllib.request
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--url',default='https://cafe-shift-rush-hour.vercel.app')
p.add_argument('--out',type=Path,default=ROOT/'work'/'live-export-proof.json')
p.add_argument('--directory',type=Path,default=ROOT/'builds'/'web')
args = p.parse_args()
results=[]
for name in ['index.html','index.js','index.wasm','index.pck','index.audio.worklet.js','index.audio.position.worklet.js']:
    local=(args.directory/name).read_bytes()
    with urllib.request.urlopen(args.url.rstrip('/')+'/'+name,timeout=60) as response:
        remote=response.read()
        mime=response.headers.get_content_type()
        status=response.status
    same=hashlib.sha256(remote).digest()==hashlib.sha256(local).digest()
    if status!=200 or not same or (name.endswith('.wasm') and mime!='application/wasm'):
        raise SystemExit('FAIL: hosted export differs or has incorrect MIME: '+name)
    results.append({'file':name,'http_status':status,'content_type':mime,'bytes':len(remote),'sha256':hashlib.sha256(remote).hexdigest(),'matches_local':same})
source_commit=None
manifest_path=args.directory/'release.json'
if manifest_path.exists():
    with urllib.request.urlopen(args.url.rstrip('/')+'/release.json',timeout=60) as response:
        remote_manifest=json.load(response)
    local_manifest=json.loads(manifest_path.read_text(encoding='utf8'))
    if remote_manifest != local_manifest: raise SystemExit('FAIL: hosted source manifest differs.')
    for item in results:
        if remote_manifest['files'][item['file']]['sha256'] != item['sha256']:
            raise SystemExit('FAIL: manifest does not describe runtime bytes: '+item['file'])
    source_commit=remote_manifest['source_commit']
report={'executed_at_utc':datetime.now(timezone.utc).isoformat(),'url':args.url,'source_commit':source_commit,'anonymous_requests':True,'files':results,'passed':True,'scope':'Anonymous HTTP file access, byte identity, source manifest when present and runtime MIME. This does not verify browser gameplay.'}
args.out.parent.mkdir(parents=True,exist_ok=True)
args.out.write_text(json.dumps(report,indent=2),encoding='utf8')
print('PASS: all six hosted runtime files match the local export; WASM MIME is correct.')
