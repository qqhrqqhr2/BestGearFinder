-- BestGearFinder : UI (역할별 칸을 가로로 나란히 표시)
local ADDON, ns = ...
local L = ns.L

local FRAME_H = 604
local MIN_FRAME_W = 480
local COL_MIN_W = 236
local SIDE_PAD = 56          -- 스크롤바/여백 합계
local ROW_H, HEADER_H = 36, 18

local rows, headers, colHeaders, dividers, hbtns = {}, {}, {}, {}, {}
local qualChk, menuChecks, chanceEdit = {}, {}, nil
local aucChk
local progress
local frame, scroll, child, status, perBtn, minEdit, maxEdit, upChk, craftChk, questChk, titleText
local nCols, colW, frameW = 1, 400, MIN_FRAME_W

local EN_CLASS = { WARRIOR="Warrior", PALADIN="Paladin", HUNTER="Hunter", ROGUE="Rogue", PRIEST="Priest", SHAMAN="Shaman", MAGE="Mage", WARLOCK="Warlock", DRUID="Druid" }
function ns:ClassLabel(class)
    if L["요구 레벨"] ~= "요구 레벨" and EN_CLASS[class] then return EN_CLASS[class] end
    local t = LOCALIZED_CLASS_NAMES_MALE
    if t and t[class] and class ~= select(2, UnitClass("player")) then return t[class] end
    return UnitClass("player")
end

-- 반투명 배경 대신 불투명한 단색 배경 (글씨가 잘 보이도록)
local function SolidBG(f)
    local t = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    t:SetColorTexture(0.04, 0.04, 0.06, 1)
    t:SetPoint("TOPLEFT", 3, -3)
    t:SetPoint("BOTTOMRIGHT", -3, 3)
    f.solidBG = t
end

local function Hex(c) return c and format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) or "|cffffffff" end

local function RoleColor(name)
    if name:find("탱") or name:find("Tank") then return 0.45, 0.7, 1 end
    if name:find("힐") or name:find("Heal") then return 0.4, 1, 0.5 end
    return 1, 0.6, 0.3
end

local function CreateRow(i)
    local r = CreateFrame("Button", nil, child)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(30, 30)
    r.icon:SetPoint("LEFT", 2, 0)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 4, -1)
    r.name:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
    r.sub:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.sub:SetJustifyH("LEFT")
    r.sub:SetWordWrap(false)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 1, 1, 0.08)
    r:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:AddLine(" ")
        if self.baseIlvl then
            GameTooltip:AddLine(L["현재 착용 장비 아이템 레벨: "] .. self.baseIlvl, 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine(L["현재 이 슬롯: 비어 있음"], 0.7, 0.7, 0.7)
        end
        if self.bis == 2 then
            GameTooltip:AddLine(L["레벨 30 BiS 목록의 1순위 아이템입니다. (wowf.io 기준)"], 1, 0.82, 0)
        elseif self.bis == 1 then
            GameTooltip:AddLine(L["레벨 30 BiS 목록에 있는 대안 아이템입니다. (wowf.io 기준)"], 0.9, 0.8, 0.4)
        end
        if self.weights and self.link and ns.StatDiffText then
            local okD, txt = pcall(ns.StatDiffText, self.link, self.baseLink, self.weights, 4)
            if okD and txt and txt ~= "" then
                GameTooltip:AddLine(format(L["현재 장비 대비: %s"], txt), 0.6, 0.8, 1, true)
            end
        end
        if self.score then
            GameTooltip:AddLine(format(L["추정 점수: 이 아이템 %.1f / 착용 중 %.1f"], self.score, self.baseScore or 0), 0.6, 0.9, 0.6)
        end
        local rec = self.rec
        if rec and #rec.src > 0 then
            GameTooltip:AddLine(L["획득처 (CMaNGOS)"], 1, 0.82, 0)
            local shown = 0
            for _, s in ipairs(rec.src) do
                if ns.SrcAllowed(s) then
                    shown = shown + 1
                    if shown > 6 then GameTooltip:AddLine("...", 0.7, 0.7, 0.7) break end
                    if s.kind == "craft" then
                        GameTooltip:AddLine(ns:FormatSource(s), 0.4, 0.8, 1)
                    elseif s.kind == "quest" then
                        GameTooltip:AddLine(ns:FormatSource(s), 1, 0.8, 0.3)
                    else
                        GameTooltip:AddLine(ns:FormatSource(s), 0.8, 0.8, 0.8)
                    end
                end
            end
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        if not self.link then return end
        if IsModifiedClick("CHATLINK") then
            local ins = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
            if ins then ins(self.link) end
        elseif IsModifiedClick("DRESSUP") then
            local dress = DressUpItemLink or (C_Item and C_Item.DressUpItemLink)
            if dress then dress(self.link) end
        end
    end)
    rows[i] = r
    return r
end

local function CreateHeader(i)
    local h = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h:SetJustifyH("LEFT")
    headers[i] = h
    return h
end

local function BuildFrame()
    local specs = ns:GetSpecList()
    nCols = #specs
    frameW = math.max(MIN_FRAME_W, SIDE_PAD + nCols * COL_MIN_W)
    colW = (frameW - SIDE_PAD) / nCols

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local function Tip(btn, title, text)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(title, 1, 1, 1)
            if text then GameTooltip:AddLine(text, 0.8, 0.8, 0.8, true) end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    frame = CreateFrame("Frame", "BestGearFinderFrame", UIParent, template)
    frame:SetSize(frameW, math.max(320, math.min(1000, (ns.db and ns.db.height) or FRAME_H)))
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    -- 화면보다 넓어지면 자동 축소
    local maxW = UIParent:GetWidth() * 0.96
    if maxW and maxW > 0 and frameW > maxW then frame:SetScale(maxW / frameW) end

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        ns.db.point = { p, rp, x, y }
    end)
    frame:SetScript("OnShow", function() ns:Refresh(true) end)
    frame:Hide()
    tinsert(UISpecialFrames, "BestGearFinderFrame")

    local pt = ns.db.point
    if pt then frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4]) else frame:SetPoint("CENTER") end

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleText:SetPoint("TOP", 0, -16)

    -- 필터 메뉴: 모든 필터를 한 곳에 모은 팝업
    local menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    menu:SetSize(232, 360)
    menu:SetFrameStrata("DIALOG")
    menu:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    SolidBG(menu)
    menu:Hide()
    local filterBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    filterBtn:SetSize(76, 22)
    filterBtn:SetPoint("TOPLEFT", 16, -34)
    filterBtn:SetText(L["필터 ▼"])
    filterBtn:SetScript("OnClick", function() if menu:IsShown() then menu:Hide() else menu:Show() end end)
    Tip(filterBtn, L["필터"], L["출처, 조건, 아이템 등급을 선택합니다."])
    menu:SetPoint("TOPLEFT", filterBtn, "BOTTOMLEFT", 0, -2)
    local my = -10
    local function Header(text)
        local h = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 12, my)
        h:SetText(text)
        my = my - 18
    end
    local function Check(label, key, tip, x, noAdvance)
        local cb = CreateFrame("CheckButton", nil, menu, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", x or 10, my + 2)
        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
        cb.text:SetText(label)
        cb.key = key
        cb:SetScript("OnClick", function(self)
            ns.db[self.key] = self:GetChecked() and true or false
            ns:Refresh(true)
        end)
        if tip then
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(label, 1, 1, 1)
                GameTooltip:AddLine(tip, 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        if not noAdvance then my = my - 22 end
        menuChecks[#menuChecks + 1] = cb
        return cb
    end
    Header(L["출처"])
    craftChk = Check(L["제작템 포함"], "crafting", L["전문기술로 만드는 장비를 포함합니다."])
    questChk = Check(L["퀘스트 보상"], "quests", L["퀘스트 보상을 포함합니다. (완료 여부와 상관없이 표시)"])
    aucChk = Check(L["월드 드랍 (저확률)"], "auction", L["던전이 아닌 월드의 여러 잡몹이 아주 낮은 확률로 떨어뜨리는 아이템을 포함합니다."])
    local ce = CreateFrame("EditBox", nil, menu, "InputBoxTemplate")
    ce:SetSize(40, 18)
    ce:SetPoint("TOPLEFT", 40, my + 1)
    ce:SetAutoFocus(false)
    ce:SetMaxLetters(5)
    ce:SetJustifyH("CENTER")
    local cl = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cl:SetPoint("LEFT", ce, "RIGHT", 4, 0)
    cl:SetText(L["% 미만은 월드 드랍으로 분류"])
    local function ApplyChance(self)
        local v = tonumber(self:GetText())
        if v then ns.db.minChance = math.max(0, math.min(100, v)) end
        self:ClearFocus()
        ns:Refresh(true)
    end
    ce:SetScript("OnEnterPressed", ApplyChance)
    ce:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    chanceEdit = ce
    my = my - 26
    Header(L["조건"])
    upChk = Check(L["업그레이드만"], "upgradeOnly", L["현재 착용 장비보다 점수가 높은 것만 보여줍니다."])
    Check(L["화면에 아이콘 표시"], "iconShown", L["게임 화면에 떠 있는 실행 아이콘을 보여줍니다. 드래그해서 옮길 수 있습니다."])
    Check(L["신규 아이템 포함 (출처 불명)"], "newItems", L["1.12 DB에 없는 Forever 신규 장비를 게임에서 직접 찾아 포함합니다. 어디서 나오는지는 알 수 없습니다."])
    Check(L["몹 레벨 제한 (범위+8)"], "mobCut", L["출처 몬스터의 레벨이 요구 레벨 상한+8을 넘으면 제외합니다."])
    Check(L["출처가 확인된 것만"], "sourcedOnly", L["던전·제작·퀘스트 등 획득처가 확인된 아이템만 보여줍니다. 출처를 알 수 없는 신규 아이템과 저확률 월드 드랍은 제외됩니다."])
    Check(L["다른 직업 전용 숨김"], "classFilter", L["툴팁에 직업 제한이 있고 내 직업이 아니면 제외합니다."])
    Header(L["등급"])
    local QUALS = {
        { 0, L["하급"], "|cff9d9d9d" }, { 1, L["일반"], "|cffffffff" }, { 2, L["고급"], "|cff1eff00" },
        { 3, L["희귀"], "|cff0070dd" }, { 4, L["영웅"], "|cffa335ee" }, { 5, L["전설"], "|cffff8000" },
    }
    for i, q in ipairs(QUALS) do
        local col = (i - 1) % 2
        local cb = CreateFrame("CheckButton", nil, menu, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("TOPLEFT", 10 + col * 100, my + 2)
        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
        cb.text:SetText(q[3] .. q[2] .. "|r")
        cb.q = q[1]
        cb:SetScript("OnClick", function(self)
            ns.db.qual[self.q] = self:GetChecked() and true or nil
            ns:Refresh(true)
        end)
        qualChk[i] = cb
        if col == 1 then my = my - 22 end
    end
    menu:SetHeight(-my + 14)

    -- 후원 버튼 (상단)
    local donateBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    donateBtn:SetSize(84, 20)
    donateBtn:SetPoint("TOPRIGHT", -40, -36)
    donateBtn:SetText(L["후원"])
    donateBtn:SetScript("OnClick", function() ns:ShowDonate() end)
    Tip(donateBtn, L["후원"], L["애드온이 마음에 드셨다면 후원 링크를 복사할 수 있습니다."])

    -- 슬롯당 개수 드롭다운 (2~10)
    perBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    perBtn:SetSize(112, 20)
    perBtn:SetPoint("RIGHT", donateBtn, "LEFT", -6, 0)
    local perMenu = CreateFrame("Frame", nil, frame, template)
    perMenu:SetFrameStrata("DIALOG")
    perMenu:SetSize(112, 9 * 20 + 16)
    perMenu:SetPoint("TOPRIGHT", perBtn, "BOTTOMRIGHT", 0, -2)
    perMenu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    SolidBG(perMenu)
    perMenu:Hide()
    for n = 2, 10 do
        local b = CreateFrame("Button", nil, perMenu)
        b:SetSize(102, 20)
        b:SetPoint("TOPLEFT", 5, -8 - (n - 2) * 20)
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("CENTER")
        t:SetText(n)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        b:SetScript("OnClick", function()
            ns.db.perSlot = n
            perMenu:Hide()
            ns:Refresh(true)
        end)
    end
    Tip(perBtn, L["슬롯당 표시 개수"], L["각 슬롯마다 보여줄 아이템 수를 2~10개 중에서 고릅니다."])
    perBtn:SetScript("OnClick", function()
        if perMenu:IsShown() then perMenu:Hide() else perMenu:Show() end
    end)
    frame:HookScript("OnHide", function() perMenu:Hide() end)

    -- 언어 드롭다운 (자동 / 한국어 / English) — 선택하면 UI를 다시 불러옵니다
    -- 직업 보기 (기본: 내 캐릭터, 드롭다운으로 다른 직업 선택 → 보기 전용)
    local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
    local classBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    classBtn:SetSize(110, 20)
    local langBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    langBtn:SetSize(96, 20)
    langBtn:SetPoint("RIGHT", perBtn, "LEFT", -6, 0)
    langBtn:SetText(L["언어"] .. " ▼")
    local langMenu = CreateFrame("Frame", nil, frame, template)
    langMenu:SetFrameStrata("DIALOG")
    langMenu:SetSize(96, 3 * 20 + 16)
    langMenu:SetPoint("TOPRIGHT", langBtn, "BOTTOMRIGHT", 0, -2)
    langMenu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    SolidBG(langMenu)
    langMenu:Hide()
    local langOpts = { { nil, "Auto" }, { "ko", "한국어" }, { "en", "English" } }
    for i, o in ipairs(langOpts) do
        local b = CreateFrame("Button", nil, langMenu)
        b:SetSize(86, 20)
        b:SetPoint("TOPLEFT", 5, -8 - (i - 1) * 20)
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("CENTER")
        t:SetText(o[2])
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        b:SetScript("OnClick", function()
            langMenu:Hide()
            ns.db.lang = o[1]
            if ns.SetLang then ns.SetLang(o[1]) end
            if ns.RelabelData then ns.RelabelData() end
            ns:RebuildUI()
        end)
    end
    Tip(langBtn, L["언어"], L["표시 언어를 고릅니다. 고르면 창이 바로 새로 열립니다."])
    langBtn:SetScript("OnClick", function()
        if langMenu:IsShown() then langMenu:Hide() else langMenu:Show() end
    end)
    frame:HookScript("OnHide", function() langMenu:Hide() end)

    classBtn:SetPoint("RIGHT", langBtn, "LEFT", -6, 0)
    classBtn:SetText((ns.viewClass and ns:ClassLabel(ns.viewClass) or L["내 캐릭터"]) .. " ▼")
    local classMenu = CreateFrame("Frame", nil, frame, template)
    classMenu:SetFrameStrata("DIALOG")
    classMenu:SetSize(120, (#CLASS_ORDER + 1) * 20 + 16)
    classMenu:SetPoint("TOPRIGHT", classBtn, "BOTTOMRIGHT", 0, -2)
    classMenu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    SolidBG(classMenu)
    classMenu:Hide()
    local opts = { { nil, L["내 캐릭터"] } }
    for _, cls in ipairs(CLASS_ORDER) do opts[#opts + 1] = { cls, ns:ClassLabel(cls) } end
    for i, o in ipairs(opts) do
        local b = CreateFrame("Button", nil, classMenu)
        b:SetSize(110, 20)
        b:SetPoint("TOPLEFT", 5, -8 - (i - 1) * 20)
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("CENTER")
        t:SetText(o[2])
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        b:SetScript("OnClick", function()
            classMenu:Hide()
            ns:SetViewClass(o[1])
            ns:RebuildUI()
        end)
    end
    Tip(classBtn, L["직업 보기"], L["다른 직업의 추천 장비를 봅니다. 이때는 내 장비와 비교하지 않는 보기 전용입니다. '내 캐릭터'를 고르면 돌아갑니다."])
    classBtn:SetScript("OnClick", function()
        langMenu:Hide()
        if classMenu:IsShown() then classMenu:Hide() else classMenu:Show() end
    end)
    langBtn:HookScript("OnClick", function() classMenu:Hide() end)
    frame:HookScript("OnHide", function() classMenu:Hide() end)

    -- 요구 레벨 범위 입력 줄
    local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 20, -66)
    lbl:SetText(L["요구 레벨"])

    local function MakeEdit(anchor, dx)
        local e = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        e:SetSize(34, 20)
        e:SetPoint("LEFT", anchor, "RIGHT", dx, 0)
        e:SetAutoFocus(false)
        e:SetNumeric(true)
        e:SetMaxLetters(2)
        e:SetJustifyH("CENTER")
        e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        return e
    end
    minEdit = MakeEdit(lbl, 20)
    local tilde = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tilde:SetPoint("LEFT", minEdit, "RIGHT", 4, 0)
    tilde:SetText("~")
    maxEdit = MakeEdit(tilde, 8)

    local function Apply()
        ns:SetRange(minEdit:GetText(), maxEdit:GetText())
        minEdit:ClearFocus()
        maxEdit:ClearFocus()
        ns:ForceRefresh()
    end
    minEdit:SetScript("OnEnterPressed", Apply)
    maxEdit:SetScript("OnEnterPressed", Apply)
    minEdit:SetScript("OnTabPressed", function() maxEdit:SetFocus() end)
    maxEdit:SetScript("OnTabPressed", function() minEdit:SetFocus() end)

    local searchBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    searchBtn:SetSize(64, 22)
    searchBtn:SetPoint("LEFT", maxEdit, "RIGHT", 8, 0)
    searchBtn:SetText(L["검색"])
    searchBtn:SetScript("OnClick", Apply)
    searchBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["검색 / 새로고침"], 1, 1, 1)
        GameTooltip:AddLine(L["입력한 요구 레벨 범위로, 현재 착용 중인 장비 기준으로 다시 계산합니다."], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    searchBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local autoBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    autoBtn:SetSize(86, 22)
    autoBtn:SetPoint("LEFT", searchBtn, "RIGHT", 4, 0)
    autoBtn:SetText(L["자동(현재-10)"])
    autoBtn:SetScript("OnClick", function()
        ns:ClearRange()
        ns:ForceRefresh()
    end)
    autoBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L["자동 범위"], 1, 1, 1)
        GameTooltip:AddLine(L["현재 레벨 -10 ~ 현재 레벨로 되돌립니다. 레벨업하면 같이 올라갑니다."], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    autoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 아이템 검색 (이름 / 보스 / 던전)
    local sBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    sBox:SetSize(150, 20)
    sBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -46, -64)
    sBox:SetAutoFocus(false)
    sBox:SetMaxLetters(40)
    sBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    sBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local sHint = sBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sHint:SetPoint("LEFT", sBox, "LEFT", 2, 0)
    sHint:SetText(L["아이템/보스 검색"])
    local sTimer
    sBox:SetScript("OnTextChanged", function(self)
        local t = strtrim(self:GetText() or ""):lower()
        sHint:SetShown(t == "" and not self:HasFocus())
        if t == ns.searchText then return end
        ns.searchText = t
        if sTimer then sTimer:Cancel() end
        sTimer = C_Timer.NewTimer(0.3, function() ns:Refresh() end)
    end)
    sBox:SetScript("OnEditFocusGained", function() sHint:Hide() end)
    sBox:SetScript("OnEditFocusLost", function(self) sHint:SetShown((self:GetText() or "") == "") end)

    -- 역할 칸 머리글 (스크롤 밖에 고정)
    for i, spec in ipairs(specs) do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", 18 + (i - 1) * colW + 4, -92)
        fs:SetWidth(colW - 8)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetTextColor(RoleColor(spec.name))
        fs:SetText(spec.name)
        colHeaders[i] = fs
    end
    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.25)
    line:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -110)
    line:SetSize(colW * nCols, 1)

    -- 스크롤 영역
    scroll = CreateFrame("ScrollFrame", "BestGearFinderScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -114)
    scroll:SetPoint("BOTTOMRIGHT", -36, 38)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(colW * nCols, 10)
    scroll:SetScrollChild(child)

    for i = 1, nCols - 1 do
        local d = child:CreateTexture(nil, "BACKGROUND")
        d:SetColorTexture(1, 1, 1, 0.12)
        d:SetWidth(1)
        dividers[i] = d
    end

    status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("BOTTOMLEFT", 20, 18)
    status:SetPoint("BOTTOMRIGHT", -20, 18)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(false)

    -- 하단 진행 막대 (데이터를 불러오는 동안만 표시)
    progress = CreateFrame("StatusBar", nil, frame)
    progress:SetPoint("BOTTOMLEFT", 20, 9)
    progress:SetPoint("BOTTOMRIGHT", -40, 9)
    progress:SetHeight(6)
    progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progress:SetStatusBarColor(0.2, 0.75, 0.3)
    progress:SetMinMaxValues(0, 1)
    local pbg = progress:CreateTexture(nil, "BACKGROUND")
    pbg:SetAllPoints()
    pbg:SetColorTexture(0, 0, 0, 0.6)
    progress:Hide()

    local statusBtn = CreateFrame("Button", nil, frame)
    statusBtn:SetPoint("BOTTOMLEFT", 20, 14)
    statusBtn:SetPoint("BOTTOMRIGHT", -40, 14)
    statusBtn:SetHeight(18)
    statusBtn:SetScript("OnEnter", function(btn)
        local st = ns.stats
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:AddLine(L["아이템 현황"], 1, 1, 1)
        GameTooltip:AddLine(format(L["조건에 맞는 후보: %d개"], st.candidates), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(format(L["게임에서 확인된 아이템: %d개"], st.ready), 0.6, 0.9, 0.6)
        if st.pending + (st.skipped or 0) > 0 then
            GameTooltip:AddLine(format(L["확인되지 않은 아이템: %d개 (게임에 없는 아이템이면 계속 확인되지 않습니다)"], st.pending + (st.skipped or 0)), 1, 0.82, 0, true)
        end
        GameTooltip:AddLine(L["점수는 직업·역할별 스탯 가중치로 계산한 추정치입니다."], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    statusBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 창 높이 조절 (오른쪽 아래 모서리를 드래그)
    pcall(function()
        frame:SetResizable(true)
        if frame.SetResizeBounds then frame:SetResizeBounds(frameW, 320, frameW, 1000)
        elseif frame.SetMinResize then frame:SetMinResize(frameW, 320) frame:SetMaxResize(frameW, 1000) end
    end)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -8, 8)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOM") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        ns.db.height = math.floor(frame:GetHeight())
    end)
    grip:SetScript("OnEnter", function(g)
        GameTooltip:SetOwner(g, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["드래그해서 창 높이를 조절합니다."], 1, 1, 1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ns.frame = frame
end

local function HideAll()
    for _, b in ipairs(hbtns) do b:Hide() end
    for _, r in ipairs(rows) do r:Hide() end
    for _, h in ipairs(headers) do h:Hide() end
    for _, d in ipairs(dividers) do d:Hide() end
end

local function ShowMessage(text)
    HideAll()
    local h = headers[1] or CreateHeader(1)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -8)
    h:SetWidth(math.min(colW * nCols - 8, 420))
    h:SetWordWrap(true)
    h:SetTextColor(1, 0.82, 0)
    h:SetText(text)
    h:Show()
    child:SetHeight(120)
end

local function SetProgress(frac)
    if not progress then return end
    if frac == nil then progress:Hide(); return end
    progress:SetValue(math.max(0, math.min(1, frac)))
    progress:Show()
end

function ns:UpdateProgress()
    if status and self.indexState == "running" then
        if self.indexStats.scanned then
            SetProgress(self.indexStats.scanned / 400000)
        else
            SetProgress(nil)
        end
        status:SetText("")
    end
end

function ns:UpdateUI()
    if not frame then return end
    if ns.UpdateLauncher then ns:UpdateLauncher() end
    local class = ns:ActiveClass()
    titleText:SetText(format("Best Gear Finder  %s%s|r  Lv.%d", Hex(RAID_CLASS_COLORS[class]), (ns.ClassLabel and ns:ClassLabel(class)) or ns:ActiveClassName() or "", UnitLevel("player")))
    perBtn:SetText(L["슬롯당 "] .. self.db.perSlot .. L["개"] .. " ▼")
    local lo, hi, isAuto = self:GetRange()
    if not minEdit:HasFocus() then minEdit:SetText(tostring(lo)) end
    if not maxEdit:HasFocus() then maxEdit:SetText(tostring(hi)) end
    for _, cb in ipairs(menuChecks) do cb:SetChecked(self.db[cb.key] and true or false) end
    if chanceEdit and not chanceEdit:HasFocus() then chanceEdit:SetText(tostring(self.db.minChance or 0)) end
    for _, cb in ipairs(qualChk) do cb:SetChecked(self.db.qual[cb.q] and true or false) end

    SetProgress(nil)
    local state = self.indexState
    if self.lastError and state == "done" then
        ShowMessage(L["계산 중 오류가 발생했습니다.\n\n"] .. tostring(self.lastError):sub(1, 400) .. L["\n\n(채팅창에도 출력됩니다. 이 내용을 알려주세요)"])
        status:SetText("")
        return
    end
    if state == "idle" or state == "running" then
        ShowMessage(L["아이템 정보를 불러오는 중입니다..."])
        self:UpdateProgress()
        return
    elseif state == "empty" then
        ShowMessage(L["CMaNGOS에서 장비 드랍 데이터를 읽지 못했습니다.\n\ntools/extract_cmnangos.py 실행 결과와\n/bgf 진단 내용을 확인해 주세요."])
        status:SetText("")
        return
    end

    HideAll()
    local function Visible(list)
        if not list or not self.db.upgradeOnly or (ns.searchText or "") ~= "" then return list end
        local out = {}
        for _, e in ipairs(list) do if e.upgrade then out[#out + 1] = e end end
        return #out > 0 and out or nil
    end
    local drawBands = {}
    for _, band in ipairs(self.bands) do
        local cnt = 0
        for si = 1, nCols do
            local l = Visible(self.views[si] and self.views[si][band.group.key])
            if l and #l > cnt then cnt = #l end
        end
        if cnt > 0 then drawBands[#drawBands + 1] = { group = band.group, count = cnt } end
    end
    local y, hdrN, ri = 0, 0, 0
    for _, band in ipairs(drawBands) do
        hdrN = hdrN + 1
        local h = headers[hdrN] or CreateHeader(hdrN)
        h:SetWordWrap(false)
        h:SetTextColor(0.4, 0.8, 1)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -y - 2)
        h:SetWidth(colW * nCols - 8)
        local collapsed = self.db.collapsed and self.db.collapsed[band.group.key]
        h:SetText((collapsed and "+ " or "- ") .. band.group.label)
        h:Show()
        local hb = hbtns[hdrN]
        if not hb then
            hb = CreateFrame("Button", nil, child)
            hb:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            hb:SetScript("OnClick", function(btn)
                local d = ns.db
                d.collapsed = d.collapsed or {}
                d.collapsed[btn.key] = (not d.collapsed[btn.key]) or nil
                ns:UpdateUI()
            end)
            hb:SetScript("OnEnter", function(btn)
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["클릭하면 이 슬롯을 접거나 펼칩니다."], 1, 1, 1)
                GameTooltip:Show()
            end)
            hb:SetScript("OnLeave", function() GameTooltip:Hide() end)
            hbtns[hdrN] = hb
        end
        hb.key = band.group.key
        hb:ClearAllPoints()
        hb:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -y)
        hb:SetSize(colW * nCols - 4, HEADER_H)
        hb:Show()
        y = y + HEADER_H
        if collapsed then y = y + 4 else
        for si = 1, nCols do
            local list = Visible(self.views[si] and self.views[si][band.group.key])
            if list then
                for n, e in ipairs(list) do
                    ri = ri + 1
                    local r = rows[ri] or CreateRow(ri)
                    r:SetSize(colW - 6, ROW_H)
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", child, "TOPLEFT", (si - 1) * colW + 2, -(y + (n - 1) * ROW_H))
                    r.link, r.rec, r.baseIlvl, r.score, r.baseScore, r.bis = e.link, e.rec, e.baseIlvl, e.score, e.baseScore, e.bis
                    r.baseLink, r.weights = e.baseLink, e.weights
                    r.icon:SetTexture(e.rec.icon)
                    local mark = e.upgrade and "|cff40ff40▲|r " or ""
                    if e.bis == 2 then mark = "|cffffd100[BiS]|r " .. mark end
                    local ps = self:PrimarySource(e.rec)
                    if ps and ps.kind == "unknown" then mark = mark .. L["|cffff80ff[신규]|r "] end
                    if ps and ps.kind == "craft" then mark = mark .. L["|cff66ccff[제작]|r "] end
                    if ps and ps.kind == "quest" then mark = mark .. L["|cffffcc33[퀘스트]|r "] end
                    if ps and ps.kind == "vendor" then mark = mark .. L["|cff99ff99[상인]|r "] end
                    r.name:SetText(mark .. e.link)
                    if (e.req or 0) > 0 then
                        r.sub:SetText(format(L["|cffffd100%d|r |cffaaaaaa· 요구 %d · %s|r"], e.ilvl, e.req,
                            self:ShortSource(e.rec)))
                    else
                        r.sub:SetText(format(L["|cffffd100%d|r |cffaaaaaa· 요구 없음 · %s|r"], e.ilvl,
                            self:ShortSource(e.rec)))
                    end
                    r:Show()
                end
            end
        end
        y = y + band.count * ROW_H + 6
        end
    end
    child:SetHeight(math.max(y, 10))
    -- 스크롤 범위를 즉시 다시 계산 (슬롯당 개수를 바꿔 높이가 커져도 끝까지 스크롤되도록)
    if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    C_Timer.After(0, function()
        if scroll and scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        local range = scroll and scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange()
        if range and scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
    end)
    for i, d in ipairs(dividers) do
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", child, "TOPLEFT", i * colW, 0)
        d:SetHeight(math.max(y, 10))
        d:Show()
    end

    if #drawBands == 0 then
        local msg = self.stats.pending > 0 and L["아이템 정보를 불러오는 중입니다..."] or
            (self.db.upgradeOnly and L["현재 조건에서 업그레이드할 아이템이 없습니다.\n('업그레이드만' 체크를 풀거나 요구 레벨 범위를 넓혀보세요)"] or L["추천할 아이템이 없습니다."])
        ShowMessage(msg)
    end

    local s = self.stats
    if (self.itemErrors or 0) > 0 then
        status:SetText(format(L["일부 아이템 처리 오류 %d건 (/bgf 진단)"], self.itemErrors))
        return
    end
    local pend = ""
    if s.pending > 0 then
        SetProgress(s.ready / math.max(1, s.ready + s.pending))
        pend = format(L[" · %d개 불러오는 중"], s.pending)
    elseif (s.skipped or 0) > 0 then
        pend = format(L[" · 게임에 없는 %d개 제외"], s.skipped)
    end
    status:SetText(format(L["요구 레벨 %d~%d%s · 확인된 아이템 %d개%s · 점수는 추정치"], lo, hi, isAuto and L["(자동)"] or "", s.ready, pend))
end

-- 언어를 바꾼 뒤 창을 새로 만든다 (/reload 불필요)
function ns:RebuildUI()
    if not frame then return end
    local wasShown = frame:IsShown()
    frame:Hide()
    frame:ClearAllPoints()
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "BestGearFinderFrame" then table.remove(UISpecialFrames, i) end
    end
    wipe(rows) wipe(headers) wipe(colHeaders) wipe(dividers) wipe(qualChk) wipe(menuChecks) wipe(hbtns)
    chanceEdit, aucChk, frame, ns.frame = nil, nil, nil, nil
    BuildFrame()
    if wasShown then frame:Show() end
end

function ns:Toggle()
    if not frame then
        if not self.db then return end
        BuildFrame()
    end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
