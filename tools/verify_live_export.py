"""Compare hosted runtime files with the export; browser gameplay QA is separate."""
from pathlib import Path
import argparse, hashlib, json, urllib.request
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--url',default='https://cafe-shift-rush-hour.vercel.app')
p.add_argument('--out',type=Path,default=ROOT/'work'/'live-export-proof.json')
args = p.parse_args()
results=[]
for name in ['index.html','index.js','index.wasm','index.pck','index.audio.worklet.js','index.audio.position.worklet.js']:
    local=(ROOT/'builds'/'web'/name).read_bytes()
    with urllib.request.urlopen(args.url.rstrip('/')+'/'+name,timeout=60) as response:
        remote=response.read()
        mime=response.headers.get_content_type()
        status=response.status
    same=hashlib.sha256(remote).digest()==hashlib.sha256(local).digest()
    if status!=200 or not same or (name.endswith('.wasm') and mime!='application/wasm'):
        raise SystemExit('FAIL: hosted export differs or has incorrect MIME: '+name)
    results.append({'file':name,'http_status':status,'content_type':mime,'bytes':len(remote),'sha256':hashlib.sha256(remote).hexdigest(),'matches_local':same})
report={'executed_at_utc':datetime.now(timezone.utc).isoformat(),'url':args.url,'files':results,'passed':True,'scope':'Byte identity and runtime MIME; gameplay verified separately in the browser.'}
args.out.parent.mkdir(parents=True,exist_ok=True)
args.out.write_text(json.dumps(report,indent=2),encoding='utf8')
print('PASS: all six hosted runtime files match the local export; WASM MIME is correct.')
