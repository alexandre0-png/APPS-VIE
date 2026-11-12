#!/usr/bin/env python3
"""Publication CITY RUSH via Open Cloud (stdlib uniquement).

Prérequis (seul l'utilisateur peut les fournir) :
  - une expérience créée dans le Creator Hub -> universeId et placeId
  - une clé API Open Cloud (variable ROBLOX_API_KEY) avec les permissions :
      universe-places:write  (publier le lieu)
      universe.developer-product:write et universe.game-pass:write (--setup-monetization)

Usage :
  python3 tools/publish.py --universe 123 --place 456            # publie le lieu
  python3 tools/publish.py --universe 123 --place 456 --dry-run  # construit seulement
  python3 tools/publish.py --universe 123 --setup-monetization   # crée produits/passes (best effort)
Les vignettes et l'icône ne sont pas gérées par Open Cloud : voir A_FAIRE_UTILISATEUR.md.
"""
import argparse, json, os, pathlib, re, subprocess, sys, urllib.request, urllib.error

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_rbxlx

PRODUCTS = [
    ("cash_s", "Sac de billets", "5 000 $ immédiatement", 49),
    ("cash_m", "Mallette", "30 000 $ immédiatement", 249),
    ("cash_l", "Coffre-fort", "150 000 $ immédiatement", 999),
]
PASSES = [
    ("VIP", "VIP CITY RUSH", "Gains x2, Phantom Doré exclusif, badge VIP", 399),
    ("BOOST", "Nitro Infini+", "Nitro deux fois plus long et recharge rapide", 149),
]

def request(method, url, key, data=None, ctype="application/json"):
    req = urllib.request.Request(url, data=data, method=method)
    if key:
        req.add_header("x-api-key", key)
    req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")

def publish_place(universe, place, key):
    build_rbxlx.OUT.parent.mkdir(exist_ok=True)
    build_rbxlx.OUT.write_text(build_rbxlx.build(), encoding="utf-8")
    body = build_rbxlx.OUT.read_bytes()
    url = f"https://apis.roblox.com/universes/v1/{universe}/places/{place}/versions?versionType=Published"
    status, text = request("POST", url, key, body, "application/xml")
    print("Publication du lieu :", status, text[:300])
    return status == 200

def write_ids(ids):
    p = ROOT / "src/ReplicatedStorage/Shared/MonetizationIds.lua"
    s = p.read_text()
    for k, v in ids.items():
        s = re.sub(rf"({k}\s*=\s*)\d+", rf"\g<1>{v}", s)
    p.write_text(s)

def setup_monetization(universe, key):
    ids = {}
    for k, name, desc, price in PRODUCTS:
        payload = json.dumps({"name": name, "description": desc, "price": price, "isForSale": True}).encode()
        st, txt = request("POST", f"https://apis.roblox.com/developer-products/v2/universes/{universe}/developer-products", key, payload)
        print(f"Produit {k}:", st, txt[:200])
        try:
            j = json.loads(txt)
            pid = j.get("productId") or j.get("id")
            if pid:
                ids[k] = int(pid)
        except Exception:
            pass
    for k, name, desc, price in PASSES:
        payload = json.dumps({"name": name, "description": desc, "price": price, "isForSale": True}).encode()
        st, txt = request("POST", f"https://apis.roblox.com/game-passes/v1/universes/{universe}/game-passes", key, payload)
        print(f"Pass {k}:", st, txt[:200])
        try:
            j = json.loads(txt)
            pid = j.get("gamePassId") or j.get("id")
            if pid:
                ids[k] = int(pid)
        except Exception:
            pass
    if ids:
        write_ids(ids)
        print("IDs écrits dans MonetizationIds.lua :", ids)
    missing = [k for k, *_ in PRODUCTS + PASSES if k not in ids]
    if missing:
        print("À créer/renseigner à la main (voir publication/monetization.md) :", missing)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--universe", type=int)
    ap.add_argument("--place", type=int)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--setup-monetization", action="store_true")
    a = ap.parse_args()
    key = os.environ.get("ROBLOX_API_KEY", "")
    if a.dry_run:
        build_rbxlx.OUT.parent.mkdir(exist_ok=True)
        build_rbxlx.OUT.write_text(build_rbxlx.build(), encoding="utf-8")
        print("Construit :", build_rbxlx.OUT)
        return
    if not a.universe:
        sys.exit("--universe est requis")
    if not key:
        sys.exit("Définis ROBLOX_API_KEY (clé Open Cloud)")
    if a.setup_monetization:
        setup_monetization(a.universe, key)
    if a.place:
        ok = publish_place(a.universe, a.place, key)
        sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
