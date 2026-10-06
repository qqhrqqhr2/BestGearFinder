#!/usr/bin/env python3
"""ATT(AllTheThings)의 WoW Forever 데이터에서 신규 아이템의 획득처를 뽑아 ForeverExtra.lua 로 만든다.

사용법:
  git clone --depth 1 https://github.com/ATTWoWAddon/AllTheThings.git att
  python tools/extract_att_forever.py att/.contrib/.db/forever \
      --geardb GearDatabase.lua --quests QuestData.lua --out ForeverExtra.lua

원본: https://github.com/ATTWoWAddon/AllTheThings (MIT License, Copyright (c) 2026 AllTheThings WoW Addon)
CMaNGOS 데이터(GearDatabase.lua / QuestData.lua)에 이미 있는 아이템은 제외하고, 그 외 아이템만 담는다.
"""
import re, os, sys, json, argparse, subprocess


TOK = re.compile(r'''
  (?P<comment>--[^\n]*)
 |(?P<string>"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')
 |(?P<number>0x[0-9a-fA-F]+|\d+\.?\d*)
 |(?P<ident>[A-Za-z_][A-Za-z_0-9]*)
 |(?P<punct>\.\.|==|~=|<=|>=|[{}()\[\],=.+\-*/%<>:;#^])
 |(?P<ws>\s+)
''', re.X)

def tokenize(text):
    toks=[]; line=1; pos=0
    # strip long comments --[[ ]]
    text=re.sub(r'--\[\[.*?\]\]', lambda m:'\n'*m.group(0).count('\n'), text, flags=re.S)
    n=len(text)
    while pos<n:
        m=TOK.match(text,pos)
        if not m:
            pos+=1; continue
        k=m.lastgroup; v=m.group(0)
        if k=='ws':
            line+=v.count('\n')
        else:
            toks.append((k,v,line))
        pos=m.end()
    return toks

class P:
    def __init__(s,toks): s.t=toks; s.i=0
    def peek(s,o=0):
        return s.t[s.i+o] if s.i+o<len(s.t) else ('eof','',0)
    def next(s):
        x=s.peek(); s.i+=1; return x
    def skip_comments(s):
        pass

def parse(toks):
    # comments are kept in token stream; collect them by line for node attachment
    comments={}
    clean=[]
    for k,v,l in toks:
        if k=='comment':
            comments.setdefault(l,v[2:].strip())
        else:
            clean.append((k,v,l))
    p=P(clean)
    def expr():
        node=primary()
        while p.peek()[0]=='punct' and p.peek()[1] in ('..','+','-','*','/','%','==','~=','<=','>=','<','>','^'):
            p.next(); primary()
        return node
    def primary():
        k,v,l=p.peek()
        if k=='punct' and v=='-':
            p.next(); return primary()
        if k=='punct' and v=='#':
            p.next(); return primary()
        if k=='punct' and v=='(':
            p.next(); e=expr()
            if p.peek()[1]==')': p.next()
            return e
        if k=='punct' and v=='{':
            return table()
        if k=='number':
            p.next(); return {'t':'num','v':float(int(v,16)) if v.startswith('0x') else float(v)}
        if k=='string':
            p.next(); return {'t':'str','v':v[1:-1]}
        if k=='ident':
            p.next(); name=v; line=l
            node={'t':'name','v':name}
            # postfix: .x [..] (..) :x(..)
            while True:
                k2,v2,l2=p.peek()
                if k2=='punct' and v2=='.':
                    p.next(); a=p.next(); node={'t':'name','v':node.get('v','')+'.'+a[1]}
                elif k2=='punct' and v2==':':
                    p.next(); a=p.next(); node={'t':'name','v':node.get('v','')+':'+a[1]}
                elif k2=='punct' and v2=='[':
                    p.next(); expr()
                    if p.peek()[1]==']': p.next()
                elif k2=='punct' and v2=='(':
                    p.next(); args=[]
                    while p.peek()[1]!=')' and p.peek()[0]!='eof':
                        args.append(expr())
                        if p.peek()[1]==',': p.next()
                        elif p.peek()[1]!=')': break
                    if p.peek()[1]==')': p.next()
                    node={'t':'call','fn':node.get('v',''),'args':args,'line':line}
                elif k2=='string' and node['t']=='name' and node['v'] in ('L',):
                    p.next(); node={'t':'str','v':v2[1:-1]}
                else: break
            return node
        if k=='string':
            p.next(); return {'t':'str','v':v}
        p.next(); return {'t':'junk'}
    def table():
        p.next() # {
        items=[]; kv={}
        while p.peek()[1]!='}' and p.peek()[0]!='eof':
            k,v,l=p.peek()
            # key = value
            if k=='ident' and p.peek(1)[1]=='=' and p.peek(2)[1]!='=':
                key=v; p.next(); p.next(); val=expr(); kv[key]=val
            elif k=='punct' and v=='[':
                p.next(); key=expr()
                if p.peek()[1]==']': p.next()
                if p.peek()[1]=='=':
                    p.next(); val=expr(); kv[key.get('v') if isinstance(key,dict) else None]=val
            else:
                items.append(expr())
            if p.peek()[1] in (',',';'): p.next()
            elif p.peek()[1]!='}': 
                # unexpected; advance to avoid loop
                if p.peek()[1] not in ('}',): p.next()
        if p.peek()[1]=='}': p.next()
        return {'t':'table','items':items,'kv':kv}
    tops=[]
    while p.peek()[0]!='eof':
        before=p.i
        tops.append(expr())
        if p.i==before: p.next()
    return tops, comments


# ---------------------------------------------------------------- walker
def clean(c):
    c = re.sub(r'<[^>]*>', '', c or '')
    c = re.sub(r'\(\d+/\d+\)', '', c)
    c = re.sub(r'\s+', ' ', c).strip()
    return c

PROF_KO = {
    'ALCHEMY': '연금술', 'BLACKSMITHING': '대장기술', 'COOKING': '요리', 'ENCHANTING': '마법부여',
    'ENGINEERING': '기계공학', 'FIRST_AID': '응급치료', 'LEATHERWORKING': '가죽세공',
    'TAILORING': '재봉술', 'MINING': '채광',
    'WEAPONSMITH': '대장기술', 'ARMORSMITH': '대장기술', 'MASTER_SWORDSMITH': '대장기술',
    'MASTER_HAMMERSMITH': '대장기술', 'MASTER_AXESMITH': '대장기술',
}
PROF_ID = {10656: '가죽세공', 10658: '가죽세공', 10660: '가죽세공'}

def zone_name(path):
    stem = os.path.splitext(os.path.basename(path))[0]
    stem = re.sub(r'^\d+(\.\d+)?\s*-\s*', '', stem)
    return ' '.join(w.capitalize() for w in stem.split())

def walk_file(path, kind_dir):
    text = open(path, encoding='utf-8', errors='replace').read()
    tops, comments = parse(tokenize(text))
    out = []
    zone = zone_name(path) if kind_dir == 'zones' else None
    def num(a):
        return int(a['v']) if a and a['t'] == 'num' else None
    def kvnum(tbl, key):
        if tbl and tbl['t'] == 'table':
            v = tbl['kv'].get(key)
            if v and v['t'] == 'num': return int(v['v'])
        return None
    def visit(node, ctx):
        if not isinstance(node, dict): return
        t = node['t']
        if t == 'table':
            for it in node['items']: visit(it, ctx)
            for v in node['kv'].values(): visit(v, ctx)
            return
        if t != 'call': return
        fn, args = node['fn'], node['args']
        first = args[0] if args else None
        fid = num(first)
        name = clean(comments.get(node['line'], ''))
        c = dict(ctx)
        if fn == 'inst' and fid is not None:
            c.update(inst=name or str(fid), boss=None, mode='drop', npc=None)
        elif fn in ('n', 'cr', 'npc', 'boss', 'o') and fid is not None:
            c.update(boss=name or None, npc=fid)
        elif fn == 'n' and first and first['t'] == 'name':
            h = first['v']
            c['hdr'] = h
            if h == 'QUESTS': c['mode'] = 'quest'
            elif h == 'VENDORS': c['mode'] = 'vendor'
            elif h in ('RARES', 'ZONE_DROPS', 'WORLD_BOSSES', 'TREASURES'): c['mode'] = 'zonedrop'
            elif h in ('ACHIEVEMENTS', 'FACTIONS', 'FLIGHT_PATHS', 'SPECIAL', 'RIDING_TRAINER', 'FACTION'): c['mode'] = 'skip'
            if h in ('ZONE_DROPS',): c['boss'] = None
        elif fn == 'q' and fid is not None:
            lvl = None
            for a in args[1:]:
                lvl = lvl or kvnum(a, 'lvl')
            c.update(mode='quest', qid=fid, qtitle=name, qlvl=lvl)
        elif fn in ('objective', 'achievement', 'ach', 'faction', 'flight', 'fp'):
            c['mode'] = 'skip'
        elif fn == 'prof' and first:
            p = None
            if first['t'] == 'name': p = PROF_KO.get(first['v'])
            elif first['t'] == 'num': p = PROF_ID.get(int(first['v']))
            if p: c['prof'] = p
            if not c.get('mode'): c['mode'] = 'craft'
        elif fn == 'i' and fid is not None:
            m = ctx.get('mode')
            if m == 'quest' and ctx.get('qid'):
                out.append(dict(id=fid, kind='quest', qid=ctx['qid'], title=ctx.get('qtitle') or '', lvl=ctx.get('qlvl')))
            elif m == 'vendor' and ctx.get('boss'):
                out.append(dict(id=fid, kind='vendor', zone=ctx.get('inst') or zone or '', boss=ctx['boss'], npc=ctx.get('npc')))
            elif m == 'drop' and ctx.get('inst') and ctx.get('boss'):
                out.append(dict(id=fid, kind='drop', inst=ctx['inst'], boss=ctx['boss'], npc=ctx.get('npc')))
            elif m == 'zonedrop' and zone and ctx.get('boss'):
                out.append(dict(id=fid, kind='drop', inst=zone, boss=ctx['boss'], npc=ctx.get('npc')))
            elif m == 'craft' and ctx.get('prof'):
                out.append(dict(id=fid, kind='craft', skill=ctx['prof']))
            for a in args[1:]: visit(a, dict(c, mode='skip') if False else c)
            return
        for a in args: visit(a, c)
    for n in tops: visit(n, {})
    return out

def collect(root):
    rows = []
    for dp, dn, fns in os.walk(root):
        rel = os.path.relpath(dp, root)
        if '.wago' in dp or 'Missing' in dp or 'zzOLD' in dp or rel.startswith('.'): continue
        top = rel.split(os.sep)[0] if rel != '.' else ''
        if top in ('dungeons & raids', 'zones', 'crafted items', 'world drops', 'profession db', 'pvp'):
            pass
        for f in sorted(fns):
            if not f.endswith('.lua') or f.startswith('.'): continue
            p = os.path.join(dp, f)
            kd = 'zones' if top == 'zones' else ('dungeons' if top == 'dungeons & raids' else top)
            rows += walk_file(p, kd)
    return rows

def known_ids(geardb, quests):
    ids = set()
    if geardb and os.path.exists(geardb):
        t = open(geardb, encoding='utf-8', errors='replace').read()
        ids |= {int(x) for x in re.findall(r'^\s*\[(\d+)\]\s*=\s*\{', t, re.M)}
    if quests and os.path.exists(quests):
        t = open(quests, encoding='utf-8', errors='replace').read()
        for m in re.finditer(r'^\[\d+\]=\{[^{]*\{([^}]*)\},\{([^}]*)\}\}', t, re.M):
            for g in m.groups():
                ids |= {int(x) for x in re.findall(r'\d+', g)}
    return ids

def inst_ko(locales):
    """Locales.lua 의 한국어->영어 표에서 영어 던전 이름 -> 한국어 이름을 만든다."""
    m = {}
    if locales and os.path.exists(locales):
        t = open(locales, encoding='utf-8').read()
        for ko, en in re.findall(r'\["([^"]+)"\]\s*=\s*"([^"]*)"', t):
            if re.search(r'[가-힣]', ko) and not re.search(r'[가-힣]', en):
                m.setdefault(en.lower(), ko)
    return m

def lua_str(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('root')
    ap.add_argument('--geardb', default='GearDatabase.lua')
    ap.add_argument('--quests', default='QuestData.lua')
    ap.add_argument('--locales', default='Locales.lua')
    ap.add_argument('--out', default='ForeverExtra.lua')
    ap.add_argument('--commit', default='')
    a = ap.parse_args()
    rows = collect(a.root)
    have = known_ids(a.geardb, a.quests)
    ko = inst_ko(a.locales)
    drops, quests, vend, craft = {}, {}, {}, {}
    def add(d, k, v):
        lst = d.setdefault(k, [])
        if v not in lst: lst.append(v)
    for r in rows:
        i = r['id']
        if i in have: continue
        if r['kind'] == 'drop':
            add(drops, i, (ko.get(r['inst'].lower(), r['inst']), r['boss'], r.get('npc') or 0))
        elif r['kind'] == 'quest':
            add(quests, i, (r['qid'], r['title'], r['lvl'] or 0))
        elif r['kind'] == 'vendor':
            add(vend, i, (r['zone'], r['boss'], r.get('npc') or 0))
        elif r['kind'] == 'craft':
            add(craft, i, (r['skill'],))
    lines = ['-- AUTO-GENERATED by tools/extract_att_forever.py',
             '-- Source: AllTheThings (ATT) WoW Forever database, https://github.com/ATTWoWAddon/AllTheThings',
             '-- ATT is licensed under the MIT License, Copyright (c) 2026 AllTheThings WoW Addon (see LICENSE-ATT.txt).',
             '-- Only items that are not in the CMaNGOS 1.12 data are listed here.',
             'local _, ns = ...',
             'ns.ForeverExtra = {',
             '    version = %s,' % lua_str('ATT ' + a.commit),
             ]
    def emit(name, d, fmt):
        lines.append('    %s = {' % name)
        for i in sorted(d):
            lines.append('        [%d] = { %s },' % (i, ', '.join(fmt(x) for x in d[i])))
        lines.append('    },')
    emit('drops', drops, lambda x: '{inst=%s, boss=%s, npc=%d}' % (lua_str(x[0]), lua_str(x[1]), x[2]))
    emit('quests', quests, lambda x: '{qid=%d, title=%s, lvl=%d}' % (x[0], lua_str(x[1]), x[2]))
    emit('vendors', vend, lambda x: '{zone=%s, boss=%s, npc=%d}' % (lua_str(x[0]), lua_str(x[1]), x[2]))
    emit('craft', craft, lambda x: '{skill=%s}' % lua_str(x[0]))
    lines.append('}')
    open(a.out, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    print('drops %d  quests %d  vendors %d  craft %d  -> %s' % (len(drops), len(quests), len(vend), len(craft), a.out))

if __name__ == '__main__':
    main()
