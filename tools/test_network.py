"""Real two-process synchronization test. Test credentials stay in an ignored handoff,
are deleted after join, and the temporary server room is revoked after the test.
"""
from pathlib import Path
import argparse, subprocess, os, time, json, uuid, tempfile
from datetime import datetime, timezone
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--godot',default=str(Path.home()/'Godot'/'Godot_v4.7.1-stable_win64_console.exe'))
p.add_argument('--endpoint',default='http://127.0.0.1:8790')
args=p.parse_args()
(ROOT/'work').mkdir(exist_ok=True)
handoff=Path(tempfile.gettempdir())/('cafe-shift-network-'+uuid.uuid4().hex+'.json')
if handoff.exists(): handoff.unlink()
env=dict(os.environ,CAFE_SYNC_ENDPOINT=args.endpoint,CAFE_TEST_HANDOFF=str(handoff))
base=[args.godot,'--headless','--path',str(ROOT),'--script','res://tests/test_network_client.gd','--']
clients=[]
logs=[]
def launch(role,client_env):
    log=ROOT/'work'/('network-'+role+'.log')
    stream=log.open('w',encoding='utf8')
    logs.append((role,log,stream))
    process=subprocess.Popen(base+[role],stdout=stream,stderr=subprocess.STDOUT,env=client_env)
    return (role,process)
try:
    clients.append(launch('POS',env))
    deadline=time.monotonic()+40
    while not handoff.exists():
        if time.monotonic()>deadline or clients[0][1].poll() is not None:
            clients[0][1].terminate()
            clients[0][1].wait(timeout=100)
            print(logs[0][1].read_text(encoding='utf8',errors='replace'))
            raise RuntimeError('Till did not create its test pairing code.')
        time.sleep(0.1)
    pairing=json.loads(handoff.read_text(encoding='utf8'))['code']
    handoff.unlink()
    kitchen_env=dict(env,CAFE_TEST_KITCHEN_CODE=pairing)
    clients.append(launch('KITCHEN',kitchen_env))
    evidence=[]
    for role,proc in clients:
        proc.wait(timeout=100)
        output=next(log for r,log,_ in logs if r==role).read_text(encoding='utf8',errors='replace')
        print(role+':\n'+output)
        ok=proc.returncode==0 and 'PASS: independent' in output and 'ERROR:' not in output
        evidence.append({'client':role,'pid':proc.pid,'passed':ok,'output':output})
    success=all(c['passed'] for c in evidence)
    report={'executed_at_utc':datetime.now(timezone.utc).isoformat(),'endpoint':args.endpoint,'transport':'loopback development HTTP' if args.endpoint.startswith('http:') else 'HTTPS','independent_processes':True,'clients':evidence,'passed':success}
    (ROOT/'work'/'network-evidence.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    raise SystemExit(0 if success else 1)
finally:
    for _,proc in clients:
        if proc.poll() is None: proc.terminate()
    for _,_,stream in logs: stream.close()
    if handoff.exists(): handoff.unlink()
    temporary=Path(str(handoff)+'.tmp')
    if temporary.exists(): temporary.unlink()
