#!/usr/bin/env python3
"""Contrôle structurel minimal des fichiers Luau (sans binaire externe).

Vérifie : équilibre function/if/for/while/repeat ↔ end/until, parenthèses, crochets, accolades,
guillemets non fermés. Heuristique : un `if` en début de ligne est une instruction ; au milieu
d'une ligne c'est une expression (sans `end`). Ne remplace PAS luau-analyze / selene.
"""
import re, sys, pathlib

def strip(src):
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith('--[[', i) or src.startswith('--[=[', i):
            m = re.match(r'--\[(=*)\[', src[i:]); close = ']' + m.group(1) + ']'
            j = src.find(close, i); j = n if j < 0 else j + len(close)
            out.append('\n' * src[i:j].count('\n')); i = j
        elif src.startswith('--', i):
            j = src.find('\n', i); i = n if j < 0 else j
        elif c in '"\'':
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == '\\': j += 1
                if src[j] == '\n': raise ValueError('guillemet non fermé')
                j += 1
            out.append('""'); i = j + 1
        elif src.startswith('[[', i) or src.startswith('[=[', i):
            m = re.match(r'\[(=*)\[', src[i:]); close = ']' + m.group(1) + ']'
            j = src.find(close, i); j = n if j < 0 else j + len(close)
            out.append('""' + '\n' * src[i:j].count('\n')); i = j
        else:
            out.append(c); i += 1
    return ''.join(out)

def check(path):
    errs = []
    try: src = strip(path.read_text(encoding='utf-8'))
    except ValueError as e: return [str(e)]
    opens = closes = 0
    for line in src.split('\n'):
        toks = re.findall(r'[A-Za-z_][A-Za-z0-9_]*', line)
        first = True
        for t in toks:
            if t in ('function', 'for', 'while', 'repeat'): opens += 1
            elif t == 'if' and first: opens += 1
            elif t in ('end', 'until'): closes += 1
            first = False
    if opens != closes: errs.append(f'blocs : {opens} ouvrants / {closes} fermants')
    for a, b in ('()', '[]', '{}'):
        if src.count(a) != src.count(b): errs.append(f'{a}{b} : {src.count(a)} / {src.count(b)}')
    return errs

def main():
    bad = 0
    for p in sorted(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'src').rglob('*.luau')):
        e = check(p)
        print(('KO ' if e else 'ok ') + str(p), '; '.join(e))
        bad += bool(e)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
