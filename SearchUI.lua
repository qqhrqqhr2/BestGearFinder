-- Best Gear Finder : 아이템 검색 창 (별도 팝업)
-- 이름/보스, 등급, 요구 레벨, 부위, 방어구·무기 종류, 획득처로 전체 아이템 데이터를 검색한다.
local ADDON, ns = ...
local L = ns.L

local W, H = 780, 640
local ROW_H, MAX_ROWS = 22, 150
local win, listChild, countText, noteText, nameBox, minBox, maxBox, mineChk
local rows = {}
local CatMatch
local filter = { text = "", noReq = true, q = {}, src = {}, mine = false, cat = nil, catKey = nil }
-- 기본값: 고급·희귀, 획득처 전체, 레벨 제한 없음 포함
local function ApplyDefaults()
    filter.text, filter.mine, filter.noReq = "", false, true
    filter.cat, filter.catKey = nil, nil
    for _, set in ipairs({ filter.q, filter.src }) do wipe(set) end
    filter.q[2], filter.q[3] = true, true
    for _, k in ipairs({ "drop", "quest", "craft", "vendor", "unknown" }) do filter.src[k] = true end
end
ApplyDefaults()
local timer, polling = nil, false
local token = 0
local running = false
local lastPending, lastChange = -1, 0
local refreshQueued = false
local searchBtn, qualChecks, noReqChk = nil, {}, nil
local bar
local expanded = {}   -- 분류 트리에서 펼친 항목 (창을 다시 만들어도 유지)

local ARMOR_KINDS = { { 4, 1 }, { 4, 2 }, { 4, 3 }, { 4, 4 }, { 4, 6 }, { 4, 0 }, { 4, 7 }, { 4, 8 }, { 4, 9 } }
local WEAPON_KINDS = { { 2, 0 }, { 2, 1 }, { 2, 4 }, { 2, 5 }, { 2, 7 }, { 2, 8 }, { 2, 15 }, { 2, 13 }, { 2, 6 }, { 2, 10 },
                       { 2, 2 }, { 2, 18 }, { 2, 3 }, { 2, 16 }, { 2, 19 }, { 2, 14 }, { 2, 20 } }
local FALLBACK = {
    ["4:0"] = "장신구/목걸이/반지/기타", ["4:1"] = "천", ["4:2"] = "가죽", ["4:3"] = "사슬", ["4:4"] = "판금", ["4:6"] = "방패",
    ["4:7"] = "성서", ["4:8"] = "우상", ["4:9"] = "토템",
    ["2:0"] = "한손 도끼", ["2:1"] = "양손 도끼", ["2:2"] = "활", ["2:3"] = "총", ["2:4"] = "한손 둔기", ["2:5"] = "양손 둔기",
    ["2:6"] = "장창", ["2:7"] = "한손 검", ["2:8"] = "양손 검", ["2:10"] = "지팡이", ["2:13"] = "격투 무기", ["2:15"] = "단검",
    ["2:16"] = "투척 무기", ["2:18"] = "석궁", ["2:19"] = "마법봉", ["2:14"] = "기타 무기", ["2:20"] = "낚싯대",
}

local EN_KIND = {
    ["4:1"] = "Cloth", ["4:2"] = "Leather", ["4:3"] = "Mail", ["4:4"] = "Plate", ["4:6"] = "Shields",
    ["4:7"] = "Librams", ["4:8"] = "Idols", ["4:9"] = "Totems",
    ["2:0"] = "One-Handed Axes", ["2:1"] = "Two-Handed Axes", ["2:2"] = "Bows", ["2:3"] = "Guns",
    ["2:4"] = "One-Handed Maces", ["2:5"] = "Two-Handed Maces", ["2:6"] = "Polearms", ["2:7"] = "One-Handed Swords",
    ["2:8"] = "Two-Handed Swords", ["2:10"] = "Staves", ["2:13"] = "Fist Weapons", ["2:14"] = "Miscellaneous",
    ["2:15"] = "Daggers", ["2:16"] = "Thrown", ["2:18"] = "Crossbows", ["2:19"] = "Wands", ["2:20"] = "Fishing Poles",
}
local EN_QUALITY = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
-- 현재 표시 언어가 영어인지 (게임 클라이언트가 한국어여도 애드온 언어 설정을 따른다)
local function IsEnglish() return L["요구 레벨"] ~= "요구 레벨" end

local function KindName(cID, sID)
    local key = cID .. ":" .. sID
    if IsEnglish() and EN_KIND[key] then return EN_KIND[key] end
    if cID == 4 and sID == 0 then return L["장신구/목걸이/반지/기타"] end
    local fn = GetItemSubClassInfo or (C_Item and C_Item.GetItemSubClassInfo)
    if fn then
        local ok, n = pcall(fn, cID, sID)
        if ok and type(n) == "string" and n ~= "" then return n end
    end
    return L[FALLBACK[key] or key]
end

local function QualityName(q)
    local n = IsEnglish() and EN_QUALITY[q] or _G["ITEM_QUALITY" .. q .. "_DESC"]
    local col = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if type(n) ~= "string" then n = tostring(q) end
    if col and type(col.hex) == "string" then return col.hex .. n .. "|r" end
    return n
end

local locToGroup = {}
for _, g in ipairs(ns.GROUPS) do
    for loc in pairs(g.locs) do locToGroup[loc] = g.key end
end

------------------------------------------------------------------------
-- 검색 실행
------------------------------------------------------------------------
local function Link(row, data)
    row.data = data
end

local function GetRow(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, listChild)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(18, 18)
    r.icon:SetPoint("LEFT", 2, 0)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
    r.name:SetWidth(190)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.info = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.info:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
    r.info:SetWidth(150)
    r.info:SetJustifyH("LEFT")
    r.info:SetWordWrap(false)
    r.src = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.src:SetPoint("LEFT", r.info, "RIGHT", 4, 0)
    r.src:SetPoint("RIGHT", -4, 0)
    r.src:SetJustifyH("LEFT")
    r.src:SetWordWrap(false)
    r:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        if not self.link then return end
        if IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link)
        elseif IsControlKeyDown() and DressUpItemLink then DressUpItemLink(self.link) end
    end)
    rows[i] = r
    return r
end

------------------------------------------------------------------------
-- 경매장 식 분류 트리: 무기 / 방어구(천·가죽·사슬·판금 → 부위, 기타 → 목걸이·반지·장신구…) / 방패 / 성물
------------------------------------------------------------------------
local function GroupNode(key)
    for _, g in ipairs(ns.GROUPS) do
        if g.key == key then return { label = g.label, locs = g.locs } end
    end
    return { label = key }
end
local function WithBase(node, c, s)
    node.c, node.s = c, s
    return node
end
local TREE
local function BuildTree()
    local weapon = { label = L["무기"], c = 2, children = {} }
    for _, k in ipairs(WEAPON_KINDS) do
        weapon.children[#weapon.children + 1] = { label = KindName(k[1], k[2]), c = k[1], s = k[2] }
    end
    local armor = { label = L["방어구"], c = 4, ss = { [1] = true, [2] = true, [3] = true, [4] = true }, children = {} }
    local slotKeys = { "HEAD", "SHOULDER", "CHEST", "WRIST", "HAND", "WAIST", "LEGS", "FEET" }
    for _, sid in ipairs({ 1, 2, 3, 4 }) do
        local n = { label = KindName(4, sid), c = 4, s = sid, children = {} }
        for _, key in ipairs(slotKeys) do n.children[#n.children + 1] = WithBase(GroupNode(key), 4, sid) end
        armor.children[#armor.children + 1] = n
    end
    armor.children[#armor.children + 1] = WithBase(GroupNode("CLOAK"), 4, nil)   -- 등: 방어구 바로 아래
    local top = { weapon, armor, { label = KindName(4, 6), c = 4, s = 6 } }
    for _, sid in ipairs({ 7, 8, 9 }) do
        top[#top + 1] = { label = KindName(4, sid), c = 4, s = sid }
    end
    for _, key in ipairs({ "NECK", "FINGER", "TRINKET" }) do
        top[#top + 1] = WithBase(GroupNode(key), 4, nil)   -- 부위(loc)만 보고 방어구 하위 종류는 따지지 않음
    end
    top[#top + 1] = { label = L["보조 장비"], c = 4, locs = { INVTYPE_HOLDABLE = true } }
    return top
end

CatMatch = function(node, rec)
    if node.c and rec.classID ~= node.c then return false end
    if node.s and rec.subID ~= node.s then return false end
    if node.ss and not node.ss[rec.subID] then return false end
    if node.locs and not node.locs[rec.loc] then return false end
    return true
end

local function SrcMatch(rec, set)
    if next(set) == nil then return true end
    for key in pairs(set) do
        if key == "unknown" then
            if rec.new or rec.kinds.unknown or next(rec.kinds) == nil then return true end
        elseif rec.kinds[key] then
            return true
        end
    end
    return false
end

local function HasQuality() return next(filter.q) ~= nil end
local function HasFilter(minL, maxL)
    return filter.text ~= "" or HasQuality() or filter.cat or next(filter.src) or minL or maxL
end
local function SetRunning(v)
    running = v
    ns.fastLoad = v        -- 검색 중에는 아이템 정보 요청을 더 빠르게 보낸다
    if not v and bar then bar:Hide() end
    if searchBtn then searchBtn:SetText(v and L["중지"] or L["검색"]) end
end

local Run
local function Schedule(delay)
    token = token + 1
    local my = token
    timer = true
    C_Timer.After(delay or 0.3, function()
        if my ~= token then return end
        timer = nil
        Run()
    end)
end

function Run()
    if not win or not win:IsShown() or not running then return end
    for _, r in ipairs(rows) do r:Hide() end
    if ns.indexState ~= "done" then
        ns:EnsureIndex()
        countText:SetText("")
        noteText:SetText(L["아이템 정보를 불러오는 중입니다..."])
        Schedule(1)
        return
    end
    local minL, maxL = tonumber(minBox:GetText()), tonumber(maxBox:GetText())
    if not HasFilter(minL, maxL) then
        countText:SetText("")
        noteText:SetText(L["조건을 고르면 해당하는 아이템이 모두 표시됩니다."])
        SetRunning(false)
        return
    end
    local text = filter.text
    local pending, results, cand = 0, {}, 0
    for id, rec in pairs(ns.index) do
        if rec and ns:IsItemDead(id) == false then
            local ok = true
            if filter.cat and not CatMatch(filter.cat, rec) then ok = false end
            if ok and not SrcMatch(rec, filter.src) then ok = false end
            if ok and filter.mine and not ns:UsableByActive(rec) then ok = false end
            if ok then
                cand = cand + 1
                local name, link, quality, ilvl, req, _, _, _, _, icon = ns.GetItemInfoC(id)
                if not name then
                    pending = pending + 1
                    ns:RequestItem(id)
                else
                    local good = true
                    if HasQuality() and not filter.q[quality or 0] then good = false end
                    if good and not (filter.noReq and (req or 0) == 0) then
                        if minL and (req or 0) < minL then good = false end
                        if good and maxL and (req or 0) > maxL then good = false end
                    end
                    if good and text ~= "" then
                        local hit = string.find(string.lower(name), text, 1, true)
                        if not hit then
                            for _, s in ipairs(rec.src) do
                                if string.find(string.lower((s.boss or "") .. " " .. (s.inst or "")), text, 1, true) then hit = true; break end
                            end
                        end
                        good = hit and true or false
                    end
                    if good then
                        results[#results + 1] = { id = id, rec = rec, name = name, link = link, quality = quality or 1,
                                                  ilvl = ilvl or 0, req = req or 0, icon = icon or rec.icon }
                    end
                end
            end
        end
    end
    table.sort(results, function(a, b)
        if a.req ~= b.req then return a.req > b.req end
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end
        return a.id < b.id
    end)
    local total = #results
    for i = 1, math.min(total, MAX_ROWS) do
        local d = results[i]
        local r = GetRow(i)
        r.link = d.link
        r.icon:SetTexture(d.icon)
        local col = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[d.quality]
        r.name:SetText(((col and type(col.hex) == "string" and col.hex) or "|cffffffff") .. d.name .. "|r")
        r.info:SetText(format("%s %d · %s %d · %s", L["요구"], d.req, "ilvl", d.ilvl, KindName(d.rec.classID, d.rec.subID)))
        r.src:SetText(ns.ShortSource and ns:ShortSource(d.rec) or "")
        r:Show()
    end
    listChild:SetHeight(math.max(1, math.min(total, MAX_ROWS) * ROW_H))
    if total > MAX_ROWS then
        countText:SetText(format(L["%d개 중 %d개 표시"], total, MAX_ROWS))
    else
        countText:SetText(format(L["%d개"], total))
    end
    noteText:SetText(pending > 0 and format(L["%d개 불러오는 중..."], pending) or (total == 0 and L["검색 결과가 없습니다."] or ""))
    -- 로딩바: 불러온 비율 (후보 중 정보가 도착한 아이템)
    if bar then
        if pending > 0 and cand > 0 then
            bar:SetValue((cand - pending) / cand)
            bar:Show()
        else
            bar:Hide()
        end
    end
    -- 대기 개수가 몇 번 연속으로 안 줄면(서버가 답하지 않는 아이템) 기다리지 않고 끝낸다
    local now = GetTime()
    if pending ~= lastPending then lastChange = now end
    lastPending = pending
    if pending > 0 and now - lastChange < 4 then
        Schedule(0.7)          -- 아이템 정보가 더 도착하면 갱신 (중지를 누를 때까지)
    else
        if pending > 0 then noteText:SetText(format(L["%d개는 불러오지 못해 제외했습니다"], pending)) end
        SetRunning(false)      -- 끝
    end
end

local function StartSearch()
    if not win then return end
    lastPending, lastChange = -1, GetTime()
    SetRunning(true)
    Schedule(0.01)
end
local function StopSearch()
    token = token + 1          -- 예약된 갱신 취소
    SetRunning(false)
    if noteText then
        local t = noteText:GetText() or ""
        noteText:SetText(t:find("%.%.%.") and L["중지됨"] or t)
    end
end

-- 아이템 정보가 도착하면 (검색창이 열려 있고 불러오는 중일 때) 조금 뒤에 다시 검색
function ns.OnItemInfo()
    -- 정보가 도착하면 (너무 자주는 말고) 곧바로 목록을 갱신
    if running and not refreshQueued then
        refreshQueued = true
        C_Timer.After(0.35, function()
            refreshQueued = false
            if running then Run() end
        end)
    end
end

------------------------------------------------------------------------
-- 창 만들기
------------------------------------------------------------------------
local function Build()
    win = CreateFrame("Frame", "BestGearFinderSearchFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    win:SetSize(W, H)
    win:SetPoint("CENTER", 60, 0)
    win:SetFrameStrata("DIALOG")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    if ns.SolidBG then ns.SolidBG(win) end
    local function ApplyAlpha(a)
        a = math.max(0.3, math.min(1, a or 0.85))
        if win.solidBG then win.solidBG:SetAlpha(a) end
        if win.SetBackdropColor then win:SetBackdropColor(1, 1, 1, a) end
        if win.SetBackdropBorderColor then win:SetBackdropBorderColor(1, 1, 1, math.min(1, a + 0.2)) end
    end
    ApplyAlpha(ns.db and ns.db.searchAlpha or 0.85)
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:Hide()
    tinsert(UISpecialFrames, "BestGearFinderSearchFrame")

    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText(L["아이템 검색"])
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- 투명도 슬라이더
    local sl = CreateFrame("Slider", "BestGearFinderSearchAlpha", win, "OptionsSliderTemplate")
    sl:SetPoint("TOPRIGHT", -70, -26)
    sl:SetSize(110, 14)
    sl:SetMinMaxValues(0.3, 1)
    sl:SetValueStep(0.05)
    if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
    local slText = _G["BestGearFinderSearchAlphaText"]
    if slText then slText:SetText(L["투명도"]); slText:ClearAllPoints(); slText:SetPoint("RIGHT", sl, "LEFT", -6, 0) end
    local slLow, slHigh = _G["BestGearFinderSearchAlphaLow"], _G["BestGearFinderSearchAlphaHigh"]
    if slLow then slLow:SetText("") end
    if slHigh then slHigh:SetText("") end
    sl:SetValue(ns.db and ns.db.searchAlpha or 0.85)
    sl:SetScript("OnValueChanged", function(_, v)
        if ns.db then ns.db.searchAlpha = v end
        ApplyAlpha(v)
    end)

    -- 이름 입력
    local nl = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nl:SetPoint("TOPLEFT", 22, -52)
    nl:SetText(L["이름/보스"])
    nameBox = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
    nameBox:SetSize(190, 20)
    nameBox:SetPoint("LEFT", nl, "RIGHT", 12, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(40)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); StartSearch() end)
    -- 옅은 안내 문구: 비워 두면 이름과 상관없이 전체 (선택 입력)
    local nameHint = nameBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    nameHint:SetPoint("LEFT", nameBox, "LEFT", 4, 0)
    nameHint:SetText(L["선택 입력 · 비워 두면 전체"])
    local function UpdateHint()
        local empty = (nameBox:GetText() or "") == ""
        nameHint:SetShown(empty and not nameBox:HasFocus())
    end
    nameBox:SetScript("OnTextChanged", function(self)
        filter.text = string.lower((self:GetText() or ""):match("^%s*(.-)%s*$"))
        UpdateHint()
    end)
    nameBox:SetScript("OnEditFocusGained", function() nameHint:Hide() end)
    nameBox:SetScript("OnEditFocusLost", UpdateHint)

    -- 요구 레벨 범위
    local ll = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ll:SetPoint("LEFT", nameBox, "RIGHT", 18, 0)
    ll:SetText(L["요구 레벨"])
    local function LevelEdit(anchor, dx)
        local e = CreateFrame("EditBox", nil, win, "InputBoxTemplate")
        e:SetSize(34, 20)
        e:SetPoint("LEFT", anchor, "RIGHT", dx, 0)
        e:SetAutoFocus(false)
        e:SetNumeric(true)
        e:SetMaxLetters(2)
        e:SetJustifyH("CENTER")
        e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        e:SetScript("OnEnterPressed", function(self) self:ClearFocus(); StartSearch() end)
        return e
    end
    minBox = LevelEdit(ll, 14)
    local tl = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tl:SetPoint("LEFT", minBox, "RIGHT", 4, 0)
    tl:SetText("~")
    maxBox = LevelEdit(tl, 8)
    noReqChk = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
    noReqChk:SetSize(22, 22)
    noReqChk:SetPoint("LEFT", maxBox, "RIGHT", 6, 0)
    local nrl = noReqChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nrl:SetPoint("LEFT", noReqChk, "RIGHT", 0, 0)
    nrl:SetText(L["레벨 제한 없음 포함"])
    noReqChk:SetChecked(filter.noReq)
    noReqChk:SetScript("OnClick", function(self) filter.noReq = self:GetChecked() and true or false end)

    -- 체크박스 묶음 (등급 / 획득처): 아무것도 안 고르면 전체
    local checkLists = {}
    local y = -80
    local CELL = 112
    local function MakeChecks(title, entries, set)
        local tx = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tx:SetPoint("TOPLEFT", 22, y - 5)
        tx:SetText(title)
        for idx, e in ipairs(entries) do
            local cb = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
            cb:SetSize(22, 22)
            cb:SetPoint("TOPLEFT", 78 + (idx - 1) * CELL, y)
            cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cb.label:SetPoint("LEFT", cb, "RIGHT", 0, 0)
            cb.label:SetText(e.label)
            cb:SetChecked(set[e.key] and true or false)
            cb:SetScript("OnClick", function(self) set[e.key] = self:GetChecked() and true or nil end)
            checkLists[#checkLists + 1] = { cb = cb, set = set, key = e.key }
        end
        y = y - 26
    end
    local qEntries = {}
    for q = 1, 5 do qEntries[#qEntries + 1] = { key = q, label = QualityName(q) } end
    MakeChecks(L["등급"], qEntries, filter.q)
    MakeChecks(L["획득처"], {
        { key = "drop", label = L["드랍"] }, { key = "quest", label = L["퀘스트"] }, { key = "craft", label = L["제작"] },
        { key = "vendor", label = L["상점"] }, { key = "unknown", label = L["출처 불명"] },
    }, filter.src)

    -- 착용 가능만 / 검색 / 초기화
    mineChk = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
    mineChk:SetPoint("TOPLEFT", 16, y - 2)
    mineChk:SetSize(24, 24)
    local ml = mineChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ml:SetPoint("LEFT", mineChk, "RIGHT", 2, 0)
    ml:SetText(L["착용 가능한 아이템만"])
    mineChk:SetChecked(filter.mine)
    mineChk:SetScript("OnClick", function(self) filter.mine = self:GetChecked() and true or false end)

    searchBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    searchBtn:SetSize(80, 22)
    searchBtn:SetPoint("TOPRIGHT", -108, y - 2)
    searchBtn:SetText(L["검색"])
    searchBtn:SetScript("OnClick", function()
        if running then StopSearch() else StartSearch() end
    end)

    local treeRefresh
    local reset = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    reset:SetSize(80, 22)
    reset:SetPoint("TOPRIGHT", -24, y - 2)
    reset:SetText(L["초기화"])
    reset:SetScript("OnClick", function()
        StopSearch()
        ApplyDefaults()
        nameBox:SetText(""); ns.SearchDefaultRange(); mineChk:SetChecked(false); noReqChk:SetChecked(true)
        for _, c in ipairs(checkLists) do c.cb:SetChecked(c.set[c.key] and true or false) end
        treeRefresh()
    end)
    y = y - 32

    countText = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOPLEFT", 22, y)
    noteText = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noteText:SetPoint("LEFT", countText, "RIGHT", 10, 0)
    bar = CreateFrame("StatusBar", nil, win)
    bar:SetPoint("TOPRIGHT", -36, y + 5)
    bar:SetSize(260, 10)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.2, 0.75, 0.3)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    local bbg = bar:CreateTexture(nil, "BACKGROUND")
    bbg:SetAllPoints()
    bbg:SetColorTexture(0, 0, 0, 0.6)
    bar:Hide()
    y = y - 18

    local hint = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 22, 16)
    hint:SetText(L["Shift+클릭: 채팅창에 링크 / Ctrl+클릭: 미리보기"])

    -- 왼쪽: 경매장 식 분류 트리
    local TREE_W = 190
    local tscroll = CreateFrame("ScrollFrame", "BestGearFinderSearchTree", win, "UIPanelScrollFrameTemplate")
    tscroll:SetPoint("TOPLEFT", 18, y)
    tscroll:SetPoint("BOTTOMLEFT", 18, 34)
    tscroll:SetWidth(TREE_W)
    local tchild = CreateFrame("Frame", nil, tscroll)
    tchild:SetSize(TREE_W - 4, 1)
    tscroll:SetScrollChild(tchild)
    TREE = BuildTree()
    -- 언어를 바꿔 창을 다시 만들 때, 이전에 고른 분류를 같은 위치에서 다시 찾는다
    if filter.catKey then
        local list, node = TREE, nil
        for idx in filter.catKey:gmatch("/(%d+)") do
            node = list and list[tonumber(idx)]
            list = node and node.children
        end
        filter.cat = node
    end
    local trows = {}
    local flat

    local function Flatten(list, depth, prefix, out)
        for i, n in ipairs(list) do
            local key = prefix .. "/" .. i
            out[#out + 1] = { node = n, depth = depth, key = key }
            if n.children and expanded[key] then Flatten(n.children, depth + 1, key, out) end
        end
    end
    function treeRefresh()
        flat = { { node = nil, depth = 0, key = "all", label = L["전체"] } }
        Flatten(TREE, 0, "", flat)
        for i, f in ipairs(flat) do
            local b = trows[i]
            if not b then
                b = CreateFrame("Button", nil, tchild)
                b:SetHeight(20)
                b:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
                b:SetPoint("TOPRIGHT", 0, -(i - 1) * 20)
                b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                b.sel = b:CreateTexture(nil, "BACKGROUND")
                b.sel:SetAllPoints()
                b.sel:SetColorTexture(0.2, 0.45, 0.9, 0.35)
                b.t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                b.t:SetJustifyH("LEFT")
                b.t:SetWordWrap(false)
                trows[i] = b
            end
            b.t:ClearAllPoints()
            b.t:SetPoint("LEFT", 4 + f.depth * 12, 0)
            b.t:SetPoint("RIGHT", -2, 0)
            local n = f.node
            local label = f.label or n.label
            if n and n.children then label = (expanded[f.key] and "- " or "+ ") .. label end
            b.t:SetText(label)
            b.sel:SetShown(filter.cat == n)
            b:SetScript("OnClick", function()
                if n and n.children then expanded[f.key] = not expanded[f.key] end
                filter.cat, filter.catKey = n, (n and f.key or nil)
                treeRefresh()
            end)
            b:Show()
        end
        for i = #flat + 1, #trows do trows[i]:Hide() end
        tchild:SetHeight(math.max(1, #flat * 20))
    end
    treeRefresh()

    -- 오른쪽: 검색 결과
    local scroll = CreateFrame("ScrollFrame", "BestGearFinderSearchScroll", win, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18 + TREE_W + 26, y)
    scroll:SetPoint("BOTTOMRIGHT", -36, 34)
    listChild = CreateFrame("Frame", nil, scroll)
    listChild:SetSize(W - TREE_W - 90, 1)
    scroll:SetScrollChild(listChild)

    local function DefaultRange()
        local lo, hi = ns:GetRange()
        minBox:SetText(tostring(lo)); maxBox:SetText(tostring(hi))
    end
    ns.SearchDefaultRange = DefaultRange
    DefaultRange()
    win:SetScript("OnHide", function() StopSearch() end)
end

-- 언어가 바뀌면 검색창도 새 언어로 다시 만든다 (입력값과 선택은 유지)
function ns:RebuildSearch()
    if not win then return end
    local wasShown = win:IsShown()
    local nameT, minT, maxT = nameBox:GetText(), minBox:GetText(), maxBox:GetText()
    StopSearch()
    win:Hide()
    win:ClearAllPoints()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "BestGearFinderSearchFrame" then table.remove(UISpecialFrames, i) end
    end
    wipe(rows)
    win, listChild, countText, noteText, nameBox, minBox, maxBox, mineChk, searchBtn, noReqChk, bar = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
    Build()
    nameBox:SetText(nameT or ""); minBox:SetText(minT or ""); maxBox:SetText(maxT or "")
    if wasShown then win:Show() end
end

function ns:ToggleSearch()
    if not win then Build() end
    if win:IsShown() then win:Hide() else win:Show() end
end

-- /bgf find <이름>  : 검색창을 열고 바로 검색
function ns:SearchFor(text)
    if not win then Build() end
    win:Show()
    nameBox:SetText(text or "")
    filter.text = string.lower((text or ""):match("^%s*(.-)%s*$"))
    StartSearch()
end
