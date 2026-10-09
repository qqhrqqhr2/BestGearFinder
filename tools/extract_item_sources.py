#!/usr/bin/env python3
"""사이트의 공략 페이지(BiS·레벨업 가이드·30레벨·새소식·퀘스트·지역 등) 안에 붙어 있는 장비 획득처를 모아 ItemSources.lua 를 만든다.

사용법:  DUNGEON_DATA_BASE=<사이트 주소/en> python3 tools/extract_item_sources.py --cache DIR --out ItemSources.lua
  sitemap.xml 의 영어 페이지를 모두 받아(캐시), 아이템마다 붙은 how / where / source / sub / quest / href / faction 을 읽는다.
  - 던전 드랍 "던전 · 보스"      -> drops
  - 퀘스트 보상 (퀘스트 ID 포함)  -> quests (진영 정보가 있으면 side)
  - 상인 "Vendor · 이름"           -> vendors
  - 희귀 몹 / 월드 드랍 / 도서관 책 등 -> drops (inst 에 종류)
  제작템은 CraftData.lua 가 다루므로 건너뛴다. 장비(부위가 있는 아이템)만 담는다.
"""
import os, re, json, time, argparse, urllib.request
from pathlib import Path

BASE = os.environ.get("DUNGEON_DATA_BASE", "")
ROOT = BASE[:-3] if BASE.endswith("/en") else BASE
DUNGEON_KO = {"wailing-caverns": "통곡의 동굴", "blackfathom-deeps": "검은심연의 나락", "gnomeregan": "놈리건",
    "razorfen-kraul": "가시덩굴 우리", "deadmines": "죽음의 폐광", "shadowfang-keep": "그림자송곳니 성채",
    "stockade": "스톰윈드 지하감옥", "razorfen-downs": "가시덩굴 구릉", "uldaman": "울다만", "ragefire-chasm": "성난불길 협곡",
    "scarlet-monastery-graveyard": "붉은십자군 수도원", "scarlet-monastery-library": "붉은십자군 수도원",
    "scarlet-monastery-armory": "붉은십자군 수도원", "scarlet-monastery-cathedral": "붉은십자군 수도원",
    "dalaran": "달라란", "hall-of-thanes": "영주의 전당", "ruins-of-lordaeron": "로데론의 폐허", "excavation-site": "발굴 현장: 저습지"}

def get(path, cache):
    fn = Path(cache) / (path.strip("/").replace("/", "_") + ".html")
    if fn.exists(): return fn.read_text(encoding="utf-8")
    try:
        req = urllib.request.Request(ROOT + path, headers={"User-Agent": "Mozilla/5.0 BestGearFinder-data"})
        h = urllib.request.urlopen(req, timeout=60).read().decode("utf-8")
    except Exception:
        h = ""
    fn.parent.mkdir(parents=True, exist_ok=True); fn.write_text(h, encoding="utf-8"); time.sleep(0.15)
    return h

def flight(h):
    parts = re.findall(r'self\.__next_f\.push\(\[1,"(.*?)"\]\)</script>', h, flags=re.S)
    return "".join(json.loads('"' + p + '"') for p in parts)

def U(v): return None if v in (None, "$undefined") else v

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--cache", default="site_cache"); ap.add_argument("--out", default="ItemSources.lua")
    a = ap.parse_args()
    sm = get("/sitemap.xml", a.cache)
    paths = sorted(set(re.findall(r"<loc>%s(/en/[^<]+)</loc>" % re.escape(ROOT), sm)))
    drops, quests, vendors, names = {}, {}, {}, {}
    def add(tbl, iid, e, key):
        lst = tbl.setdefault(iid, [])
        if not any(all(x.get(k) == e.get(k) for k in key) for x in lst): lst.append(e)
    def pair(en, ko):
        if en and ko and en != ko and en not in names: names[en] = ko
    dec = json.JSONDecoder()

    def wrappers(t):
        out = []
        for m in re.finditer(r'\{"item":\{"id":(\d+)', t):
            try: o, _ = dec.raw_decode(t[m.start():])
            except ValueError: continue
            out.append((int(m.group(1)), o))
        return out

    def text_of(o):
        x = U(o.get("where")) or (o.get("source")[0] if isinstance(o.get("source"), list) and o.get("source") else None) or U(o.get("sub"))
        return x if isinstance(x, str) and x else None

    def quest_title(parts):
        if parts[0] in ("Quest rewards", "퀘스트 보상") and len(parts) > 1: return parts[1]
        t = parts[-1]
        m = re.match(r"Reward from (.+)", t) or re.match(r"(.+) 보상$", t)
        return m.group(1) if m else t

    for p in paths:
        h = get(p, a.cache)
        if not h: continue
        hk = get(p.replace("/en/", "/ko/", 1), a.cache)
        W = wrappers(flight(h))
        K = {}
        for iid, o in (wrappers(flight(hk)) if hk else []):
            K.setdefault(iid, []).append(o)
        for iid, o in W:
            ko = K.get(iid).pop(0) if K.get(iid) else None
            it = o.get("item") or {}
            if U(it.get("slot")) is None: continue          # 장비만
            how = U(o.get("how"))
            text = text_of(o)
            if not text: continue
            ktext = text_of(ko) if ko else None
            href = U(o.get("href")) or U(o.get("sourceHref")) or ""
            if not isinstance(href, str): href = ""
            side = U(o.get("faction")) or "both"
            if how == "craft" or text.startswith("Crafted"): continue
            qid = None
            q = o.get("quest") if isinstance(o.get("quest"), dict) else None
            if q: qid = q.get("id") or q.get("quest")
            if not qid:
                mm = re.search(r"/quests/(\d+)|#quest-(\d+)|#q-(\d+)", href)
                if mm: qid = int(next(g for g in mm.groups() if g))
            parts = [x.strip() for x in text.split(" · ")]
            kparts = [x.strip() for x in ktext.split(" · ")] if ktext else None
            if kparts and len(kparts) != len(parts): kparts = None
            dslug = (re.search(r"/dungeons/([a-z0-9-]+)", href) or [None, None])[1]
            if qid and ("Quest" in text or "Reward from" in text or how in ("quest", "world")):
                ten = quest_title(parts)
                tko = quest_title(kparts) if kparts else None
                add(quests, iid, {"qid": int(qid), "title": tko or ten, "titleEn": ten, "side": side}, ("qid",))
            elif parts[0] == "Vendor" and len(parts) >= 2:
                add(vendors, iid, {"zone": parts[2] if len(parts) > 2 else "?", "boss": parts[1]}, ("boss",))
                if kparts:
                    pair(parts[1], kparts[1])
                    if len(parts) > 2: pair(parts[2], kparts[2])
            elif how == "drop" and dslug and len(parts) >= 2:
                add(drops, iid, {"inst": DUNGEON_KO.get(dslug, parts[0]), "boss": parts[1]}, ("inst", "boss"))
                if kparts: pair(parts[1], kparts[1])
            elif parts[0] == "Rares" and len(parts) >= 2:
                add(drops, iid, {"inst": "Rare", "boss": parts[1]}, ("inst", "boss"))
                if kparts: pair(parts[1], kparts[1])
            elif text == "World drop":
                add(drops, iid, {"inst": "World drop", "boss": ""}, ("inst",))
            elif how == "discovery":
                add(drops, iid, {"inst": parts[0], "boss": " · ".join(parts[1:])}, ("inst", "boss"))
                if kparts: pair(parts[0], kparts[0]); pair(" · ".join(parts[1:]), " · ".join(kparts[1:]))
    # PvP 장비 세트 (명예 보상): 세트 이름과 진영
    t = flight(get("/en/pvp/gear", a.cache) or "")
    for m in re.finditer(r'\{"id":\d+,"name":"[^"]+","faction":"', t):
        try: o, _ = dec.raw_decode(t[m.start():])
        except ValueError: continue
        for pc in o.get("pieces") or []:
            if isinstance(pc, dict) and isinstance(pc.get("id"), int):
                add(vendors, pc["id"], {"zone": "PvP", "boss": o.get("name") or "PvP", "side": U(o.get("faction")) or "both"}, ("boss",))
    q = lambda s: json.dumps(s, ensure_ascii=False)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write("-- AUTO-GENERATED by tools/extract_item_sources.py. Do not hand edit.\n-- Gear sources noted on guide pages (dungeon drops, quest rewards with faction, vendors, rares, world drops).\n")
        f.write("local _, ns = ...\nns.ItemSources = {\n    drops = {\n")
        for iid in sorted(drops): f.write("        [%d] = { %s },\n" % (iid, ", ".join("{inst=%s, boss=%s}" % (q(x["inst"]), q(x["boss"])) for x in drops[iid])))
        f.write("    },\n    quests = {\n")
        for iid in sorted(quests): f.write("        [%d] = { %s },\n" % (iid, ", ".join("{qid=%d, title=%s, titleEn=%s, side=%s, lvl=0}" % (x["qid"], q(x["title"]), q(x["titleEn"]), q(x["side"])) for x in quests[iid])))
        f.write("    },\n    vendors = {\n")
        for iid in sorted(vendors): f.write("        [%d] = { %s },\n" % (iid, ", ".join("{zone=%s, boss=%s, side=%s}" % (q(x["zone"]), q(x["boss"]), q(x.get("side", "both"))) for x in vendors[iid])))
        f.write("    },\n    -- 영어 이름 -> 한국어 (보스·희귀 몹·상인·평판 등)\n    names = {\n")
        for en in sorted(names): f.write("        [%s] = %s,\n" % (q(en), q(names[en])))
        f.write("    },\n}\n")
    print("names", len(names), "pages", len(paths), "drops", len(drops), "quests", len(quests), "vendors", len(vendors))

if __name__ == "__main__":
    main()
