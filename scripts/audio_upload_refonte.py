import json, os, subprocess, sys, time
OWNER = "11905484366"
D = os.environ.get("AUDIO_OUT", "/tmp/claude-0/-home-user-APPS-VIE/c9e841d1-d554-571c-a61d-bf92920d8724/scratchpad/audio4")
def curl(a): return subprocess.run(["curl", "-sS"] + a, capture_output=True, text=True).stdout
names = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(D) if f.endswith(".ogg"))
ids_path = os.path.join(D, "ids.json")
res = json.load(open(ids_path)) if os.path.exists(ids_path) else {}
ops = {}
for n in names:
    req = json.dumps({"assetType": "Audio", "displayName": n, "description": f"{n} son synthetique pour jeu Roblox", "creationContext": {"creator": {"userId": OWNER}}})
    out = curl(["-X", "POST", "https://apis.roblox.com/assets/v1/assets", "--form-string", f"request={req}", "-F", f"fileContent=@{D}/{n}.ogg;type=audio/ogg"])
    try: ops[n] = json.loads(out)["operationId"]
    except Exception: ops[n] = None; print("ECHEC", n, out[:200])
    time.sleep(0.8)
done = {}
for _ in range(30):
    pend = [n for n in names if n not in done and ops.get(n)]
    if not pend: break
    time.sleep(6)
    for n in pend:
        r = json.loads(curl([f"https://apis.roblox.com/assets/v1/operations/{ops[n]}"]) or "{}")
        if r.get("done"):
            resp = r.get("response", {}); done[n] = {"id": resp.get("assetId"), "mod": resp.get("moderationResult", {}).get("moderationState"), "err": r.get("error")}
res.update(done)
json.dump(res, open(ids_path, "w"), indent=1)
from collections import Counter
print(Counter(v["mod"] for v in done.values()), "sur", len(names))
print(" ; ".join(f"{n} {v['id']} {v['mod']}" for n, v in done.items()))
