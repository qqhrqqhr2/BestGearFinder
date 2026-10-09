-- Best Gear Finder : 게임 중 실제로 얻은 장비의 획득처를 자동으로 기록한다.
--  * 전리품 창: 어떤 몹/상자에서, 어느 던전·지역에서 나왔는지
--  * 퀘스트 보상 창: 퀘스트 이름과 ID
--  * 상인 창: 상인 이름과 지역
-- 기록은 BestGearFinderDB.learned 에 저장되며, 툴팁과 추천 목록에 "(직접 확인)"으로 표시된다.
local ADDON, ns = ...
local L = ns.L

local GetItemInfoInstantC = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

-- 포에버 클라이언트는 일부 값을 읽을 수 없게(비밀 값) 돌려줄 수 있어서, 문자열/숫자로 쓸 수 있을 때만 받는다
local function Safe(v)
    if issecretvalue and issecretvalue(v) then return nil end
    local t = type(v)
    if t == "string" or t == "number" then
        local ok = pcall(function() return v .. "" end)
        if ok then return v end
    end
    return nil
end

local function ItemID(link)
    link = Safe(link)
    if not link then return nil end
    local ok, id = pcall(function() return tonumber(link:match("item:(%d+)")) end)
    return ok and id or nil
end

-- 장비인지 (부위가 있는 무기/방어구)
local function IsGear(id)
    local ok, _, _, _, loc = pcall(GetItemInfoInstantC, id)
    loc = ok and Safe(loc) or nil
    return loc and ns.EQUIP_LOCS and ns.EQUIP_LOCS[loc] and true or false
end

local function Where()
    local name, itype = GetInstanceInfo()
    name, itype = Safe(name), Safe(itype)
    if name and itype and itype ~= "none" then return name end
    return Safe(GetRealZoneText and GetRealZoneText()) or Safe(GetZoneText and GetZoneText()) or "?"
end

-- GUID -> 이름 (대상/마우스오버로 본 몹 이름을 기억해 둠)
local guidNames = {}
local function Remember(unit)
    local g = Safe(UnitGUID(unit))
    local n = Safe(UnitName(unit))
    if g and n then guidNames[g] = n end
end

local function NpcID(guid)
    local ok, id = pcall(function() return tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)")) end)
    return ok and id or nil
end

-- 데이터에 이미 획득처가 있는 아이템은 기록하지 않는다 (모르는 것만 채움)
local function Wanted(id)
    return IsGear(id) and ns:HasKnownSource(id) ~= true
end

local function Notify(id, link)
    if ns.db and ns.db.learnNotify and link then
        print("|cff33ccffBest Gear Finder|r: " .. L["획득처를 기록했습니다: "] .. link)
    end
end

local function OnLoot()
    local n = GetNumLootItems and GetNumLootItems() or 0
    local where = Where()
    for slot = 1, n do
        local link = GetLootSlotLink and GetLootSlotLink(slot)
        local id = ItemID(link)
        if id and Wanted(id) then
            local boss, npc = nil, nil
            local srcs = { pcall(GetLootSourceInfo, slot) }
            if srcs[1] then
                local g = Safe(srcs[2])
                if g then
                    if g:find("^GameObject") then
                        boss = L["상자"]
                    else
                        npc = NpcID(g)
                        boss = guidNames[g]
                    end
                end
            end
            if not boss then
                local tn = Safe(UnitName("target"))
                if tn and UnitIsDead and UnitIsDead("target") then boss = tn end
            end
            if ns:LearnSource(id, "drops", { inst = where, boss = boss or L["몹"], npc = npc }) then Notify(id, link) end
        end
    end
end

local function OnQuestComplete()
    local qid = Safe(GetQuestID and GetQuestID())
    local title = Safe(GetTitleText and GetTitleText())
    if not qid or not title then return end
    local function Scan(kind, count)
        for i = 1, count or 0 do
            local link = GetQuestItemLink and GetQuestItemLink(kind, i)
            local id = ItemID(link)
            if id and Wanted(id) then
                if ns:LearnSource(id, "quests", { qid = qid, title = title, lvl = 0 }) then Notify(id, link) end
            end
        end
    end
    Scan("choice", GetNumQuestChoices and GetNumQuestChoices())
    Scan("reward", GetNumQuestRewards and GetNumQuestRewards())
end

local function OnMerchant()
    local name = Safe(UnitName("npc"))
    if not name then return end
    local g = Safe(UnitGUID("npc"))
    local npc = g and NpcID(g)
    local zone = Where()
    for i = 1, (GetMerchantNumItems and GetMerchantNumItems() or 0) do
        local link = GetMerchantItemLink and GetMerchantItemLink(i)
        local id = ItemID(link)
        if id and Wanted(id) then
            ns:LearnSource(id, "vendors", { zone = zone, boss = name, npc = npc })
        end
    end
end

local f = CreateFrame("Frame")
for _, ev in ipairs({ "LOOT_OPENED", "QUEST_COMPLETE", "MERCHANT_SHOW", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT" }) do
    pcall(f.RegisterEvent, f, ev)
end
f:SetScript("OnEvent", function(_, event)
    if not ns.db or ns.db.learn == false then return end
    pcall(function()
        if event == "LOOT_OPENED" then OnLoot()
        elseif event == "QUEST_COMPLETE" then OnQuestComplete()
        elseif event == "MERCHANT_SHOW" then OnMerchant()
        elseif event == "PLAYER_TARGET_CHANGED" then Remember("target")
        elseif event == "UPDATE_MOUSEOVER_UNIT" then Remember("mouseover") end
    end)
end)

-- 기록한 개수
function ns:LearnedCount()
    local n = 0
    for _, kind in ipairs({ "drops", "quests", "vendors" }) do
        for _ in pairs(ns.db and ns.db.learned and ns.db.learned[kind] or {}) do n = n + 1 end
    end
    return n
end

-- /bgf export : 기록한 획득처를 복사할 수 있는 글로 보여준다 (개발자에게 보내면 애드온 데이터에 넣을 수 있음)
local exportFrame
function ns:ShowLearnedExport()
    local lines = {}
    local data = ns.db and ns.db.learned or {}
    for _, kind in ipairs({ "drops", "quests", "vendors" }) do
        local ids = {}
        for id in pairs(data[kind] or {}) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            for _, e in ipairs(data[kind][id]) do
                if kind == "quests" then
                    lines[#lines + 1] = string.format("%s\t%d\t%s\t%s", kind, id, tostring(e.qid), tostring(e.title))
                else
                    lines[#lines + 1] = string.format("%s\t%d\t%s\t%s\t%s", kind, id, tostring(e.inst or e.zone), tostring(e.boss), tostring(e.npc or ""))
                end
            end
        end
    end
    if not exportFrame then
        local f = CreateFrame("Frame", "BestGearFinderExport", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        f:SetSize(560, 360)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
        if ns.SolidBG then ns.SolidBG(f) end
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
        local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOPLEFT", 20, -18)
        t:SetText(L["기록한 획득처 (Ctrl+A, Ctrl+C로 복사)"])
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -6, -6)
        local sf = CreateFrame("ScrollFrame", "BestGearFinderExportScroll", f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 20, -44); sf:SetPoint("BOTTOMRIGHT", -36, 20)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true); eb:SetAutoFocus(true); eb:SetFontObject(ChatFontNormal); eb:SetWidth(490)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        f.eb = eb
        tinsert(UISpecialFrames, "BestGearFinderExport")
        exportFrame = f
    end
    exportFrame.eb:SetText(#lines > 0 and table.concat(lines, "\n") or L["아직 기록한 획득처가 없습니다."])
    exportFrame.eb:HighlightText()
    exportFrame:Show()
end
