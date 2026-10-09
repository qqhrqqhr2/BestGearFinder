-- BestGearFinder : CMaNGOS Classic-DB 정적 데이터를 사용해 현재 직업/레벨에 맞는 장비를 추천
local ADDON, ns = ...
local L = ns.L
_G.BestGearFinder = ns

local DEFAULTS = { perSlot = 2, upgradeOnly = true, range = {}, qual = { [2] = true, [3] = true, [4] = true }, allModules = false, crafting = true, quests = true, minChance = 1, auction = true, newItems = true, iconShown = true, scan = {}, mobCut = true, classFilter = true, sourcedOnly = false, collapsed = {}, spec = {}, itemTooltip = true }

ns.index = {}          -- [itemID] = { loc, classID, subID, icon, minLvl, src = { {inst, boss}, ... } } | false
ns.indexState = "idle" -- idle | running | done | empty
ns.indexStats = { bosses = 0, items = 0, modules = 0 }
ns.views = {}          -- [역할번호][슬롯키] = 추천 목록
ns.bands = {}          -- 화면에 그릴 슬롯 순서 { {group=, count=}, ... }
ns.stats = { candidates = 0, ready = 0, pending = 0 }

local db
local scoreCache = {}
local requested, queue, queueLo = {}, {}, {}
local attempts, dead = {}, {}  -- 요청 횟수 / 끝내 불러오지 못한(게임에 없는) 아이템
local qdone = {}   -- 완료한 퀘스트 캐시 (계산할 때마다 초기화)

------------------------------------------------------------------------
-- 클라이언트 API 호환 래퍼
------------------------------------------------------------------------
local GetItemInfoInstantC = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemInfoC = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemStatsC = (C_Item and C_Item.GetItemStats) or GetItemStats

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Best Gear Finder|r " .. tostring(msg)) end
ns.Print = Print

------------------------------------------------------------------------
-- 설정 / 직업 정보
------------------------------------------------------------------------
local function InitDB()
    BestGearFinderDB = BestGearFinderDB or {}
    db = BestGearFinderDB
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then
            if type(v) == "table" then db[k] = {} for kk, vv in pairs(v) do db[k][kk] = vv end else db[k] = v end
        end
    end
    if type(db.perSlot) ~= "number" or db.perSlot < 2 then db.perSlot = 2 elseif db.perSlot > 10 then db.perSlot = 10 end
    ns.db = db
    if ns.SetLang then ns.SetLang(db.lang) end
    if ns.RelabelData then ns.RelabelData() end
end

-- 보고 있는 직업: 기본은 내 캐릭터, 드롭다운으로 다른 직업을 고르면 그 직업(보기 전용)
function ns:ActiveClass()
    local _, class = UnitClass("player")
    return ns.viewClass or class
end
function ns:ActiveClassName()
    local cls = ns:ActiveClass()
    if ns.viewClass then
        local t = LOCALIZED_CLASS_NAMES_MALE
        return (t and t[cls]) or cls
    end
    return (UnitClass("player"))
end
function ns:CharKey() return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?") end

function ns:GetSpecList()
    local class = ns:ActiveClass()
    return ns.SPECS[class] or ns.SPECS.WARRIOR
end


-- 요구 레벨 범위: 사용자가 입력하면 캐릭터별로 저장, 없으면 (현재레벨-10 ~ 현재레벨)
function ns:GetRange()
    local level = UnitLevel("player")
    local r = db.range[self:CharKey()]
    if r and r.min and r.max then return r.min, r.max, false end
    return math.max(1, level - 10), level, true
end

function ns:SetRange(lo, hi)
    local curLo, curHi = self:GetRange()
    lo, hi = tonumber(lo) or curLo, tonumber(hi) or curHi
    lo = math.max(1, math.min(99, math.floor(lo)))
    hi = math.max(1, math.min(99, math.floor(hi)))
    if lo > hi then lo, hi = hi, lo end
    db.range[self:CharKey()] = { min = lo, max = hi }
    return lo, hi
end

function ns:ClearRange()
    db.range[self:CharKey()] = nil
end

local function GetArmorType(rules, level)
    local t = rules.armor[1][2]
    for _, a in ipairs(rules.armor) do
        if level >= a[1] then t = a[2] end
    end
    return t
end

------------------------------------------------------------------------
-- 1단계: CMaNGOS 정적 데이터 인덱싱 (프레임을 멈추지 않도록 코루틴으로 분할 처리)
local budgetStart = 0
local function MaybeYield()
    if debugprofilestop() - budgetStart > 6 then coroutine.yield() end
end

local function AddSource(rec, inst, boss, minLvl, kind, skill, extra)
    rec.kinds[kind] = true
    extra = extra or {}
    for _, s in ipairs(rec.src) do
        if s.kind == kind then
            if kind == "quest" then
                if s.qid == extra.qid then return end
            elseif s.inst == inst and s.boss == boss and s.creature == extra.creature and s.map == extra.map then
                return
            end
        end
    end
    local src = { inst = inst, boss = boss, kind = kind, skill = skill }
    for k, v in pairs(extra) do src[k] = v end
    rec.src[#rec.src + 1] = src
    if kind == "drop" and minLvl and minLvl > 0 and (not rec.minLvl or minLvl < rec.minLvl) then rec.minLvl = minLvl end
end

-- 퀘스트 보상 인덱싱 (QuestData.lua: CMaNGOS classic-db 기반)
local CLASS_BIT = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }
local function HasBit(mask, bitv)
    return (mask == 0) or not bitv or (math.floor(mask / bitv) % 2 == 1)
end
local function IndexQuests()
    local Q = ns.QUESTS
    local st = ns.indexStats
    st.quest = 0
    if not Q then return end
    local idx = ns.index
    local class = ns:ActiveClass()
    local cbit = CLASS_BIT[class]
    local raceID = select(3, UnitRace("player"))
    local rbit = raceID and 2 ^ (raceID - 1) or nil
    for qid, q in pairs(Q) do
        if HasBit(q[4], cbit) and HasBit(q[5], rbit) then
            for pass = 1, 2 do
                local list = (pass == 1) and q[6] or q[7]
                for _, id in ipairs(list) do
                    local rec = idx[id]
                    if rec == nil then
                        local _, _, _, loc, icon, cID, sID = GetItemInfoInstantC(id)
                        if loc and ns.EQUIP_LOCS[loc] then
                            rec = { loc = loc, classID = cID, subID = sID, icon = icon, src = {}, kinds = {} }
                            idx[id] = rec
                            st.items = st.items + 1
                        else
                            idx[id] = false
                        end
                    end
                    if rec then
                        if not rec.kinds.quest then st.quest = st.quest + 1 end
                        AddSource(rec, q[1], "", nil, "quest", nil, { qid = qid, ql = q[2], ml = q[3], choice = (pass == 1) })
                    end
                end
            end
            MaybeYield()
        end
    end
end

local function MakeRecord(id)
    local _, _, _, loc, icon, cID, sID = GetItemInfoInstantC(id)
    if loc and ns.EQUIP_LOCS[loc] then
        return { loc = loc, classID = cID, subID = sID, icon = icon, src = {}, kinds = {} }
    end
    return false
end

-- Forever 신규 아이템: 1.12 DB(known)에 없는 무기/방어구를 게임 클라이언트에서 직접 찾는다.
-- 서버에 묻지 않는 GetItemInfoInstant 로 ID 를 훑고, 결과는 게임 빌드별로 저장해 둔다.
local SCAN_MAX = 400000
local function ScanNewItems()
    local D = ns.GearDB
    local kn = D and D.known
    if type(kn) ~= "table" or #kn == 0 then return end   -- 구버전 데이터 파일이면 건너뜀
    local st = ns.indexStats
    local known = {}
    for i = 1, #kn, 2 do
        for id = kn[i], kn[i + 1] do known[id] = true end
    end
    MaybeYield()
    local build = select(4, GetBuildInfo()) or 0
    local cache = db.scan
    local ids
    if type(cache) == "table" and cache.build == build and cache.max == SCAN_MAX and cache.ver == D.version and type(cache.ids) == "table" then
        ids = cache.ids
    else
        ids = {}
        for id = 1, SCAN_MAX do
            if not known[id] then
                local _, _, _, loc = GetItemInfoInstantC(id)
                if loc and ns.EQUIP_LOCS[loc] then ids[#ids + 1] = id end
            end
            if id % 1000 == 0 then
                st.scanned = id
                MaybeYield()
            end
        end
        db.scan = { build = build, max = SCAN_MAX, ver = D.version, ids = ids }
    end
    st.scanned = nil
    st.new = 0
    for _, id in ipairs(ids) do
        if ns.index[id] == nil then
            local rec = MakeRecord(id)
            if rec then
                rec.new = true
                AddSource(rec, L["Forever 신규"], L["획득처 불명"], nil, "unknown")
                ns.index[id] = rec
                st.items = st.items + 1
                st.new = st.new + 1
            end
        end
    end
end

-- Forever 전용 획득처 (ForeverExtra.lua): CMaNGOS 1.12 DB에 없는 아이템의 출처
local function IndexForeverExtra()
    local st = ns.indexStats
    st.extra = 0
    local idx = ns.index
    local function Rec(id)
        local rec = idx[id]
        if rec == nil then
            rec = MakeRecord(id)
            idx[id] = rec
            if rec then st.items = st.items + 1 end
        end
        return rec or nil
    end
    local function Each(tbl, fn)
        if type(tbl) ~= "table" then return end
        for id, list in pairs(tbl) do
            local rec = Rec(id)
            if rec then
                st.extra = st.extra + 1
                for _, e in ipairs(list) do fn(rec, e) end
            end
            MaybeYield()
        end
    end
    -- 같은 보스가 이미 출처로 등록되어 있으면(이름만 다른 경우 포함) 중복 추가하지 않는다
    local function HasBoss(rec, boss)
        local b = tostring(boss or ""):lower()
        for _, s in ipairs(rec.src) do
            if s.kind == "drop" and tostring(s.boss or ""):lower() == b then return true end
        end
        return false
    end
    -- 같은 전문기술 출처가 이미 있으면 다시 넣지 않는다 (제작 데이터가 여러 곳에 겹쳐 있음)
    local function HasCraft(rec, skill)
        for _, s in ipairs(rec.src) do
            if s.kind == "craft" and s.inst == skill then return true end
        end
        return false
    end
    for _, X in ipairs({ ns.CraftData, ns.ForeverExtra, ns.DungeonData, ns.WorldData }) do
        -- 지역/희귀 몹 데이터는 같은 종류의 출처가 이미 있으면 보태지 않는다 (상인·퀘스트 이름이 달라 중복으로 보이는 것 방지)
        local onlyNew = (X == ns.WorldData)
        if type(X) == "table" then
            Each(X.drops, function(rec, e) if not HasBoss(rec, e.boss) then AddSource(rec, e.inst, e.boss, nil, "drop", nil, { creature = e.npc }) end end)
            Each(X.quests, function(rec, e)
                if not (onlyNew and rec.kinds.quest) then
                    AddSource(rec, e.title, "", nil, "quest", nil, { qid = e.qid, ql = e.lvl, ml = 0, choice = false })
                end
            end)
            Each(X.vendors, function(rec, e)
                if not (onlyNew and rec.kinds.vendor) then
                    AddSource(rec, e.zone, e.boss, nil, "vendor", nil, { creature = e.npc })
                end
            end)
            Each(X.craft, function(rec, e)
                if not HasCraft(rec, e.skill) then
                    AddSource(rec, e.skill, e.recipe and "도안 필요" or "", nil, "craft", e.lvl, e.spell and { spell = e.spell } or {})
                end
            end)
        end
    end
end

local function IndexBody()
    local idx = ns.index
    local st = ns.indexStats
    st.bosses, st.items, st.modules, st.craft = 0, 0, 1, 0

    local D = ns.GearDB
    if D and type(D.sources) == "table" then
        for itemID, sources in pairs(D.sources) do
            if type(itemID) == "number" and type(sources) == "table" then
                local rec = idx[itemID]
                if rec == nil then
                    rec = MakeRecord(itemID)
                    idx[itemID] = rec
                    if rec then st.items = st.items + 1 end
                end
                if rec then
                    for _, src in ipairs(sources) do
                        st.bosses = st.bosses + 1
                        AddSource(rec, src.inst or "?", src.boss or "?", src.minLvl, "drop", nil, {
                            creature = src.creature, map = src.map, chance = src.chance
                        })
                    end
                end
                MaybeYield()
            end
        end
    end

    -- 제작은 CMaNGOS 제작 데이터가 있을 때만 사용합니다. CMaNGOS 추출기가 제작 데이터를 만들면 사용합니다.
    local C = D and D.crafting
    if db.crafting and type(C) == "table" then
        for itemID, sources in pairs(C) do
            local rec = idx[itemID]
            if rec == nil then
                rec = MakeRecord(itemID)
                idx[itemID] = rec
                if rec then st.items = st.items + 1 end
            end
            if rec then
                for _, src in ipairs(sources) do
                    st.craft = st.craft + 1
                    AddSource(rec, src.inst or L["제작"], src.boss or "", nil, "craft", src.skill, { spell = src.spell })
                end
            end
            MaybeYield()
        end
    end

    IndexQuests()
    IndexForeverExtra()
    ScanNewItems()
end

local indexCo
function ns:EnsureIndex()
    if self.indexState == "running" or self.indexState == "done" or self.indexState == "empty" then return end
    wipe(self.index)
    scoreCache = {}
    self.indexState = "running"
    indexCo = coroutine.create(IndexBody)
end

function ns:ResetIndex()
    self.indexState = "idle"
    indexCo = nil
end

------------------------------------------------------------------------
-- 2단계: 직업/레벨 필터 + 점수 계산
------------------------------------------------------------------------
local locToGroups = {}
for _, g in ipairs(ns.GROUPS) do
    for loc in pairs(g.locs) do
        locToGroups[loc] = locToGroups[loc] or {}
        table.insert(locToGroups[loc], g)
    end
end

-- 착용 효과(주문력/치유량/공격력 등)는 GetItemStats 에 안 나올 수 있어서,
-- 툴팁 줄에서 게임의 현지화 문자열로 만든 패턴으로 직접 읽는다.
local EFFECT_TOKENS = {
    "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_HEALING_DONE_SHORT", "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
    "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT",
    "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "ITEM_MOD_DODGE_RATING_SHORT", "ITEM_MOD_PARRY_RATING_SHORT",
    "ITEM_MOD_BLOCK_VALUE_SHORT",
}
local effectPatterns
local function Esc(str) return (str:gsub("([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1")) end
local function BuildEffectPatterns()
    effectPatterns = {}
    for _, tok in ipairs(EFFECT_TOKENS) do
        local pats = {}
        local base = tok:gsub("_SHORT$", "")
        local long, short = _G[base], _G[tok]
        if type(long) == "string" and long:find("%%d") then
            pats[#pats + 1] = Esc(long):gsub("%%%%d", "(%%d+)")
        end
        if type(short) == "string" and short ~= "" then
            local e = Esc(short)
            pats[#pats + 1] = "^%+?(%d+)%s*" .. e
            pats[#pats + 1] = e .. "%s*%+(%d+)"
        end
        if #pats > 0 then effectPatterns[tok] = pats end
    end
end
local function TooltipStats(id)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" or #data.lines == 0 then return nil end
    if not effectPatterns then BuildEffectPatterns() end
    local out = {}
    for _, ln in ipairs(data.lines) do
        local t = ln.leftText
        if type(t) == "string" and t ~= "" then
            t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            for tok, pats in pairs(effectPatterns) do
                for _, p in ipairs(pats) do
                    local v = tonumber(t:match(p))
                    if v then
                        if (out[tok] or 0) < v then out[tok] = v end
                        break
                    end
                end
            end
        end
    end
    return out
end
ns.TooltipStats = TooltipStats

local statsCache = {}
local function GetStats(link)
    local st = statsCache[link]
    if st == nil then
        local base = GetItemStatsC and GetItemStatsC(link) or false
        local id = tonumber(link:match("item:(%d+)"))
        local tip = id and TooltipStats(id)
        if tip then
            local merged = {}
            if base then for k, v in pairs(base) do merged[k] = v end end
            for k, v in pairs(tip) do
                if (merged[k] or 0) < v then merged[k] = v end   -- 같은 능력치는 큰 값 하나만 (중복 합산 방지)
            end
            st = merged
            statsCache[link] = st
        else
            st = base
            if base then statsCache[link] = base end   -- 툴팁을 못 읽었으면 다음에 다시 시도
        end
    end
    return st
end
ns.GetStats = GetStats

local function ScoreItem(link, ilvl, weights)
    local sc = (ilvl or 0) * ns.ILVL_WEIGHT
    local stats = GetStats(link)
    if stats then
        for k, v in pairs(stats) do
            local m = weights[k]
            if m then sc = sc + v * m end
        end
    end
    return sc
end

local scanTip, classPrefix
local allowCache = {}
-- 직업 제한 아이템("직업: 전사, 성기사") 판별. 모르면 nil 반환.
local function IsClassAllowed(id)
    local c = allowCache[id]
    if c ~= nil then return c end
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "BestGearFinderScanTip", UIParent, "GameTooltipTemplate")
        classPrefix = ((ITEM_CLASSES_ALLOWED or "Classes: %s"):gsub("%%s", ""))
    end
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    local ok = pcall(scanTip.SetHyperlink, scanTip, "item:" .. id)
    local n = scanTip:NumLines()
    if not ok or n == 0 then return nil end
    local localized = ns:ActiveClassName()
    local result = true
    for i = 2, n do
        local fs = _G["BestGearFinderScanTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t then
            local _, e = t:find(classPrefix, 1, true)
            if e then
                result = t:sub(e + 1):find(localized, 1, true) ~= nil
                break
            end
        end
    end
    allowCache[id] = result
    return result
end

-- 테스트/폐기 아이템 이름 (신규 아이템 스캔에서만 사용)
local function IsJunkName(name)
    if not name then return false end
    return name:find("^[Tt][Ee][Ss][Tt]") or name:find("^TEST") or name:lower():find("deprecated", 1, true)
        or name:find("^zz") or name:find("^ZZ") or name:find("^OLD") or name:find("^%[") or name:find("%[PH%]")
        or name:find("^Monster") or name:find("^PH ") or false
end

-- 사용 효과로 '능력을 배우는' 성물(룬 아이템)은 장비가 아니므로 신규 아이템에서 제외
local GetItemSpellC = (C_Item and C_Item.GetItemSpell) or GetItemSpell
-- 툴팁에 '사용 효과' 줄이 있는지 (착용 효과와 구분). 알 수 없으면 nil
local function HasUseLine(id)
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local prefix = ITEM_SPELL_TRIGGER_ONUSE or "Use:"
    for _, ln in ipairs(data.lines) do
        local t = ln.leftText
        if type(t) == "string" and t:sub(1, #prefix) == prefix then return true end
    end
    return false
end
local function IsAbilityRelic(id, rec)
    if not (rec.new and rec.loc == "INVTYPE_RELIC") then return false end
    local u = HasUseLine(id)
    if u ~= nil then return u end
    if not GetItemSpellC then return false end
    local ok, spell = pcall(GetItemSpellC, id)
    return ok and spell ~= nil
end

local function Usable(rec, rules, armorType, dwOK)
    local loc, cID, sID = rec.loc, rec.classID, rec.subID
    if cID == ns.CLASS_WEAPON then
        if not rules.weapons[sID] then return false end
        if loc == "INVTYPE_WEAPONOFFHAND" and not dwOK then return false end
        return true
    elseif cID == ns.CLASS_ARMOR then
        if ns.ARMOR_LOCS[loc] then return sID == armorType end
        if loc == "INVTYPE_SHIELD" then return rules.shield and sID == 6 end
        if loc == "INVTYPE_RELIC" then return rules.relic == sID end
        if loc == "INVTYPE_RANGED" or loc == "INVTYPE_RANGEDRIGHT" or loc == "INVTYPE_THROWN" then return false end
    elseif cID ~= nil then
        return false   -- 무기/방어구가 아닌 분류(장난감 등)는 장비가 아님
    end
    return true
end

local function EquippedScore(group, weights)
    local base, baseLink
    if ns.viewClass then return 0, nil end
    for _, slot in ipairs(group.inv) do
        local link = GetInventoryItemLink("player", slot)
        local s = 0
        if link then
            local _, _, _, ilvl = GetItemInfoC(link)
            s = ScoreItem(link, ilvl, weights)
        end
        if not base or s < base then base, baseLink = s, link end
    end
    return base or 0, baseLink
end

-- 현재 장비(교체될 것)와 비교해 점수에 가장 크게 기여하는 능력치 차이 문자열
function ns.StatDiffText(link, baseLink, weights, maxN)
    local a = GetStats(link) or {}
    local b = (baseLink and GetStats(baseLink)) or {}
    local list = {}
    local seen = {}
    for k in pairs(a) do seen[k] = true end
    for k in pairs(b) do seen[k] = true end
    for k in pairs(seen) do
        local m = weights[k]
        if m and m > 0 then
            local d = (a[k] or 0) - (b[k] or 0)
            if math.abs(d) >= 0.5 then list[#list + 1] = { k = k, d = d, w = math.abs(d) * m } end
        end
    end
    table.sort(list, function(x, y) return x.w > y.w end)
    local out = {}
    for i = 1, math.min(maxN or 4, #list) do
        local e = list[i]
        local label = type(_G[e.k]) == "string" and _G[e.k] or e.k:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", "")
        out[#out + 1] = format("%s %+d", label, math.floor(e.d + (e.d >= 0 and 0.5 or -0.5)))
    end
    return table.concat(out, ", ")
end

local function EquippedIlvl(group)
    local best
    if ns.viewClass then return nil end
    for _, slot in ipairs(group.inv) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local _, _, _, ilvl = GetItemInfoC(link)
            if ilvl and (not best or ilvl < best) then best = ilvl end
        end
    end
    return best
end

local IsCached = C_Item and C_Item.IsItemDataCachedByID
local Request
function Request(id, prio)
    if dead[id] then return end
    local t = requested[id]
    if not t or GetTime() - t > 10 then
        local n = attempts[id] or 0
        if n >= 3 then dead[id] = true; return end   -- 3번 물어도 답이 없으면 포기
        attempts[id] = n + 1
        requested[id] = GetTime()
        local q = prio and queue or queueLo
        q[#q + 1] = id
    end
end

function ns:RequestItem(id) Request(id, true) end
function ns:IsItemDead(id) return dead[id] and true or false end
ns.GetItemInfoC = GetItemInfoC

-- 요구 레벨이 없는(0) 아이템은 아이템 레벨이 범위 상한 -2 ~ +10 인 것만 포함한다(너무 낮은 퀘스트템/높은 선행 아이템 제외)
-- (게임에 미리 들어 있는 높은 레벨 아이템이 요구 레벨 0으로 보이는 경우가 있음). BiS 목록의 아이템은 예외.
local function InRange(req, minReq, maxReq, ilvl, isBis)
    if req and req > 0 then return req >= minReq and req <= maxReq end
    if isBis then return true end
    local lv = ilvl or 0
    return lv <= maxReq + 10 and lv >= maxReq - 2   -- 요구 레벨 없는 아이템: 현재 상한 근처의 아이템 레벨만
end

-- BiS 목록 조회: 스펙 칸 si 에서 아이템 id 의 등급 (2 = 1순위, 1 = 대안, 0 = 목록에 없음)
local bisCache = {}
-- 현재 보고 있는 직업이 착용할 수 있는 아이템인지 (검색창용)
function ns:UsableByActive(rec)
    local rules = ns.CLASS_RULES[ns:ActiveClass()]
    if not rules then return true end
    local level = UnitLevel("player")
    local class = ns:ActiveClass()
    local dwOK = rules.dualWield and level >= (ns.DUAL_WIELD_LEVEL[class] or 99) or false
    return Usable(rec, rules, GetArmorType(rules, level), dwOK)
end

function ns:SetViewClass(cls)
    local _, mine = UnitClass("player")
    if cls == mine then cls = nil end
    ns.viewClass = cls
    wipe(allowCache)
    wipe(bisCache)
    scoreCache = {}
    self:ResetIndex()
end

local function BisLookup(si)
    local c = bisCache[si]
    if c then return c end
    c = { top = {}, alt = {} }
    local class = ns:ActiveClass()
    local data = ns.BiS and ns.BiS[class]
    local names = ns.BIS_MAP and ns.BIS_MAP[class] and ns.BIS_MAP[class][si]
    if data and names then
        local side = (UnitFactionGroup and UnitFactionGroup("player") == "Horde") and "H" or "A"
        for _, nm in ipairs(names) do
            local t = data[nm] and (data[nm][side] or data[nm].A or data[nm].H)
            if t then
                for _, id in ipairs(t.top) do c.top[id] = true end
                for _, id in ipairs(t.alt) do c.alt[id] = true end
            end
        end
    end
    bisCache[si] = c
    return c
end
function ns:IsAnyBis(id)
    for si = 1, #self:GetSpecList() do
        local c = BisLookup(si)
        if c.top[id] or c.alt[id] then return true end
    end
    return false
end
function ns:BisRank(si, id)
    local c = BisLookup(si)
    return c.top[id] and 2 or (c.alt[id] and 1 or 0)
end

function ns:Compute()
    local class = ns:ActiveClass()
    local other = ns.viewClass ~= nil   -- 다른 직업 보기: 내 장비와 비교하지 않음
    local rules = ns.CLASS_RULES[class]
    if not rules then return end
    local level = UnitLevel("player")
    local minReq, maxReq = self:GetRange()
    wipe(qdone)
    local armorType = GetArmorType(rules, level)
    local dwOK = rules.dualWield and level >= (ns.DUAL_WIELD_LEVEL[class] or 99) or false
    local specs = self:GetSpecList()

    -- 1) 후보 수집 (역할과 무관한 공통 단계)
    local buckets = {}
    for _, g in ipairs(ns.GROUPS) do buckets[g.key] = {} end
    local cand, ready, pending, skipped = 0, 0, 0, 0
    local errCount, firstErr = 0, nil
    local function handle(id, rec)
        if rec and ns:SourceAllowed(rec) and Usable(rec, rules, armorType, dwOK)
           and not (db.mobCut and rec.minLvl and not ((rec.kinds.craft and db.crafting) or (rec.kinds.quest and db.quests)) and rec.minLvl > maxReq + 8) then
            cand = cand + 1
            local name, link, quality, ilvl, reqLevel
            if IsCached and not IsCached(id) then
                Request(id, not rec.minLvl or (rec.minLvl <= maxReq + 8 and rec.minLvl >= minReq - 8))
            else
                name, link, quality, ilvl, reqLevel = GetItemInfoC(id)
            end
            if not name then
                if not IsCached then Request(id, true) end
                if dead[id] then skipped = skipped + 1 else pending = pending + 1 end
            else
                ready = ready + 1
                if quality and db.qual[quality] and not (rec.new and IsJunkName(name)) and not IsAbilityRelic(id, rec) and InRange(reqLevel, minReq, maxReq, ilvl, ns:IsAnyBis(id)) then
                    local entry = { id = id, name = name, link = link, ilvl = ilvl or 0, req = reqLevel or 0, rec = rec, quality = quality }
                    for _, g in ipairs(locToGroups[rec.loc]) do
                        table.insert(buckets[g.key], entry)
                    end
                    if rec.loc == "INVTYPE_WEAPON" and dwOK then
                        table.insert(buckets.OFF, entry)
                    end
                end
            end
        end
    end
    for id, rec in pairs(self.index) do
        local ok, err = pcall(handle, id, rec)
        if not ok then
            errCount = errCount + 1
            firstErr = firstErr or (tostring(id) .. ": " .. tostring(err))
        end
    end
    self.itemErrors, self.firstItemError = errCount, firstErr

    -- 현재 주무기가 양손이면 보조 장비 추천 생략
    local twoHanded = false
    local mh = (not other) and GetInventoryItemLink("player", 16) or nil
    if mh then
        local _, _, _, loc = GetItemInfoInstantC(mh)
        twoHanded = (loc == "INVTYPE_2HWEAPON" or loc == "INVTYPE_RANGED")
    end

    -- 2) 역할별 점수 계산 및 슬롯별 선정
    local perSlot = db.perSlot
    self.funnel = {}
    local views = {}
    self.slotError = nil
    for si, spec in ipairs(specs) do
        local weights = spec.w
        scoreCache[si] = scoreCache[si] or {}
        local sc = scoreCache[si]
        local picks = {}
        for _, g in ipairs(ns.GROUPS) do
            local okSlot, errSlot = pcall(function()
                local list = {}
                -- 사용자가 고른 정렬 능력치 (없으면 추천 점수 순)
                local sortTokens   -- 고른 능력치 묶음들 (묶음 안에서는 큰 값 하나만: 주문력/피해량처럼 같은 효과가 두 토큰에 겹쳐 있음)
                if db.sortStats and next(db.sortStats) then
                    sortTokens = {}
                    for _, st in ipairs(ns.SORT_STATS or {}) do
                        if db.sortStats[st.key] then sortTokens[#sortTokens + 1] = st.tokens end
                    end
                end
                for _, e in ipairs(buckets[g.key]) do
                    local score = sc[e.id]
                    if not score then
                        score = ScoreItem(e.link, e.ilvl, weights)
                        sc[e.id] = score
                    end
                    local sv
                    if sortTokens then
                        sv = 0
                        local stt = GetStats(e.link)
                        if stt then
                            for _, grp in ipairs(sortTokens) do
                                local m = 0
                                for _, tk in ipairs(grp) do if (stt[tk] or 0) > m then m = stt[tk] end end
                                sv = sv + m
                            end
                        end
                    end
                    list[#list + 1] = { e = e, score = score, bis = ns:BisRank(si, e.id), sv = sv }
                end
                table.sort(list, function(a, b)
                    if sortTokens and a.sv ~= b.sv then return a.sv > b.sv end
                    if a.bis ~= b.bis then return a.bis > b.bis end
                    if a.score ~= b.score then return a.score > b.score end
                    return a.e.id < b.e.id
                end)
                local base, baseLink = EquippedScore(g, weights)
                if si == 1 then self.funnel = self.funnel or {}; self.funnel[g.key] = { cand = #list, base = base, top = list[1] and list[1].score or 0, topId = list[1] and list[1].e.id } end
                local baseIlvl = EquippedIlvl(g)
                local picked = {}
                -- 이미 착용 중인 아이템 (BiS 인데 이미 끼고 있으면 업그레이드가 아님)
                local worn = {}
                for _, invSlot in ipairs(g.inv) do
                    local wid = (not other) and GetInventoryItemID and GetInventoryItemID("player", invSlot)
                    if wid then worn[wid] = true end
                end
                local q = ns.searchText
                if q == "" then q = nil end
                local function Match(e)
                    if string.find(string.lower(e.name or ""), q, 1, true) then return true end
                    for _, s in ipairs(e.rec.src) do
                        if string.find(string.lower((s.boss or "") .. " " .. (s.inst or "")), q, 1, true) then return true end
                    end
                    return false
                end
                for _, w in ipairs(list) do
                    local isUpgrade = w.score > base * (1 + ns.UPGRADE_MARGIN_PCT) + ns.UPGRADE_MARGIN_ABS
                    -- BiS 1순위는 점수와 무관하게 아직 착용하지 않았다면 항상 표시
                    if w.bis == 2 and not worn[w.e.id] then isUpgrade = true end
                    if q and not Match(w.e) then
                        -- 검색어와 맞지 않는 아이템은 제외
                    elseif (q or not db.upgradeOnly or isUpgrade) and (q or not (w.bis == 2 and worn[w.e.id])) then
                        local e = w.e
                        if not db.classFilter or IsClassAllowed(e.id) ~= false then
                            picked[#picked + 1] = { id = e.id, link = e.link, ilvl = e.ilvl, req = e.req, rec = e.rec,
                                quality = e.quality, score = w.score, upgrade = isUpgrade, baseIlvl = baseIlvl, baseScore = base,
                                bis = w.bis, baseLink = baseLink, weights = weights, sortVal = w.sv }
                            if #picked >= (q and 30 or perSlot) then break end
                        end
                    end
                end
                if #picked > 1 and not sortTokens then
                    -- 출처가 확인된 아이템을 위로, 출처 불명(신규)은 아래로 (각 그룹 안에서는 점수순 유지)
                    local known, unknown = {}, {}
                    for _, pk in ipairs(picked) do
                        local ps = ns:PrimarySource(pk.rec)
                        if pk.bis == 2 then
                            known[#known + 1] = pk
                        elseif ps and ps.kind == "unknown" then
                            unknown[#unknown + 1] = pk
                        else
                            known[#known + 1] = pk
                        end
                    end
                    for _, pk in ipairs(unknown) do known[#known + 1] = pk end
                    picked = known
                end
                if #picked > 0 then picks[g.key] = picked end
            end)
            if not okSlot then self.slotError = g.key .. ": " .. tostring(errSlot) end
        end
        views[si] = picks
    end

    -- 3) 슬롯별 가로 띠(band): 역할 칸들이 같은 슬롯끼리 같은 높이에 놓이도록 최대 개수 계산
    local bands = {}
    for _, g in ipairs(ns.GROUPS) do
        local m = 0
        for si = 1, #specs do
            local pk = views[si][g.key]
            if pk and #pk > m then m = #pk end
        end
        if m > 0 then bands[#bands + 1] = { group = g, count = m } end
    end

    self.views, self.bands = views, bands
    self.stats.candidates, self.stats.ready, self.stats.pending = cand, ready, pending
    self.stats.skipped = skipped
    return pending
end

local IsQuestDoneFn = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
local function QuestDone(qid)
    local v = qdone[qid]
    if v == nil then
        v = false
        if IsQuestDoneFn then
            local ok, r = pcall(IsQuestDoneFn, qid)
            v = ok and r and true or false
        end
        qdone[qid] = v
    end
    return v
end

local function SrcAllowed(src)
    local k = src.kind
    if k == "craft" then return db.crafting and true or false end
    if db.sourcedOnly and (k == "unknown" or (src.chance and src.chance < (db.minChance or 0))) then return false end
    if k == "unknown" then return db.newItems and true or false end
    if k == "quest" then return db.quests and true or false end   -- 완료/보유 여부와 무관하게 표시
    -- 드랍: 보스(확정 드랍 등)는 항상, 일반 몹의 극저확률 드랍은 최소 드랍률 미만이면 제외
    -- 드랍률이 아주 낮은 출처는 월드 잡몹의 저확률 드랍: '월드 드랍' 옵션이 켜져 있을 때만 포함
    if src.chance and src.chance < (db.minChance or 0) then return db.auction and true or false end
    return true
end
ns.SrcAllowed = SrcAllowed
ns.searchText = ""

function ns:SourceAllowed(rec)
    for _, s in ipairs(rec.src) do
        if SrcAllowed(s) then return true end
    end
    return false
end

-- 퀘스트 제목: 클라이언트 언어 제목을 얻을 수 있으면 사용, 아니면 DB의 영문 제목
local titleRequested = {}
function ns:QuestTitle(s)
    local t
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, r = pcall(C_QuestLog.GetTitleForQuestID, s.qid)
        if ok and type(r) == "string" and r ~= "" then t = r end
    end
    if not t then
        if not titleRequested[s.qid] and C_QuestLog and C_QuestLog.RequestLoadQuestByID then
            titleRequested[s.qid] = true
            pcall(C_QuestLog.RequestLoadQuestByID, s.qid)
        end
        t = s.inst
    end
    return t
end

local KIND_PRIORITY = { drop = 1, quest = 2, craft = 3, vendor = 4 }

-- 화면에 표시할 대표 출처: 드랍 > 퀘스트 > 제작 순, 꺼진 출처는 제외
function ns:PrimarySource(rec)
    local best, bestP
    for _, s in ipairs(rec.src) do
        if SrcAllowed(s) then
            local p = KIND_PRIORITY[s.kind] or 4
            if not bestP or p < bestP then best, bestP = s, p end
        end
    end
    return best
end

-- 데이터의 던전/전문기술 이름(한국어 원문)을 현지화, '보스 외 N' 표기 처리
local function LocInst(name)
    if not name then return "?" end
    return L[name]
end
local function LocBoss(boss)
    if not boss then return "?" end
    local base, n = boss:match("^(.-) 외 (%d+)$")
    if base then boss = base .. string.format(L[" 외 %d"], tonumber(n)) end
    local chest = boss:match("^상자: (.+)$")
    if chest then boss = L["상자: "] .. chest end
    return boss
end
ns.LocInst, ns.LocBoss = LocInst, LocBoss

function ns:ShortSource(rec)
    local s = self:PrimarySource(rec)
    if not s then return "?" end
    if s.kind == "unknown" then return L["출처 불명 (신규)"] end
    if s.kind == "craft" then return L["제작:"] .. LocInst(s.inst) end
    if s.kind == "quest" then return L["퀘스트:"] .. self:QuestTitle(s) end
    if s.kind == "vendor" then return L["상인:"] .. (s.boss or "?") end
    if s.chance and s.chance < (db.minChance or 0) then return L["월드 드랍"] end
    return LocInst(s.inst)
end

function ns:FormatSource(s)
    if s.kind == "unknown" then return L["획득처 불명 (Forever 신규 아이템)"] end
    if s.kind == "craft" then
        local t = L["제작: "] .. LocInst(s.inst)
        if s.boss == "도안 필요" then t = t .. L[" [도안 필요]"] end
        if s.skill and s.skill > 0 then t = t .. L[" (숙련 "] .. s.skill .. ")" end
        return t
    elseif s.kind == "quest" then
        local t = L["퀘스트: "] .. self:QuestTitle(s) .. " (Lv." .. (s.ql or "?")
        if s.ml and s.ml > 0 then t = t .. L[", 수락 Lv."] .. s.ml end
        return t .. ") · " .. (s.choice and L["선택 보상"] or L["확정 보상"])
    end
    if s.kind == "vendor" then
        return L["상인: "] .. (s.boss or "?") .. " (" .. LocInst(s.inst) .. ")"
    end
    if s.chance and s.chance < (db.minChance or 0) then
        return string.format(L["월드 드랍 - 잡몹 (%.3f%%)"], s.chance)
    end
    local t = LocInst(s.inst) .. " - " .. LocBoss(s.boss)
    if s.chance then t = t .. string.format(" (%.1f%%)", s.chance) end
    return t
end

function ns:SourceText(rec)
    local s = self:PrimarySource(rec)
    if not s then return L["출처 불명"] end
    local n = 0
    for _, o in ipairs(rec.src) do if SrcAllowed(o) then n = n + 1 end end
    local txt = self:FormatSource(s)
    if n > 1 then txt = txt .. string.format(L[" 외 %d곳"], n - 1) end
    return txt
end

------------------------------------------------------------------------
-- 갱신 루프 / 이벤트
------------------------------------------------------------------------
local refreshScheduled = false
local lastPending, stall = -1, 0

function ns:ScheduleRefresh(delay)
    if refreshScheduled then return end
    refreshScheduled = true
    C_Timer.After(delay or 0.4, function()
        refreshScheduled = false
        ns:Refresh()
    end)
end

local uiScheduled = false
function ns:ScheduleUIUpdate()
    if uiScheduled then return end
    uiScheduled = true
    C_Timer.After(0.5, function()
        uiScheduled = false
        if ns.frame and ns.frame:IsShown() and ns.indexState == "done" and not ns.lastError then ns:UpdateUI() end
    end)
end

function ns:Refresh(userAction)
    if not (self.frame and self.frame:IsShown()) then return end
    if userAction then stall = 0; lastPending = -1; self.pendingStalled = false end
    self:EnsureIndex()
    if self.indexState == "idle" or self.indexState == "running" then
        self:UpdateUI()
        return
    end
    if self.indexState == "done" then
        self.lastError = nil
        local ok, res = xpcall(function() return self:Compute() end, function(e)
            return tostring(e) .. "\n" .. (debugstack and debugstack(2, 6, 0) or "")
        end)
        if not ok then
            self.lastError = res
            if self.lastErrorPrinted ~= res then
                self.lastErrorPrinted = res
                Print(L["|cffff5555계산 중 오류:|r "] .. tostring(res))
            end
            self:UpdateUI()
            return
        end
        local pending = res or 0
        if pending > 0 then
            if pending >= lastPending and lastPending >= 0 then stall = stall + 1 else stall = 0 end
            lastPending = pending
            self.pendingStalled = stall >= 6
            if stall < 6 then self:ScheduleRefresh(1.5) end
        else
            lastPending, stall = -1, 0
            self.pendingStalled = false
        end
    end
    self:UpdateUI()
end

-- '검색' 버튼: 캐시/대기 상태를 비우고 현재 착용 장비 기준으로 처음부터 다시 계산
function ns:ForceRefresh()
    wipe(requested)
    wipe(queue)
    wipe(queueLo)
    wipe(attempts)
    wipe(dead)
    if self.indexState == "empty" then self:ResetIndex() end
    self:Refresh(true)
end

local driver = CreateFrame("Frame")
local acc = 0
driver:SetScript("OnUpdate", function(_, dt)
    -- 인덱싱 코루틴 진행
    if indexCo and ns.indexState == "running" then
        budgetStart = debugprofilestop()
        local ok, err = coroutine.resume(indexCo)
        if not ok then
            ns.indexState = "empty"
            indexCo = nil
            Print(L["데이터 읽기 오류: "] .. tostring(err))
            ns:Refresh()
        elseif coroutine.status(indexCo) == "dead" then
            indexCo = nil
            ns.indexState = (ns.indexStats.items > 0) and "done" or "empty"
            local okR, errR = pcall(ns.Refresh, ns)
            if not okR then ns.lastError = tostring(errR); Print(L["|cffff5555화면 갱신 오류:|r "] .. tostring(errR)) end
        elseif ns.frame and ns.frame:IsShown() and ns.UpdateProgress then
            ns:UpdateProgress()
        end
    end
    -- 아이템 정보 요청을 조금씩 나눠 보냄
    acc = acc + dt
    if acc >= (ns.fastLoad and 0.03 or 0.1) and (#queue > 0 or #queueLo > 0) then
        acc = 0
        for _ = 1, (ns.fastLoad and 200 or 30) do
            local id = table.remove(queue) or table.remove(queueLo)
            if not id then break end
            if C_Item and C_Item.RequestLoadItemDataByID then
                C_Item.RequestLoadItemDataByID(id)
            else
                GetItemInfoC(id)
            end
        end
    end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
-- 클라이언트에 없는 이벤트일 수 있으므로 보호해서 등록
pcall(ev.RegisterEvent, ev, "QUEST_TURNED_IN")
pcall(ev.RegisterEvent, ev, "QUEST_DATA_LOAD_RESULT")
ev:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then InitDB() end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if arg2 == false and requested[arg1] then dead[arg1] = true end   -- 서버가 '없음'이라고 답한 아이템
        if ns.frame and ns.frame:IsShown() and ns.stats.pending > 0 then ns:ScheduleRefresh(1.5) end
        if ns.OnItemInfo then ns.OnItemInfo() end
    elseif event == "QUEST_TURNED_IN" then
        ns:ScheduleRefresh(0.8)
    elseif event == "QUEST_DATA_LOAD_RESULT" then
        ns:ScheduleUIUpdate()
    elseif event == "PLAYER_LEVEL_UP" then
        C_Timer.After(0.5, function() ns:Refresh(true) end)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        ns:ScheduleRefresh(0.3)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.indexState == "idle" or ns.indexState == "empty" then ns:Refresh(true) end
    end
end)

------------------------------------------------------------------------
-- 슬래시 명령어
------------------------------------------------------------------------
SLASH_BESTGEARFINDER1 = "/bgf"
SLASH_BESTGEARFINDER2 = "/내템"
SLASH_BESTGEARFINDER3 = "/bestgear"
SlashCmdList["BESTGEARFINDER"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local q = msg:match("^find%s*(.*)$") or msg:match("^검색%s*(.*)$")
    if q then
        if ns.SearchFor then ns:SearchFor(q) end
    elseif msg == "debug" or msg == "diag" or msg == "진단" then
        if ns.indexState == "done" and ns.frame then ns:Refresh(true) end
        Print(string.format(L["상태=%s, 모듈=%d, 보스=%d, 장비 아이템=%d(제작 %d, 퀘스트 %d), 후보=%d, 로딩완료=%d, 대기=%d"],
            ns.indexState, ns.indexStats.modules, ns.indexStats.bosses, ns.indexStats.items, ns.indexStats.craft or 0, ns.indexStats.quest or 0,
            ns.stats.candidates, ns.stats.ready, ns.stats.pending))
        Print(L["아이템 처리 오류 수: "] .. tostring(ns.itemErrors or 0) .. (ns.firstItemError and (L[" / 첫 오류: "] .. ns.firstItemError) or ""))
        if ns.slotError then Print(L["슬롯 처리 오류: "] .. ns.slotError) end
        if ns.lastError then Print(L["마지막 오류: "] .. ns.lastError) end
        local d = ns.GearDB or {}
        local sourceItems, sourceCount = 0, 0
        if type(d.sources) == "table" then
            for _, src in pairs(d.sources) do sourceItems = sourceItems + 1; if type(src) == "table" then sourceCount = sourceCount + #src end end
        end
        Print(L["신규 아이템(출처 불명): "] .. tostring(ns.indexStats.new or 0))
        Print(L["CMaNGOS 데이터: 아이템="] .. sourceItems .. L[", 출처="] .. sourceCount .. L[", 버전="] .. tostring(d.version or "?"))
    elseif msg:match("^why%s+%d+$") or msg:match("^왜%s+%d+$") then
        local id = tonumber(msg:match("%d+"))
        local rec = ns.index and ns.index[id]
        local function P(t) Print("[why " .. id .. "] " .. t) end
        if not rec then P("not in index (not equippable, or not in data)"); return end
        local _, class = UnitClass("player")
        local rules = ns.CLASS_RULES[class]
        local level = UnitLevel("player")
        local dw = rules.dualWield and level >= (ns.DUAL_WIELD_LEVEL[class] or 99) or false
        local minReq, maxReq = ns:GetRange()
        P(("loc=%s class=%s sub=%s new=%s"):format(tostring(rec.loc), tostring(rec.classID), tostring(rec.subID), tostring(rec.new)))
        for _, sr in ipairs(rec.src) do
            P(("src kind=%s inst=%s allowed=%s%s"):format(tostring(sr.kind), tostring(sr.inst), tostring(SrcAllowed(sr)),
                sr.qid and (" qid=" .. sr.qid .. " done=" .. tostring(QuestDone(sr.qid))) or ""))
        end
        P("sourceAllowed=" .. tostring(ns:SourceAllowed(rec)) .. " usable=" .. tostring(Usable(rec, rules, GetArmorType(rules, level), dw)))
        local name, _, quality, ilvl, req = GetItemInfoC(id)
        P(("name=%s quality=%s ilvl=%s req=%s inRange=%s range=%d-%d"):format(tostring(name), tostring(quality), tostring(ilvl), tostring(req), tostring(name and InRange(req, minReq, maxReq, ilvl, ns:IsAnyBis(id))), minReq, maxReq))
        do
            local _, link = GetItemInfoC(id)
            local st = link and GetStats(link)
            if type(st) == "table" then
                local parts = {}
                for k, v in pairs(st) do parts[#parts + 1] = k:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", "") .. "=" .. tostring(v) end
                table.sort(parts)
                P("stats: " .. (#parts > 0 and table.concat(parts, ", ") or "(none)"))
                for _, sp in ipairs(ns:GetSpecList()) do
                    P(("score[%s]=%.1f"):format(sp.nameKo or sp.name, ScoreItem(link, ilvl, sp.w)))
                end
            else
                P("stats: not available (" .. tostring(link and "no stats" or "not loaded") .. ")")
            end
        end
        do
            local ts = ns.TooltipStats(id)
            if ts then
                local parts = {}
                for k, v in pairs(ts) do parts[#parts + 1] = k:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", "") .. "=" .. v end
                table.sort(parts)
                P("tooltip stats: " .. (#parts > 0 and table.concat(parts, ", ") or "(none read)"))
            else
                P("tooltip stats: tooltip not readable")
            end
        end
        P("qualityAllowed=" .. tostring(quality and db.qual[quality]) .. " junkName=" .. tostring(name and IsJunkName(name) and true or false))
        P(("abilityRelic=%s useLine=%s itemSpell=%s"):format(tostring(IsAbilityRelic(id, rec)), tostring(HasUseLine(id)), tostring(GetItemSpellC and select(1, GetItemSpellC(id)))))
    elseif msg == "reset" or msg == "초기화" then
        db.point = nil
        if ns.frame then ns.frame:ClearAllPoints() ns.frame:SetPoint("CENTER") end
        ns:ResetLauncher()
        Print(L["창 위치를 초기화했습니다."])
    elseif msg:match("^%d+%s*[~%-%s]%s*%d+$") then
        local a, b = msg:match("^(%d+)%s*[~%-%s]%s*(%d+)$")
        local lo, hi = ns:SetRange(a, b)
        Print(string.format(L["요구 레벨 범위: %d ~ %d"], lo, hi))
        if ns.frame and ns.frame:IsShown() then ns:ForceRefresh() else ns:Toggle() end
    elseif msg == "craft" or msg == "crafting" or msg == "제작" then
        db.crafting = not db.crafting
        Print(L["제작템 포함: "] .. (db.crafting and L["켜짐"] or L["꺼짐"]))
        ns:Refresh(true)
    elseif msg == "quest" or msg == "quests" or msg == "퀘스트" then
        db.quests = not db.quests
        Print(L["퀘스트 보상 포함: "] .. (db.quests and L["켜짐"] or L["꺼짐"]))
        ns:Refresh(true)
    elseif msg:match("^확률%s*[%d%.]+$") or msg:match("^chance%s*[%d%.]+$") then
        db.minChance = tonumber(msg:match("([%d%.]+)$")) or 1
        Print(string.format(L["최소 드랍률: %.1f%%"], db.minChance))
        ns:Refresh(true)
    elseif msg:match("^등급") or msg:match("^quality") then
        local want = { ["하"] = 0, ["일"] = 1, ["녹"] = 2, ["청"] = 3, ["보"] = 4, ["주"] = 5 }
        local any = false
        db.qual = {}
        for ch, q in pairs(want) do if msg:find(ch, 1, true) then db.qual[q] = true; any = true end end
        for word, q in pairs({ gray = 0, grey = 0, white = 1, green = 2, blue = 3, rare = 3, epic = 4, purple = 4, legendary = 5, orange = 5 }) do
            if msg:find(word, 1, true) then db.qual[q] = true; any = true end
        end
        if not any then db.qual = { [2] = true, [3] = true, [4] = true } end
        Print(L["등급 필터를 바꿨습니다. 예: /bgf 등급 녹청"])
        ns:Refresh(true)
    elseif msg == "슬롯" or msg == "slot" then
        if not ns.funnel then Print(L["먼저 창을 열어 검색하세요."]) else
            for _, g in ipairs(ns.GROUPS) do
                local f = ns.funnel[g.key]
                if f then Print(string.format(L["%s: 후보 %d개, 착용 점수 %.1f, 최고 후보 점수 %.1f (id %s)"], tostring(g.name or g.key), f.cand, f.base, f.top, tostring(f.topId))) end
            end
        end
    elseif msg == "월드드랍" or msg == "경매장" or msg == "auction" or msg == "worlddrop" then
        db.auction = not db.auction
        Print(L["월드 드랍(저확률 잡몹 드랍) 포함: "] .. (db.auction and L["켜짐"] or L["꺼짐"]))
        ns:Refresh(true)
    elseif msg:match("^lang") or msg:match("^언어") then
        local a = msg:match("^%S+%s+(%S+)")
        if a == "en" or a == "ko" then db.lang = a
        elseif a == "auto" or a == "자동" then db.lang = nil
        else Print("/bgf lang en | ko | auto") return end
        ns.SetLang(db.lang)
        if ns.RelabelData then ns.RelabelData() end
        if ns.RebuildUI then ns:RebuildUI() end
        Print("Language: " .. (db.lang or "auto"))
    elseif msg == "icon" or msg == "아이콘" then
        db.iconShown = not db.iconShown
        ns:UpdateLauncher()
        Print(L["화면 아이콘: "] .. (db.iconShown and L["켜짐"] or L["꺼짐"]))
    elseif msg == "new" or msg == "신규" then
        db.newItems = not db.newItems
        Print(L["신규 아이템(출처 불명) 포함: "] .. (db.newItems and L["켜짐"] or L["꺼짐"]))
        ns:Refresh(true)
    elseif msg == "rescan" or msg == "재검색" then
        db.scan = {}
        Print(L["신규 아이템을 처음부터 다시 검색합니다."])
        ns:ResetIndex()
        ns:Refresh(true)
    elseif msg == "donate" or msg == "후원" then
        ns:ShowDonate()
    elseif msg == "all" or msg == "전체" then
        Print(L["CMaNGOS 데이터 범위는 tools/extract_cmnangos.py 실행 옵션으로 결정됩니다."])
    else
        ns:Toggle()
    end
end


------------------------------------------------------------------------
-- 후원 링크 (Buy Me a Coffee): 애드온은 브라우저를 열 수 없으므로 복사용 입력창을 보여준다
------------------------------------------------------------------------
ns.DONATE_URL = "https://buymeacoffee.com/qqhrqqhr2"
StaticPopupDialogs["BESTGEARFINDER_DONATE"] = {
    text = "Best Gear Finder\n%s",
    button1 = CLOSE or "Close",
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        local eb = self.editBox or self.EditBox
        if eb then eb:SetText(ns.DONATE_URL); eb:HighlightText(); eb:SetFocus() end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
function ns:ShowDonate()
    StaticPopup_Show("BESTGEARFINDER_DONATE", L["도움이 되셨다면 커피 한 잔으로 응원해 주세요! (Ctrl+C로 복사)"])
end
