-- Best Gear Finder : 아이템 검색 창 (별도 팝업)
-- 이름/보스, 등급, 요구 레벨, 부위, 방어구·무기 종류, 획득처로 전체 아이템 데이터를 검색한다.
local ADDON, ns = ...
local L = ns.L

local W, H = 640, 560
local ROW_H, MAX_ROWS = 22, 150
local win, listChild, countText, noteText, nameBox, minBox, maxBox, mineChk
local rows = {}
local filter = { text = "", quality = nil, slot = nil, kind = nil, src = nil, mine = false }
local dropdowns = {}
local timer, polling = nil, false
local token = 0

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
-- 드롭다운 (현재 값 버튼 + 팝업 메뉴)
------------------------------------------------------------------------
local function MakeDropdown(parent, x, y, width, title, getOptions, onPick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 22)
    btn:SetPoint("TOPLEFT", x, y)
    local menu = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    if ns.SolidBG then ns.SolidBG(menu) end
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    menu:Hide()
    local items = {}
    local d = { btn = btn, menu = menu }
    function d.Refresh()
        local opts = getOptions()
        local shown = 0
        for i, o in ipairs(opts) do
            local b = items[i]
            if not b then
                b = CreateFrame("Button", nil, menu)
                b:SetHeight(20)
                b.t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                b.t:SetPoint("LEFT", 6, 0)
                b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                items[i] = b
            end
            b:SetPoint("TOPLEFT", 5, -8 - (i - 1) * 20)
            b:SetWidth(math.max(width, 150) - 10)
            b.t:SetText(o.label)
            b:SetScript("OnClick", function()
                menu:Hide()
                onPick(o.value)
                d.Refresh()
            end)
            b:Show()
            shown = i
            if o.selected then btn:SetText(title .. ": " .. o.label .. " ▼") end
        end
        for i = shown + 1, #items do items[i]:Hide() end
        menu:SetSize(math.max(width, 150), shown * 20 + 16)
    end
    btn:SetScript("OnClick", function()
        for _, o in ipairs(dropdowns) do if o ~= d then o.menu:Hide() end end
        if menu:IsShown() then menu:Hide() else d.Refresh(); menu:Show() end
    end)
    dropdowns[#dropdowns + 1] = d
    d.Refresh()
    return d
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

local function SrcMatch(rec, src)
    if not src then return true end
    if src == "unknown" then return rec.new or rec.kinds.unknown or next(rec.kinds) == nil end
    return rec.kinds[src] and true or false
end

local function HasFilter(minL, maxL)
    return filter.text ~= "" or filter.quality or filter.slot or filter.kind or filter.src or minL or maxL
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
    if not win or not win:IsShown() then return end
    for _, r in ipairs(rows) do r:Hide() end
    if ns.indexState ~= "done" then
        ns:EnsureIndex()
        countText:SetText("")
        noteText:SetText(L["아이템 정보를 불러오는 중입니다..."])
        if not polling then
            polling = true
            C_Timer.After(1, function() polling = false; Run() end)
        end
        return
    end
    local minL, maxL = tonumber(minBox:GetText()), tonumber(maxBox:GetText())
    if not HasFilter(minL, maxL) then
        countText:SetText("")
        noteText:SetText(L["조건을 고르면 해당하는 아이템이 모두 표시됩니다."])
        return
    end
    local text = filter.text
    local pending, results = 0, {}
    for id, rec in pairs(ns.index) do
        if rec and ns:IsItemDead(id) == false then
            local ok = true
            if filter.slot and locToGroup[rec.loc] ~= filter.slot then ok = false end
            if ok and filter.kind and (rec.classID .. ":" .. rec.subID) ~= filter.kind then ok = false end
            if ok and not SrcMatch(rec, filter.src) then ok = false end
            if ok and filter.mine and not ns:UsableByActive(rec) then ok = false end
            if ok then
                local name, link, quality, ilvl, req, _, _, _, _, icon = ns.GetItemInfoC(id)
                if not name then
                    pending = pending + 1
                    ns:RequestItem(id)
                else
                    local good = true
                    if filter.quality and (quality or 0) < filter.quality then good = false end
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
end

-- 아이템 정보가 도착하면 (검색창이 열려 있고 불러오는 중일 때) 조금 뒤에 다시 검색
function ns.OnItemInfo()
    if win and win:IsShown() and not timer and noteText and noteText:GetText() and noteText:GetText():find("%.%.%.") then
        Schedule(1.2)
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
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Schedule(0.01) end)
    nameBox:SetScript("OnTextChanged", function(self)
        local t = string.lower((self:GetText() or ""):match("^%s*(.-)%s*$"))
        if t ~= filter.text then filter.text = t; Schedule(0.35) end
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
        e:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Schedule(0.01) end)
        e:SetScript("OnTextChanged", function() Schedule(0.5) end)
        return e
    end
    minBox = LevelEdit(ll, 14)
    local tl = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tl:SetPoint("LEFT", minBox, "RIGHT", 4, 0)
    tl:SetText("~")
    maxBox = LevelEdit(tl, 8)

    -- 드롭다운: 등급 / 부위 / 종류 / 획득처
    MakeDropdown(win, 20, -80, 140, L["등급"], function()
        local o = { { label = L["전체"], value = nil, selected = filter.quality == nil } }
        for q = 1, 5 do o[#o + 1] = { label = QualityName(q) .. " " .. L["이상"], value = q, selected = filter.quality == q } end
        return o
    end, function(v) filter.quality = v; Schedule(0.05) end)

    MakeDropdown(win, 166, -80, 140, L["부위"], function()
        local o = { { label = L["전체"], value = nil, selected = filter.slot == nil } }
        for _, g in ipairs(ns.GROUPS) do o[#o + 1] = { label = g.label, value = g.key, selected = filter.slot == g.key } end
        return o
    end, function(v) filter.slot = v; Schedule(0.05) end)

    MakeDropdown(win, 312, -80, 170, L["종류"], function()
        local o = { { label = L["전체"], value = nil, selected = filter.kind == nil } }
        for _, k in ipairs(ARMOR_KINDS) do
            local key = k[1] .. ":" .. k[2]
            o[#o + 1] = { label = KindName(k[1], k[2]), value = key, selected = filter.kind == key }
        end
        for _, k in ipairs(WEAPON_KINDS) do
            local key = k[1] .. ":" .. k[2]
            o[#o + 1] = { label = KindName(k[1], k[2]), value = key, selected = filter.kind == key }
        end
        return o
    end, function(v) filter.kind = v; Schedule(0.05) end)

    MakeDropdown(win, 488, -80, 130, L["획득처"], function()
        local list = { { nil, L["전체"] }, { "drop", L["드랍"] }, { "quest", L["퀘스트"] }, { "craft", L["제작"] },
                       { "vendor", L["상점"] }, { "unknown", L["출처 불명"] } }
        local o = {}
        for _, e in ipairs(list) do o[#o + 1] = { label = e[2], value = e[1], selected = filter.src == e[1] } end
        return o
    end, function(v) filter.src = v; Schedule(0.05) end)

    -- 내 직업(보고 있는 직업)이 착용 가능한 것만
    mineChk = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
    mineChk:SetPoint("TOPLEFT", 16, -108)
    mineChk:SetSize(24, 24)
    local ml = mineChk:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ml:SetPoint("LEFT", mineChk, "RIGHT", 2, 0)
    ml:SetText(L["착용 가능한 아이템만"])
    mineChk:SetScript("OnClick", function(self) filter.mine = self:GetChecked() and true or false; Schedule(0.05) end)

    local reset = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    reset:SetSize(80, 22)
    reset:SetPoint("TOPRIGHT", -24, -108)
    reset:SetText(L["초기화"])
    reset:SetScript("OnClick", function()
        filter.text, filter.quality, filter.slot, filter.kind, filter.src, filter.mine = "", nil, nil, nil, nil, false
        nameBox:SetText(""); ns.SearchDefaultRange(); mineChk:SetChecked(false)
        for _, d in ipairs(dropdowns) do d.Refresh() end
        Schedule(0.05)
    end)

    countText = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOPLEFT", 22, -140)
    noteText = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    noteText:SetPoint("LEFT", countText, "RIGHT", 10, 0)

    local hint = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 22, 16)
    hint:SetText(L["Shift+클릭: 채팅창에 링크 / Ctrl+클릭: 미리보기"])

    local scroll = CreateFrame("ScrollFrame", "BestGearFinderSearchScroll", win, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -158)
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
    win:SetScript("OnShow", function() for _, d in ipairs(dropdowns) do d.Refresh() end; Run() end)
    win:SetScript("OnHide", function() for _, d in ipairs(dropdowns) do d.menu:Hide() end end)
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
    Schedule(0.01)
end
