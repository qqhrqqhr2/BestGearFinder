#!/usr/bin/env python3
"""CMaNGOS Classic-DB -> LevelBiS GearDatabase.lua   (v3)

입력: ClassicDB_1_12_1_z2815.sql 또는 .sql.gz
출력: 던전/레이드 드랍(보스+일반몹), 전문기술 제작 정보를 담은 Lua 테이블

v1 대비 수정 사항
  * INSERT 문에 컬럼 목록이 없는 덤프라서, CREATE TABLE 에서 읽은 '컬럼 이름'으로 값을 찾는다.
    (v1 은 col_N 번호를 추측해서 이름/레벨/LootId 가 전부 틀어졌다)
  * 참조 드랍(mincountOrRef < 0)은 item 컬럼이 아니라 -mincountOrRef 가 참조 테이블 번호다.
    v1 은 이걸 아이템으로 착각해서, 참조로 나오는 드랍이 통째로 빠졌다.
  * creature_template.LootId 를 올바르게 사용한다 (LootId != Entry 인 몬스터 누락 해결).
  * 던전 맵 번호 오류 수정 (그림자송곳니 성채 33 추가, 90 은 놈리건, 성난불길 협곡 389 추가).
  * 장비(무기/방어구, 고급 이상)만 저장해서 파일 크기를 줄인다.
"""
from __future__ import annotations
import argparse, gzip, re, sys, time
from collections import defaultdict
from pathlib import Path

# ----------------------------------------------------------------------------
# 던전/레이드 맵 (클래식 1.12)
# ----------------------------------------------------------------------------
INSTANCE_MAPS = {
    33: "그림자송곳니 성채", 34: "스톰윈드 지하감옥", 36: "죽음의 폐광", 43: "통곡의 동굴",
    47: "가시덩굴 우리", 48: "검은심연의 나락", 70: "울다만", 90: "놈리건",
    109: "가라앉은 사원", 129: "가시덩굴 구릉", 189: "붉은십자군 수도원", 209: "줄파락",
    229: "검은바위 첨탑", 230: "검은바위 나락", 249: "오닉시아의 둥지", 289: "스칼로맨스",
    309: "줄구룹", 329: "스트라솔름", 349: "마라우돈", 389: "성난불길 협곡",
    409: "화산 심장부", 429: "혈투의 전장", 469: "검은날개 둥지", 509: "안퀴라즈 폐허",
    531: "안퀴라즈 사원", 533: "낙스라마스",
}
WORLD_MAPS = {0: "야외 (동부 왕국)", 1: "야외 (칼림도어)"}

WORLD_BOSS = -1      # 야외에 나타나는 월드 보스(용 4마리, 카자크, 아주어고스 등)
SCRIPT_BOSSES = {
    # CMaNGOS 에는 스크립트(C++)로 소환되는 몬스터의 스폰 정보가 없어서 맵을 직접 지정한다.
    11502: 409, 11664: 409, 11663: 409,                         # 화산 심장부: 라그나로스, 불꽃인도자 정예/치유사
    11583: 469,                                                  # 검은날개 둥지: 네파리안
    1853: 289, 10506: 289, 16118: 289, 14516: 289,               # 스칼로맨스: 간들링, 키르토노스, 코르모크, 다크리버
    10813: 329, 10439: 329, 11143: 329, 16102: 329, 16101: 329, 10808: 329,   # 스트라솔름
    10429: 229, 16042: 229, 10339: 229, 10264: 229,              # 검은바위 첨탑(상층): 렌드, 발타라크, 기스, 솔라카르
    16080: 229, 10584: 229, 10268: 229, 10263: 229,              # 검은바위 첨탑(하층)
    15989: 533,                                                  # 낙스라마스: 사피론
    15517: 531,                                                  # 안퀴라즈 사원: 아우로
    16097: 429, 14506: 429,                                      # 혈투의 전장
    8443: 109, 5717: 109, 5716: 109, 5715: 109, 5714: 109, 5713: 109, 5712: 109, 8580: 109,   # 가라앉은 사원
    9537: 230, 9032: 230, 9031: 230, 9030: 230, 9029: 230, 9028: 230, 9027: 230,              # 검은바위 나락
    8927: 230, 16095: 230, 8933: 230, 8932: 230, 8926: 230, 8925: 230,
    7228: 70,                                                    # 울다만: 이로나야
    7275: 209, 7273: 209,                                        # 줄파락
    7355: 129, 7356: 129,                                        # 가시덩굴 구릉
    3654: 43, 3671: 43,                                          # 통곡의 동굴
    7361: 90, 643: 36, 4627: 33, 14693: 189,                     # 놈리건, 죽음의 폐광, 그림자송곳니, 붉은십자군 수도원
    15114: 309, 15085: 309, 15084: 309, 15083: 309, 15082: 309,  # 줄구룹(광기의 경계 보스)
    14888: WORLD_BOSS, 14887: WORLD_BOSS, 14890: WORLD_BOSS, 14889: WORLD_BOSS,   # 녹색 용 4마리
    6109: WORLD_BOSS, 12397: WORLD_BOSS,                                           # 아즈골고스, 카자크 경
}

PROFESSIONS = {164: "대장기술", 165: "가죽세공", 197: "재봉술", 202: "기계공학"}   # 장비를 만드는 전문기술
# 장비가 아닌 전문기술(연금술/요리/마부 등)은 결과 아이템이 장비가 아니라 자동으로 걸러진다.
ALL_PROF_NAMES = {164: "대장기술", 165: "가죽세공", 171: "연금술", 197: "재봉술", 202: "기계공학",
                  333: "마법부여", 185: "요리", 129: "응급치료", 186: "채광"}
RECIPE_SUBCLASS_SKILL = {1: 165, 2: 197, 3: 202, 4: 164, 5: 185, 6: 171, 7: 129, 8: 333}

SPELL_EFFECT_CREATE_ITEM = 24
SPELL_EFFECT_LEARN_SPELL = 36

WANT = {
    "creature_template": ["entry", "name", "minlevel", "rank", "lootid"],
    "creature": ["guid", "id", "map"],
    "creature_spawn_entry": ["guid", "entry"],
    "creature_loot_template": ["entry", "item", "chanceorquestchance", "groupid", "mincountorref", "maxcount"],
    "reference_loot_template": ["entry", "item", "chanceorquestchance", "groupid", "mincountorref", "maxcount"],
    "item_template": ["entry", "class", "subclass", "quality", "inventorytype", "requiredlevel", "requiredskill",
                      "requiredskillrank", "spellid_1", "spellid_2", "spellid_3", "spellid_4", "spellid_5"],
    "gameobject": ["id", "map"],
    "gameobject_template": ["entry", "type", "name", "data1"],
    "gameobject_loot_template": ["entry", "item", "chanceorquestchance", "groupid", "mincountorref", "maxcount"],
    "npc_trainer": ["spell", "reqskill", "reqskillvalue", "reqlevel"],
    "npc_trainer_template": ["spell", "reqskill", "reqskillvalue", "reqlevel"],
    "spell_template": ["id", "effect1", "effect2", "effect3", "effectitemtype1", "effectitemtype2",
                       "effectitemtype3", "effecttriggerspell1", "effecttriggerspell2", "effecttriggerspell3"],
}

# ----------------------------------------------------------------------------
# SQL 파서
# ----------------------------------------------------------------------------
TOKEN = re.compile(r"'((?:[^'\\]|\\.|'')*)'|(NULL)|(-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)|([(),;])", re.S)
UNESC = {"n": "\n", "r": "\r", "t": "\t", "0": "\0", "Z": "\x1a", "b": "\b"}
UNESC_RE = re.compile(r"\\(.)|''", re.S)

def _unescape(s: str) -> str:
    if "\\" not in s and "''" not in s:
        return s
    return UNESC_RE.sub(lambda m: "'" if m.group(0) == "''" else UNESC.get(m.group(1), m.group(1)), s)

def parse_values(s: str):
    rows, cur = [], None
    for m in TOKEN.finditer(s):
        q, null, num, p = m.groups()
        if p:
            if p == "(":
                cur = []
            elif p == ")":
                if cur is not None:
                    rows.append(cur)
                cur = None
        elif cur is not None:
            if q is not None:
                cur.append(_unescape(q))
            elif null:
                cur.append(None)
            else:
                cur.append(float(num) if ("." in num or "e" in num or "E" in num) else int(num))
    return rows

def open_text(path: Path):
    if path.suffix.lower() == ".gz":
        return gzip.open(path, "rt", encoding="utf-8", errors="replace", newline="")
    return open(path, "rt", encoding="utf-8", errors="replace", newline="")

CREATE_RE = re.compile(r"^CREATE TABLE `([A-Za-z0-9_]+)`")
COL_RE = re.compile(r"^\s+`([A-Za-z0-9_]+)`\s")
INSERT_RE = re.compile(r"^INSERT INTO `([A-Za-z0-9_]+)`\s*(?:\(([^)]*)\)\s*)?VALUES\s*", re.I)

def load_tables(path: Path):
    """필요한 테이블만 읽어서 {테이블: [ {소문자컬럼: 값} ... ]} 로 돌려준다."""
    data = {t: [] for t in WANT}
    columns = {}
    t0 = time.time()
    with open_text(path) as f:
        in_create, create_name, create_cols = False, None, []
        pending, pending_table, pending_cols = None, None, None
        for line in f:
            if in_create:
                m = COL_RE.match(line)
                if m:
                    create_cols.append(m.group(1).lower())
                elif line.startswith(")"):
                    columns[create_name] = create_cols
                    in_create = False
                continue
            if pending is not None:
                pending.append(line)
                if line.rstrip().endswith(";"):
                    _flush(data, pending_table, pending_cols or columns.get(pending_table), "".join(pending))
                    pending = None
                continue
            if line.startswith("CREATE TABLE"):
                m = CREATE_RE.match(line)
                if m and m.group(1) in WANT:
                    in_create, create_name, create_cols = True, m.group(1), []
                continue
            if line.startswith("INSERT INTO"):
                m = INSERT_RE.match(line)
                if not m or m.group(1) not in WANT:
                    continue
                tbl = m.group(1)
                cols = [c.strip().strip("`").lower() for c in m.group(2).split(",")] if m.group(2) else None
                body = line[m.end():]
                if body.rstrip().endswith(";"):
                    _flush(data, tbl, cols or columns.get(tbl), body)
                else:
                    pending, pending_table, pending_cols = [body], tbl, cols
    for t, rows in data.items():
        print(f"  - {t:<26} {len(rows):>8,} 행", flush=True)
    print(f"  (파싱 {time.time() - t0:.1f}초)")
    missing = [t for t in WANT if t not in columns and not data[t]]
    if missing:
        print("  ! 덤프에서 찾지 못한 테이블:", ", ".join(missing))
    return data

def _flush(data, tbl, cols, text):
    if not cols:
        raise SystemExit(f"[오류] {tbl} 의 컬럼 이름을 알 수 없습니다 (CREATE TABLE 이 INSERT 보다 앞에 있어야 합니다).")
    idx = {c: cols.index(c) for c in WANT[tbl] if c in cols}
    absent = [c for c in WANT[tbl] if c not in idx]
    if absent and not data[tbl]:
        print(f"  ! {tbl}: 없는 컬럼 {absent} (건너뜀)")
    for r in parse_values(text):
        if len(r) != len(cols):
            continue
        data[tbl].append({c: r[i] for c, i in idx.items()})

# ----------------------------------------------------------------------------
# 드랍 확률 계산 (MaNGOS 루트 규칙)
# ----------------------------------------------------------------------------
class LootDB:
    def __init__(self, creature_rows, reference_rows):
        self.tables = {"creature": defaultdict(list), "reference": defaultdict(list)}
        for kind, rows in (("creature", creature_rows), ("reference", reference_rows)):
            for r in rows:
                if isinstance(r.get("entry"), int) and isinstance(r.get("item"), int):
                    self.tables[kind][r["entry"]].append(r)
        self._ref_cache = {}

    def _eval_rows(self, rows, stack):
        """한 번 굴렸을 때 각 아이템이 나올 확률(%)을 돌려준다."""
        out = defaultdict(float)
        groups = defaultdict(list)
        for r in rows:
            g = r.get("groupid") or 0
            is_ref = (r.get("mincountorref") or 0) < 0
            if g == 0 or is_ref:          # MaNGOS: 참조 행은 groupid 와 상관없이 독립적으로 굴린다
                self._add_row(out, r, abs(r.get("chanceorquestchance") or 0), stack)
            else:
                groups[g].append(r)
        for g, grows in groups.items():
            explicit = sum(abs(r.get("chanceorquestchance") or 0) for r in grows)
            zero = [r for r in grows if not (r.get("chanceorquestchance") or 0)]
            share = max(0.0, 100.0 - explicit) / len(zero) if zero else 0.0
            for r in grows:
                c = abs(r.get("chanceorquestchance") or 0) or share
                self._add_row(out, r, c, stack)
        return out

    def _add_row(self, out, r, chance, stack):
        if chance <= 0:
            return
        ref = r.get("mincountorref") or 0
        if ref < 0:                                   # 참조 테이블: -mincountOrRef 가 번호
            sub = self.eval_reference(-ref, stack)
            rolls = max(1, r.get("maxcount") or 1)
            for item, p in sub.items():
                out[item] = min(100.0, out[item] + chance / 100.0 * p * rolls)
        else:
            out[r["item"]] = min(100.0, out[r["item"]] + chance)

    def eval_reference(self, entry, stack):
        if entry in self._ref_cache:
            return self._ref_cache[entry]
        if entry in stack:
            return {}
        res = self._eval_rows(self.tables["reference"].get(entry, []), stack | {entry})
        self._ref_cache[entry] = res
        return res

    def eval_creature(self, loot_id):
        return self._eval_rows(self.tables["creature"].get(loot_id, []), frozenset())

# ----------------------------------------------------------------------------
def lq(s) -> str:
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'

def fnum(x) -> str:
    if isinstance(x, float):
        return ("%.3f" % x).rstrip("0").rstrip(".") or "0"
    return str(x)

def main():
    ap = argparse.ArgumentParser(description="CMaNGOS Classic-DB 에서 LevelBiS 용 데이터 추출")
    ap.add_argument("input", help="ClassicDB_1_12_1_z2815.sql 또는 .sql.gz")
    ap.add_argument("-o", "--output", default="BestGearFinder/GearDatabase.lua")
    ap.add_argument("--min-quality", type=int, default=2, help="저장할 최소 품질 (2=고급/녹색, 기본값)")
    ap.add_argument("--world-rares", action="store_true", help="야외 희귀/보스 몬스터(Rank 2~4) 드랍도 포함")
    args = ap.parse_args()
    src, out = Path(args.input), Path(args.output)
    if not src.exists():
        ap.error(f"입력 파일이 없습니다: {src}")

    print("[1/4] SQL 읽는 중...", flush=True)
    d = load_tables(src)

    # 장비 아이템 판별 (무기 2 / 방어구 4, 착용 부위 있음, 최소 품질)
    items = {}
    for r in d["item_template"]:
        if r.get("class") in (2, 4) and (r.get("inventorytype") or 0) != 0 and (r.get("quality") or 0) >= args.min_quality:
            items[r["entry"]] = r
    print(f"      장비 아이템(품질>={args.min_quality}): {len(items):,}개")

    print("[2/4] 던전/레이드 몬스터 찾는 중...", flush=True)
    guid_map = {}
    spawn_maps = defaultdict(set)                       # creature id -> maps
    for r in d["creature"]:
        guid_map[r["guid"]] = r["map"]
        cid = r.get("id")
        if isinstance(cid, int) and cid > 0:
            spawn_maps[cid].add(r["map"])
    for r in d["creature_spawn_entry"]:                 # 여러 몬스터 중 하나가 나오는 스폰
        mp = guid_map.get(r["guid"])
        if mp is not None and isinstance(r.get("entry"), int):
            spawn_maps[r["entry"]].add(mp)

    tmpl = {r["entry"]: r for r in d["creature_template"]}
    targets = {}                                        # creature id -> [map,...]
    for cid, maps in spawn_maps.items():
        t = tmpl.get(cid)
        if not t:
            continue
        keep = [m for m in maps if m in INSTANCE_MAPS]
        outdoor = [m for m in maps if m in WORLD_MAPS]
        rank = t.get("rank") or 0
        if outdoor and args.world_rares and rank in (2, 4):
            keep += outdoor
        if keep:
            targets[cid] = sorted(set(keep))
    for cid, mp in SCRIPT_BOSSES.items():
        if cid in tmpl and cid not in targets:
            targets[cid] = [mp]
    print(f"      대상 몬스터: {len(targets):,}마리")

    print("[3/4] 드랍 테이블 풀어내는 중...", flush=True)
    loot = LootDB(d["creature_loot_template"], d["reference_loot_template"])
    best = {}                                           # (item, map) -> 정보
    cnt = defaultdict(set)                              # (item, map) -> 드랍하는 몬스터들
    no_loot = 0
    for cid, maps in targets.items():
        t = tmpl[cid]
        lootid = t.get("lootid") or cid
        drops = loot.eval_creature(lootid)
        if not drops and lootid != cid:
            drops = loot.eval_creature(cid)
        if not drops:
            no_loot += 1
            continue
        rank = t.get("rank") or 0
        for item, chance in drops.items():
            if item not in items:
                continue
            for mp in maps:
                key = (item, mp)
                cnt[key].add(cid)
                cur = best.get(key)
                cand = (chance, rank, -cid)
                if cur is None or cand > cur["_k"]:
                    best[key] = {"_k": cand, "cid": cid, "chance": chance,
                                 "name": t.get("name") or f"NPC {cid}", "lvl": t.get("minlevel") or 0}
                else:
                    cur["lvl"] = min(cur["lvl"], t.get("minlevel") or cur["lvl"]) or cur["lvl"]
    print(f"      드랍이 있는 몬스터 {len(targets) - no_loot:,}마리 / 드랍 없음 {no_loot:,}마리")

    # 던전 안의 상자(오브젝트) 드랍
    go_tmpl = {r["entry"]: r for r in d["gameobject_template"]}
    go_loot = LootDB(d["gameobject_loot_template"], [])
    go_loot._ref_cache = loot._ref_cache                 # 참조 테이블은 공유
    go_loot.tables["reference"] = loot.tables["reference"]
    chests = defaultdict(set)                            # gameobject id -> maps
    for r in d["gameobject"]:
        if r.get("map") in INSTANCE_MAPS and r.get("id") in go_tmpl:
            chests[r["id"]].add(r["map"])
    n_chest = 0
    for gid, maps in chests.items():
        g = go_tmpl[gid]
        if g.get("type") != 3 or not g.get("data1"):
            continue
        drops = go_loot.eval_creature(g["data1"])
        if not drops:
            continue
        n_chest += 1
        for item, chance in drops.items():
            if item not in items:
                continue
            for mp in maps:
                key = (item, mp)
                cnt[key].add(-gid)
                cand = (chance, -1, gid)
                cur = best.get(key)
                if cur is None or cand > cur["_k"]:
                    best[key] = {"_k": cand, "cid": -gid, "chance": chance,
                                 "name": "상자: " + (g.get("name") or f"Object {gid}"), "lvl": 0}
    print(f"      드랍이 있는 상자 종류: {n_chest:,}개")

    sources = defaultdict(list)
    for (item, mp), b in best.items():
        n = len(cnt[(item, mp)])
        boss = b["name"] + (f" 외 {n - 1}" if n > 1 else "")
        inst = "월드 보스" if mp == WORLD_BOSS else (INSTANCE_MAPS.get(mp) or WORLD_MAPS.get(mp, f"Map {mp}"))
        sources[item].append({"inst": inst, "boss": boss, "minLvl": b["lvl"], "chance": round(b["chance"], 3),
                              "creature": b["cid"], "map": mp, "n": n})
    for v in sources.values():
        v.sort(key=lambda x: (x["map"], x["creature"]))

    print("[4/4] 제작 정보 만드는 중...", flush=True)
    spells = {r["id"]: r for r in d["spell_template"]}

    def learned(spell):
        s = spells.get(spell)
        if s:
            for i in (1, 2, 3):
                if s.get(f"effect{i}") == SPELL_EFFECT_LEARN_SPELL and s.get(f"effecttriggerspell{i}"):
                    return s[f"effecttriggerspell{i}"]
        return spell

    def created(spell):
        s = spells.get(spell)
        if s:
            for i in (1, 2, 3):
                if s.get(f"effect{i}") == SPELL_EFFECT_CREATE_ITEM and s.get(f"effectitemtype{i}"):
                    return s[f"effectitemtype{i}"]
        return None

    craft = defaultdict(dict)       # item -> {(skill,): entry}
    def add_craft(item, skill, rank, spell, need_recipe, recipe=None):
        if item not in items or skill not in ALL_PROF_NAMES:
            return
        key = skill
        cur = craft[item].get(key)
        e = {"inst": ALL_PROF_NAMES[skill], "boss": "도안 필요" if need_recipe else "", "skill": rank or 0, "spell": spell}
        if cur is None or (cur["boss"] and not e["boss"]):      # 트레이너 습득이 도안보다 우선
            craft[item][key] = e

    n_tr = 0
    for r in d["npc_trainer"] + d["npc_trainer_template"]:
        sp = learned(r.get("spell"))
        it = created(sp)
        if it:
            skill = r.get("reqskill") or 0
            add_craft(it, skill, r.get("reqskillvalue"), sp, False)
            n_tr += 1
    n_rc = 0
    for r in d["item_template"]:
        if r.get("class") != 9:
            continue
        skill = r.get("requiredskill") or RECIPE_SUBCLASS_SKILL.get(r.get("subclass"), 0)
        for i in range(1, 6):
            sid = r.get(f"spellid_{i}")
            if not sid:
                continue
            sp = learned(sid)
            it = created(sp)
            if it:
                add_craft(it, skill, r.get("requiredskillrank"), sp, True, r["entry"])
                n_rc += 1
    print(f"      트레이너 제작 주문 {n_tr:,}개 / 도안 아이템 {n_rc:,}개 -> 장비 제작품 {len(craft):,}개")

    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("-- AUTO-GENERATED by tools/extract_cmnangos.py (v3)\n")
        f.write("-- Source: CMaNGOS Classic-DB 1.12.x\n")
        f.write("-- Do not hand edit; re-run the extractor when the source DB changes.\n")
        f.write("local _, ns = ...\nns.GearDB = {\n")
        f.write('    version = "CMaNGOS Classic-DB 1.12.x (extractor v3)",\n    sources = {\n')
        for item in sorted(sources):
            f.write(f"        [{item}] = {{\n")
            for s in sources[item]:
                f.write("            {inst=%s, boss=%s, minLvl=%d, chance=%s, creature=%d, map=%d, n=%d},\n" % (
                    lq(s["inst"]), lq(s["boss"]), s["minLvl"], fnum(s["chance"]), s["creature"], s["map"], s["n"]))
            f.write("        },\n")
        f.write("    },\n    crafting = {\n")
        for item in sorted(craft):
            f.write(f"        [{item}] = {{\n")
            for e in craft[item].values():
                f.write("            {inst=%s, boss=%s, skill=%d, spell=%d},\n" % (lq(e["inst"]), lq(e["boss"]), e["skill"], e["spell"]))
            f.write("        },\n")
        f.write("    },\n    maps = {\n")
        for mp, name in sorted(INSTANCE_MAPS.items()):
            f.write(f"        [{mp}] = {{name={lq(name)}}},\n")
        f.write("    },\n")
        # 1.12 DB 에 존재하는 모든 무기/방어구 ID (연속 구간 [시작,끝] 평탄 배열).
        # 애드온이 게임에서 훑은 ID 중 여기에 없는 것을 'Forever 신규 아이템'으로 취급한다.
        ids = sorted(r["entry"] for r in d["item_template"] if r["class"] in (2, 4))
        ranges = []
        for i in ids:
            if ranges and i == ranges[-1][1] + 1:
                ranges[-1][1] = i
            else:
                ranges.append([i, i])
        f.write("    known = {" + ",".join("%d,%d" % (lo, hi) for lo, hi in ranges) + "},\n")
        f.write("}\n")

    n_src = sum(len(v) for v in sources.values())
    print(f"\n완료: 드랍 아이템 {len(sources):,}개 (출처 {n_src:,}곳) / 제작 아이템 {len(craft):,}개")
    print(f"출력: {out}  ({out.stat().st_size / 1024:.0f} KB)")

if __name__ == "__main__":
    main()
