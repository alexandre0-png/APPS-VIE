#!/usr/bin/env python3
"""Envoie dist/FestinDuTRex.rbxlx sur Roblox via l'API Open Cloud « Place Publishing ».

  python3 tools/publish_place.py --universe 123 --place 456            # simulation (rien n'est envoyé)
  python3 tools/publish_place.py --universe 123 --place 456 --go       # envoi réel, version PUBLIÉE
  python3 tools/publish_place.py --universe 123 --place 456 --go --saved   # envoi en « Saved » (non publié)

Clé API : elle n'est jamais lue ni affichée par ce script. Dans l'environnement Claude, un proxy
ajoute l'en-tête x-api-key. Hors de cet environnement, exporter ROBLOX_API_KEY.
Permission requise sur la clé : universe-places:write pour cette expérience.
ATTENTION : --go remplace la version en ligne de cette place.
"""
import argparse, os, sys, urllib.request, urllib.error

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--universe', required=True, type=int)
    ap.add_argument('--place', required=True, type=int)
    ap.add_argument('--file', default=os.path.join(os.path.dirname(__file__), '..', 'dist', 'FestinDuTRex.rbxlx'))
    ap.add_argument('--go', action='store_true', help="envoi réel (sinon simulation)")
    ap.add_argument('--saved', action='store_true', help="versionType=Saved au lieu de Published")
    a = ap.parse_args()

    path = os.path.abspath(a.file)
    if not os.path.isfile(path):
        sys.exit(f"Fichier introuvable : {path} (lancer tools/build_rbxlx.py)")
    version_type = 'Saved' if a.saved else 'Published'
    url = f"https://apis.roblox.com/universes/v1/{a.universe}/places/{a.place}/versions?versionType={version_type}"
    size = os.path.getsize(path)
    print(f"POST {url}\n  fichier : {path} ({size // 1024} Ko)\n  type    : {version_type}")
    if not a.go:
        print("Simulation : rien envoyé. Ajouter --go pour publier.")
        return

    with open(path, 'rb') as f:
        body = f.read()
    # Valeur factice : le proxy de l'environnement remplace l'en-tête par la vraie clé.
    key = os.environ.get('ROBLOX_API_KEY', 'proxy-injected')
    req = urllib.request.Request(url, data=body, method='POST',
                                 headers={'x-api-key': key, 'Content-Type': 'application/xml'})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            print('HTTP', r.status, r.read().decode()[:300])
    except urllib.error.HTTPError as e:
        print('HTTP', e.code, e.read().decode()[:500])
        sys.exit(1)

if __name__ == '__main__':
    main()
