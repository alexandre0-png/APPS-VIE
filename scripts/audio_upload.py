import json, os, subprocess, time
OWNER="11905484366"
def curl(a): return subprocess.run(["curl","-sS"]+a,capture_output=True,text=True).stdout
names=sorted(f[:-4] for f in os.listdir("audio2") if f.endswith(".ogg"))
ops={}
for n in names:
    req=json.dumps({"assetType":"Audio","displayName":n,"description":f"{n} son synthetique pour jeu Roblox","creationContext":{"creator":{"userId":OWNER}}})
    out=curl(["-X","POST","https://apis.roblox.com/assets/v1/assets","--form-string",f"request={req}","-F",f"fileContent=@audio2/{n}.ogg;type=audio/ogg"])
    try: ops[n]=json.loads(out)["operationId"]
    except Exception: ops[n]=None; print("ECHEC",n,out[:200])
    time.sleep(0.8)
res={}
for _ in range(20):
    pend=[n for n in names if n not in res and ops.get(n)]
    if not pend: break
    time.sleep(6)
    for n in pend:
        r=json.loads(curl([f"https://apis.roblox.com/assets/v1/operations/{ops[n]}"]) or "{}")
        if r.get("done"): resp=r.get("response",{}); res[n]={"id":resp.get("assetId"),"mod":resp.get("moderationResult",{}).get("moderationState"),"err":r.get("error")}
json.dump(res,open("audio2/ids.json","w"),indent=1)
from collections import Counter
print(Counter(v["mod"] for v in res.values()), "sur", len(names))
print(" ; ".join(f"{n} {v['id']}" for n,v in res.items() if v["id"]))
