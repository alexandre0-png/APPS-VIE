import json, os, subprocess, time, sys
OWNER = "11905484366"; D = "out2"
names = sorted(f[:-4] for f in os.listdir(D) if f.endswith(".fbx"))
ops = {}
def curl(args): return subprocess.run(["curl","-sS"]+args, capture_output=True, text=True).stdout
for n in names:
    req = json.dumps({"assetType":"Model","displayName":n,"description":f"{n} modele low-poly pour jeu Roblox","creationContext":{"creator":{"userId":OWNER}}})
    out = curl(["-X","POST","https://apis.roblox.com/assets/v1/assets","--form-string",f"request={req}","-F",f"fileContent=@{D}/{n}.fbx;type=model/fbx"])
    try: ops[n] = json.loads(out)["operationId"]
    except Exception: ops[n] = None; print("ECHEC envoi", n, out[:160])
    time.sleep(0.6)
res = {}
for round_ in range(12):
    pending = [n for n in names if n not in res and ops.get(n)]
    if not pending: break
    time.sleep(6)
    for n in pending:
        r = json.loads(curl([f"https://apis.roblox.com/assets/v1/operations/{ops[n]}"]) or "{}")
        if r.get("done"):
            resp = r.get("response", {}); res[n] = {"id": resp.get("assetId"), "mod": resp.get("moderationResult",{}).get("moderationState"), "err": r.get("error")}
json.dump(res, open("assets_ids.json","w"), indent=1)
ok = {n:v for n,v in res.items() if v["id"] and v["mod"]=="Approved"}
print("approuves", len(ok), "/", len(names)); 
for n,v in res.items():
    if n not in ok: print("non approuve", n, v)
