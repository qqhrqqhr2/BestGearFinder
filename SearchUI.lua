-- Best Gear Finder : 아이템 검색 창 (별도 팝업)
-- 이름/보스, 등급, 요구 레벨, 부위, 방어구·무기 종류, 획득처로 전체 아이템 데이터를 검색한다.
local ADDON, ns = ...
local L = ns.L

local W, H = 700, 780
local ROW_H, MAX_ROWS = 22, 150
local win, listChild, countText, noteText, nameBox, minBox, maxBox, mineChk
local rows = {}
local filter = { text = "", q = {}, slot = {}, kind = {}, src = {}, mine = false }
local timer, polling = nil, false
local token = 0
local running = false
local searchBtn, qualChecks = nil, {}

local ARMOR_KINDS = { { 4, 1 }, { 4, 2 }, { 4, 3 }, { 4, 4 }, { 4, 6 }, { 4, 0 }, { 4, 7 }, { 4, 8 }, { 4, 9 } }
local WEAPON_KINDS = { { 2, 0 }, { 2, 1 }, { 2, 4 }, { 2, 5 }, { 2, 7 }, { 2, 8 }, { 2, 15 }, { 2, 13 }, { 2, 6 }, { 2, 10 },
                       { 2, 2 }, { 2, 18 }, { 2, 3 }, { 2, 16 }, { 2, 19 } }
local FALLBACK = {
    ["4:0"] = "장신구/목걸이/반지/기타", ["4:1"] = "천", ["4:2"] = "가죽", ["4:3"] = "사슬", ["4:4"] = "판금", ["4:6"] = "방패",
    ["4:7"] = "성서", ["4:8"] = "우상", ["4:9"] = "토템",
    ["2:0"] = "한손 도끼", ["2:1"] = "양손 도끼", ["2:2"] = "활", ["2:3"] = "총", ["2:4"] = "한손 둔기", ["2:5"] = "양손 둔기",
    ["2:6"] = "장창", ["2:7"] = "한손 검", ["2:8"] = "양손 검", ["2:10"] = "지팡이", ["2:13"] = "격투 무기", ["2:15"] = "단검",
    ["2:16"] = "투척 무기", ["2:18"] = "석궁", ["2:19"] = "마법봉",
}

local function KindName(cID, sID)
    local key = cID .. ":" .. sID
    if cID == 4 and sID == 0 then return L["장신구/목걸이/반지/기타"] end
    local fn = GetItemSubClassInfo or (C_Item and C_Item.GetItemSubClassInfo)
    if fn then
        local ok, n = pcall(fn, cID, sID)
        if ok and type(n) == "string" and n ~= "" then return n end
    end
    return L[FALLBACK[key] or key]
end

local function QualityName(q)
    local n = _G["ITEM_QUALITY" .. q .. "_DESC"]
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
    r.name:SetWidth(210)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.info = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.info:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
    r.info:SetWidth(170)
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
    return filter.text ~= "" or HasQuality() or next(filter.slot) or next(filter.kind) or next(filter.src) or minL or maxL
end
local function SetRunning(v)
    running = v
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
    local pending, results = 0, {}
    for id, rec in pairs(ns.index) do
        if rec and ns:IsItemDead(id) == false then
            local ok = true
            if next(filter.slot) and not filter.slot[locToGroup[rec.loc]] then ok = false end
            if ok and next(filter.kind) and not filter.kind[rec.classID .. ":" .. rec.subID] then ok = false end
            if ok and not SrcMatch(rec, filter.src) then ok = false end
            if ok and filter.mine and not ns:UsableByActive(rec) then ok = false end
            if ok then
                local name, link, quality, ilvl, req, _, _, _, _, icon = ns.GetItemInfoC(id)
                if not name then
                    pending = pending + 1
                    ns:RequestItem(id)
                else
                    local good = true
                    if HasQuality() and not filter.q[quality or 0] then good = false end
                    if good and minL and (req or 0) < minL then good = false end
                    if good and maxL and (req or 0) > maxL then good = false end
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
    if pending > 0 then
        Schedule(1.2)          -- 아이템 정보가 더 도착하면 갱신 (중지를 누를 때까지)
    else
        SetRunning(false)      -- 끝
    end
end

local function StartSearch()
    if not win then return end
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
function ns.OnItemInfo() end

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
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:Hide()
    tinsert(UISpecialFrames, "BestGearFinderSearchFrame")

    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText(L["아이템 검색"])
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

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
    nameBox:SetScript("OnTextChanged", function(self)
        local t = string.lower((self:GetText() or ""):match("^%s*(.-)%s*$"))
        filter.text = t
    end)

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

    -- 체크박스 묶음 (아무것도 안 고르면 전체)
    local checkLists = {}
    local y = -80
    local PER_ROW = 5
    local CELL = math.floor((W - 110) / PER_ROW)
    local function MakeChecks(title, entries, set, colorFn)
        local tl = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tl:SetPoint("TOPLEFT", 22, y - 6)
        tl:SetText(title)
        for idx, e in ipairs(entries) do
            local col, row = (idx - 1) % PER_ROW, math.floor((idx - 1) / PER_ROW)
            local cb = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
            cb:SetSize(22, 22)
            cb:SetPoint("TOPLEFT", 78 + col * CELL, y - row * 22)
            cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cb.label:SetPoint("LEFT", cb, "RIGHT", 0, 0)
            cb.label:SetWidth(CELL - 26)
            cb.label:SetJustifyH("LEFT")
            cb.label:SetWordWrap(false)
            cb.label:SetText(e.label)
            cb:SetScript("OnClick", function(self) set[e.key] = self:GetChecked() and true or nil end)
            checkLists[#checkLists + 1] = { cb = cb, set = set, key = e.key }
        end
        y = y - math.ceil(#entries / PER_ROW) * 22 - 6
    end

    local qEntries = {}
    for q = 1, 5 do qEntries[#qEntries + 1] = { key = q, label = QualityName(q) } end
    MakeChecks(L["등급"], qEntries, filter.q)

    local slotEntries = {}
    for _, g in ipairs(ns.GROUPS) do slotEntries[#slotEntries + 1] = { key = g.key, label = g.label } end
    MakeChecks(L["부위"], slotEntries, filter.slot)

    local armorEntries, weaponEntries = {}, {}
    for _, k in ipairs(ARMOR_KINDS) do armorEntries[#armorEntries + 1] = { key = k[1] .. ":" .. k[2], label = KindName(k[1], k[2]) } end
    for _, k in ipairs(WEAPON_KINDS) do weaponEntries[#weaponEntries + 1] = { key = k[1] .. ":" .. k[2], label = KindName(k[1], k[2]) } end
    MakeChecks(L["방어구"], armorEntries, filter.kind)
    MakeChecks(L["무기"], weaponEntries, filter.kind)

    MakeChecks(L["획득처"], {
        { key = "drop", label = L["드랍"] }, { key = "quest", label = L["퀘스트"] }, { key = "craft", label = L["제작"] },
        { key = "vendor", label = L["상점"] }, { key = "unknown", label = L["출처 불명"] },
    }, filter.src)

    -- 내 직업(보고 있는 직업)이 착용 가능한 것만
    mineChk = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
    mineChk:SetPoint("TOPLEFT", 16, y - 4)
    mineChk:SetSize(24, 24)
    local ml = mineChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ml:SetPoint("LEFT", mineChk, "RIGHT", 2, 0)
    ml:SetText(L["착용 가능한 아이템만"])
    mineChk:SetScript("OnClick", function(self) filter.mine = self:GetChecked() and true or false end)

    searchBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    searchBtn:SetSize(80, 22)
    searchBtn:SetPoint("TOPRIGHT", -108, y - 4)
    searchBtn:SetText(L["검색"])
    searchBtn:SetScript("OnClick", function()
        if running then StopSearch() else StartSearch() end
    end)

    local reset = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    reset:SetSize(80, 22)
    reset:SetPoint("TOPRIGHT", -24, y - 4)
    reset:SetText(L["초기화"])
    reset:SetScript("OnClick", function()
        StopSearch()
        filter.text, filter.mine = "", false
        for _, set in ipairs({ filter.q, filter.slot, filter.kind, filter.src }) do wipe(set) end
        nameBox:SetText(""); ns.SearchDefaultRange(); mineChk:SetChecked(false)
        for _, c in ipairs(checkLists) do c.cb:SetChecked(false) end
    end)
    y = y - 34

    countText = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOPLEFT", 22, y)
    noteText = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noteText:SetPoint("LEFT", countText, "RIGHT", 10, 0)

    local hint = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 22, 16)
    hint:SetText(L["Shift+클릭: 채팅창에 링크 / Ctrl+클릭: 미리보기"])

    local scroll = CreateFrame("ScrollFrame", "BestGearFinderSearchScroll", win, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, y - 18)
    scroll:SetPoint("BOTTOMRIGHT", -36, 34)
    listChild = CreateFrame("Frame", nil, scroll)
    listChild:SetSize(W - 70, 1)
    scroll:SetScrollChild(listChild)

    local function DefaultRange()
        local lo, hi = ns:GetRange()
        minBox:SetText(tostring(lo)); maxBox:SetText(tostring(hi))
    end
    ns.SearchDefaultRange = DefaultRange
    DefaultRange()
        win:SetScript("OnHide", function() StopSearch() end)
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
