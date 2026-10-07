-- BestGearFinder : 정적 규칙 데이터 (직업별 방어구/무기 숙련, 슬롯 그룹, 스탯 가중치)
local ADDON, ns = ...
local L = ns.L

-- 아이템 classID / subClassID (언어와 무관한 숫자 ID 사용)
ns.CLASS_WEAPON, ns.CLASS_ARMOR = 2, 4
local W = { AXE1 = 0, AXE2 = 1, BOW = 2, GUN = 3, MACE1 = 4, MACE2 = 5, POLE = 6,
            SWORD1 = 7, SWORD2 = 8, STAFF = 10, FIST = 13, DAGGER = 15, THROWN = 16,
            XBOW = 18, WAND = 19 }
local A = { CLOTH = 1, LEATHER = 2, MAIL = 3, PLATE = 4, SHIELD = 6, LIBRAM = 7, IDOL = 8, TOTEM = 9 }

local function set(...) local t = {} for i = 1, select("#", ...) do t[select(i, ...)] = true end return t end

-- armorByLevel: { {최소레벨, 방어구종류}, ... } 마지막으로 만족하는 항목 사용
ns.CLASS_RULES = {
    WARRIOR = { armor = { {1, A.MAIL}, {40, A.PLATE} }, shield = true, dualWield = true,
        weapons = set(W.AXE1, W.AXE2, W.BOW, W.GUN, W.MACE1, W.MACE2, W.POLE, W.SWORD1, W.SWORD2, W.STAFF, W.FIST, W.DAGGER, W.THROWN, W.XBOW) },
    PALADIN = { armor = { {1, A.MAIL}, {40, A.PLATE} }, shield = true, relic = A.LIBRAM,
        weapons = set(W.AXE1, W.AXE2, W.MACE1, W.MACE2, W.POLE, W.SWORD1, W.SWORD2) },
    HUNTER  = { armor = { {1, A.LEATHER}, {40, A.MAIL} }, dualWield = true,
        weapons = set(W.AXE1, W.AXE2, W.BOW, W.GUN, W.POLE, W.SWORD1, W.SWORD2, W.STAFF, W.FIST, W.DAGGER, W.XBOW, W.THROWN) },
    ROGUE   = { armor = { {1, A.LEATHER} }, dualWield = true,
        weapons = set(W.DAGGER, W.FIST, W.MACE1, W.SWORD1, W.BOW, W.GUN, W.XBOW, W.THROWN) },
    PRIEST  = { armor = { {1, A.CLOTH} },
        weapons = set(W.MACE1, W.DAGGER, W.STAFF, W.WAND) },
    SHAMAN  = { armor = { {1, A.LEATHER}, {40, A.MAIL} }, shield = true, relic = A.TOTEM, dualWield = true,
        weapons = set(W.AXE1, W.AXE2, W.MACE1, W.MACE2, W.STAFF, W.FIST, W.DAGGER) },
    MAGE    = { armor = { {1, A.CLOTH} },
        weapons = set(W.SWORD1, W.DAGGER, W.STAFF, W.WAND) },
    WARLOCK = { armor = { {1, A.CLOTH} },
        weapons = set(W.SWORD1, W.DAGGER, W.STAFF, W.WAND) },
    DRUID   = { armor = { {1, A.LEATHER} }, relic = A.IDOL,
        weapons = set(W.MACE1, W.MACE2, W.STAFF, W.FIST, W.DAGGER, W.POLE) },
}

-- 이중무기 가능 레벨 (대략값)
ns.DUAL_WIELD_LEVEL = { WARRIOR = 20, ROGUE = 10, HUNTER = 20, SHAMAN = 40 }

-- 방어구 종류 제한을 적용할 장착 부위 (목걸이/반지/장신구/망토는 제한 없음)
ns.ARMOR_LOCS = set("INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_ROBE",
    "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND")

-- 슬롯 그룹: locs = 장착 부위, inv = 비교 대상 인벤토리 슬롯 ID
ns.GROUPS = {
    { key = "HEAD",     label = L["머리"], labelKo = "머리",      locs = set("INVTYPE_HEAD"), inv = {1} },
    { key = "NECK",     label = L["목걸이"], labelKo = "목걸이",    locs = set("INVTYPE_NECK"), inv = {2} },
    { key = "SHOULDER", label = L["어깨"], labelKo = "어깨",      locs = set("INVTYPE_SHOULDER"), inv = {3} },
    { key = "CLOAK",    label = L["등"], labelKo = "등",        locs = set("INVTYPE_CLOAK"), inv = {15} },
    { key = "CHEST",    label = L["가슴"], labelKo = "가슴",      locs = set("INVTYPE_CHEST", "INVTYPE_ROBE"), inv = {5} },
    { key = "WRIST",    label = L["손목"], labelKo = "손목",      locs = set("INVTYPE_WRIST"), inv = {9} },
    { key = "HAND",     label = L["손"], labelKo = "손",        locs = set("INVTYPE_HAND"), inv = {10} },
    { key = "WAIST",    label = L["허리"], labelKo = "허리",      locs = set("INVTYPE_WAIST"), inv = {6} },
    { key = "LEGS",     label = L["다리"], labelKo = "다리",      locs = set("INVTYPE_LEGS"), inv = {7} },
    { key = "FEET",     label = L["발"], labelKo = "발",        locs = set("INVTYPE_FEET"), inv = {8} },
    { key = "FINGER",   label = L["반지"], labelKo = "반지",      locs = set("INVTYPE_FINGER"), inv = {11, 12} },
    { key = "TRINKET",  label = L["장신구"], labelKo = "장신구",    locs = set("INVTYPE_TRINKET"), inv = {13, 14} },
    { key = "MAIN1H",   label = L["한손 무기"], labelKo = "한손 무기", locs = set("INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND"), inv = {16} },
    { key = "MAIN2H",   label = L["양손 무기"], labelKo = "양손 무기", locs = set("INVTYPE_2HWEAPON"), inv = {16} },
    { key = "OFF",      label = L["보조 장비"], labelKo = "보조 장비", locs = set("INVTYPE_SHIELD", "INVTYPE_HOLDABLE", "INVTYPE_WEAPONOFFHAND"), inv = {17} },
    { key = "RANGED",   label = L["원거리/성물"], labelKo = "원거리/성물", locs = set("INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC"), inv = {18} },
}
-- DW 가능 직업은 한손 무기도 보조 장비 후보가 됨 (Core에서 처리)
ns.OFF_EXTRA_LOCS = set("INVTYPE_WEAPON")

-- 아이템 장착 부위 -> 인덱싱 대상 여부
ns.EQUIP_LOCS = {}
for _, g in ipairs(ns.GROUPS) do
    for loc in pairs(g.locs) do ns.EQUIP_LOCS[loc] = true end
end

-- 스탯 가중치 (GetItemStats 토큰 기준, 모르는 토큰은 무시됨)
local function w(t) return t end
local HEAL = { ITEM_MOD_HEALING_DONE_SHORT = 1.0, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 1.0, ITEM_MOD_SPELL_POWER_SHORT = 1.0 }
local SDMG = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1.0, ITEM_MOD_SPELL_POWER_SHORT = 1.0 }
local function merge(...)
    local r = {}
    for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do r[k] = v end end
    return r
end
local STR, AGI, STA, INT, SPI = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT"
local AP, RAP, FAP = "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "ITEM_MOD_FERAL_ATTACK_POWER_SHORT"
local MP5, DPS, ARMOR = "ITEM_MOD_MANA_REGENERATION_SHORT", "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "RESISTANCE0_NAME"
local DEF, DODGE, PARRY, BLOCK = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "ITEM_MOD_DODGE_RATING_SHORT", "ITEM_MOD_PARRY_RATING_SHORT", "ITEM_MOD_BLOCK_VALUE_SHORT"

ns.SPECS = {
    WARRIOR = {
        { name = L["분노/무기 (딜)"], nameKo = "분노/무기 (딜)", w = { [STR]=1, [AGI]=0.7, [STA]=0.3, [AP]=0.5, [DPS]=4, [ARMOR]=0.01 } },
        { name = L["방어 (탱)"], nameKo = "방어 (탱)",      w = { [STA]=1, [STR]=0.5, [AGI]=0.4, [DEF]=2, [DODGE]=2, [PARRY]=2, [BLOCK]=0.5, [DPS]=1, [ARMOR]=0.06 } },
    },
    PALADIN = {
        { name = L["징벌 (딜)"], nameKo = "징벌 (딜)",  w = { [STR]=1, [AGI]=0.3, [STA]=0.3, [INT]=0.1, [AP]=0.5, [DPS]=4, [ARMOR]=0.01 } },
        { name = L["신성 (힐)"], nameKo = "신성 (힐)",  w = merge({ [INT]=1, [SPI]=0.4, [STA]=0.3, [MP5]=2 }, HEAL) },
        { name = L["보호 (탱)"], nameKo = "보호 (탱)",  w = { [STA]=1, [STR]=0.6, [DEF]=2, [DODGE]=2, [PARRY]=2, [BLOCK]=0.5, [DPS]=0.5, [ARMOR]=0.06 } },
    },
    HUNTER = {
        { name = L["사냥꾼 (딜)"], nameKo = "사냥꾼 (딜)", w = { [AGI]=1, [INT]=0.4, [STA]=0.4, [STR]=0.2, [AP]=0.5, [RAP]=0.5, [DPS]=4 } },
    },
    ROGUE = {
        { name = L["도적 (딜)"], nameKo = "도적 (딜)",  w = { [AGI]=1, [STR]=0.6, [STA]=0.3, [AP]=0.5, [DPS]=4 } },
    },
    PRIEST = {
        { name = L["신성/수양 (힐)"], nameKo = "신성/수양 (힐)", w = merge({ [INT]=1, [SPI]=0.8, [STA]=0.3, [MP5]=2 }, HEAL) },
        { name = L["암흑 (딜)"], nameKo = "암흑 (딜)",      w = merge({ [INT]=0.7, [SPI]=0.3, [STA]=0.4 }, SDMG) },
    },
    SHAMAN = {
        { name = L["정기 (딜)"], nameKo = "정기 (딜)",  w = merge({ [INT]=1, [STA]=0.4, [SPI]=0.2 }, SDMG) },
        { name = L["고양 (딜)"], nameKo = "고양 (딜)",  w = { [STR]=0.8, [AGI]=0.8, [STA]=0.3, [INT]=0.1, [AP]=0.5, [DPS]=4 } },
        { name = L["복원 (힐)"], nameKo = "복원 (힐)",  w = merge({ [INT]=1, [SPI]=0.3, [STA]=0.3, [MP5]=2 }, HEAL) },
    },
    MAGE = {
        { name = L["마법사 (딜)"], nameKo = "마법사 (딜)", w = merge({ [INT]=1, [SPI]=0.3, [STA]=0.4 }, SDMG) },
    },
    WARLOCK = {
        { name = L["흑마법사 (딜)"], nameKo = "흑마법사 (딜)", w = merge({ [STA]=0.8, [INT]=0.8, [SPI]=0.1 }, SDMG) },
    },
    DRUID = {
        { name = L["조화 (딜)"], nameKo = "조화 (딜)",    w = merge({ [INT]=1, [SPI]=0.3, [STA]=0.4 }, SDMG) },
        { name = L["야성 (딜)"], nameKo = "야성 (딜)",    w = { [STR]=1, [AGI]=0.75, [STA]=0.3, [AP]=0.5, [FAP]=0.5, [DPS]=3 } },  -- 힘 1 = 공격력 2
        { name = L["야성 (탱)"], nameKo = "야성 (탱)",    w = { [STA]=1, [AGI]=0.8, [STR]=0.4, [FAP]=0.3, [DPS]=1, [ARMOR]=0.05 } },
        { name = L["회복 (힐)"], nameKo = "회복 (힐)",    w = merge({ [INT]=1, [SPI]=0.5, [STA]=0.3, [MP5]=2 }, HEAL) },
    },
}

-- 각 직업의 스펙 칸(위 SPECS 순서) -> BiS 목록(BiSData.lua)의 스펙 이름들
ns.BIS_MAP = {
    WARRIOR = { { "arms", "fury" }, { "protection" } },
    PALADIN = { { "retribution" }, { "holy" }, { "protection" } },
    HUNTER  = { { "beast-mastery", "marksmanship" } },
    ROGUE   = { { "assassination", "combat", "subtlety" } },
    PRIEST  = { { "holy", "discipline" }, { "shadow" } },
    SHAMAN  = { { "elemental" }, { "enhancement" }, {} },
    MAGE    = { { "arcane", "fire", "frost" } },
    WARLOCK = { { "affliction", "demonology", "destruction" } },
    DRUID   = { { "balance" }, { "feral-dps" }, { "feral-tank" }, { "restoration" } },
}

-- 아이템 레벨 가중치: 스탯이 거의 없는 아이템 구분/동점 처리용 보조점수 (스탯보다 작게 유지)
ns.ILVL_WEIGHT = 0.15

-- 업그레이드 판정: 착용 중인 장비보다 이 비율 + 고정치 이상 높아야 ▲ (미세한 차이는 무시)
ns.UPGRADE_MARGIN_PCT = 0.05
ns.UPGRADE_MARGIN_ABS = 0.5

-- 언어 강제 설정(/bgf lang)이 적용된 뒤 슬롯/스펙 이름을 다시 번역한다.
function ns.RelabelData()
    for _, g in ipairs(ns.GROUPS or {}) do
        if g.labelKo then g.label = L[g.labelKo] end
    end
    for _, list in pairs(ns.SPECS or {}) do
        for _, sp in ipairs(list) do
            if sp.nameKo then sp.name = L[sp.nameKo] end
        end
    end
end
