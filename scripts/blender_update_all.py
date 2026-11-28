import json, os, subprocess, time
def curl(a): return subprocess.run(["curl","-sS"]+a,capture_output=True,text=True).stdout
maps=[("outB2","assets_ids.json"),("outB3","assets_ids3.json"),("outB4","assets_ids4.json"),("outB5","assets_ids5.json"),("outB6","assets_ids6.json")]
jobs=[]
for d,j in maps:
    ids=json.load(open(j))
    for n,v in ids.items():
        if n.startswith("tex_") or not v.get("id"): continue
        f=f"{d}/{n}.fbx"
        if os.path.exists(f): jobs.append((n,v["id"],f))
ops={}
for n,aid,f in jobs:
    out=curl(["-X","PATCH",f"https://apis.roblox.com/assets/v1/assets/{aid}","--form-string",json.dumps({"assetId":aid}).join(["request=",""]),"-F",f"fileContent=@{f};type=model/fbx"])
    try: ops[n]=(aid,json.loads(out)["operationId"])
    except Exception: ops[n]=None; print("ECHEC",n,out[:140])
    time.sleep(0.6)
res={}
for _ in range(16):
    pend=[n for n,_,_ in jobs if n not in res and ops.get(n)]
    if not pend: break
    time.sleep(6)
    for n in pend:
        r=json.loads(curl([f"https://apis.roblox.com/assets/v1/operations/{ops[n][1]}"]) or "{}")
        if r.get("done"): resp=r.get("response",{}); res[n]={"rev":resp.get("revisionId"),"mod":resp.get("moderationResult",{}).get("moderationState"),"err":r.get("error")}
bad=[(n,v) for n,v in res.items() if v["mod"]!="Approved"]
print("mis a jour",len(res),"/",len(jobs),"non approuves",len(bad)); print(bad[:8])
json.dump(res,open("update_results.json","w"))
