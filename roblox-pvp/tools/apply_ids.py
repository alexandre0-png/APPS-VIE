#!/usr/bin/env python3
"""Injecte les Id d'achats Roblox dans Config.luau depuis publication/ids.json.

ids.json : {"DoubleXP": 123, "DoubleCoins": 456, "VIP": 789, "Coins500": 1, "Coins1500": 2, "Coins5000": 3}
Seules les clés présentes sont modifiées. Usage : tools/apply_ids.py [ids.json] [Config.luau]
"""
import json, os, re, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ids_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "publication", "ids.json")
cfg_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(root, "src/ReplicatedStorage/Shared/Config.luau")
ids = json.load(open(ids_path, encoding="utf-8"))
text = open(cfg_path, encoding="utf-8").read()
done = []
for key, value in ids.items():
    if not isinstance(value, int) or value < 0:
        sys.exit(f"Id invalide pour {key} : {value!r}")
    text, n = re.subn(rf'(Key = "{re.escape(key)}", Id = )\d+', rf"\g<1>{value}", text)
    if n != 1:
        sys.exit(f"Clé inconnue ou ambiguë : {key}")
    done.append(key)
open(cfg_path, "w", encoding="utf-8").write(text)
print("Id appliqués :", ", ".join(done) or "(aucun)")
