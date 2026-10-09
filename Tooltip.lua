-- Best Gear Finder : 게임 아이템 툴팁(가방, 채팅 링크, 상인 창 등)에 획득처와 BiS 표시를 붙인다.
local ADDON, ns = ...
local L = ns.L

local MAX_LINES = 5

-- 애드온 창 안의 줄에서 띄운 툴팁은 이미 획득처를 따로 보여주므로 건너뛴다
function ns:SuppressItemTooltip(v) ns.tipSuppressed = v end

local function ItemIDFrom(tt, data)
    local id = data and data.id
    if type(id) == "number" then return id end
    if tt and tt.GetItem then
        local ok, _, link = pcall(tt.GetItem, tt)
        if ok and type(link) == "string" then
            local n = tonumber(link:match("item:(%d+)"))
            if n then return n end
        end
    end
end

local function Add(tt, id)
    if not ns.db or ns.db.itemTooltip == false then return end
    -- 애드온 창의 줄 툴팁(GameTooltip)만 건너뛴다. 옆에 뜨는 비교 툴팁(착용 중인 장비)에는 붙인다.
    if tt == GameTooltip then
        if ns.tipSuppressed then return end
        local okO, owner = pcall(tt.GetOwner, tt)
        if okO and type(owner) == "table" and owner.bgfRow then return end
    end
    if ns.indexState ~= "done" or not ns.index then return end
    local rec = ns.index[id]
    if not rec then
        -- 데이터에 없는 아이템: 신규 아이템 번호대(20만 이상)면 번호로 추정만 보여준다
        if id < 200000 then return end
        local est = ns:EstimateSource(id)
        if not est then return end
        tt:AddLine(" ")
        tt:AddLine("Best Gear Finder", 0.4, 0.8, 1)
        tt:AddLine(L["추정 획득처: "] .. est.long, 0.75, 0.75, 0.75, true)
        tt:AddLine(string.format(L["(번호가 가까운 아이템 #%d 기준%s)"], est.near, est.sure and L[", 앞뒤 모두 같은 곳"] or ""), 0.55, 0.55, 0.55, true)
        return
    end
    tt:AddLine(" ")
    tt:AddLine("Best Gear Finder", 0.4, 0.8, 1)
    -- BiS (지금 보고 있는 직업 기준)
    if ns.BisRank and ns.GetSpecList then
        for si, spec in ipairs(ns:GetSpecList()) do
            local r = ns:BisRank(si, id)
            if r == 2 then
                tt:AddLine("[BiS] " .. (spec.name or ""), 1, 0.82, 0)
            elseif r == 1 then
                tt:AddLine(L["BiS 대안: "] .. (spec.name or ""), 0.9, 0.8, 0.4)
            end
        end
    end
    local shown, total = 0, 0
    local craftShown = false
    for _, s in ipairs(rec.src) do
        total = total + 1
        if shown < MAX_LINES then
            shown = shown + 1
            local txt = ns:FormatSource(s)
            if s.kind == "craft" then
                tt:AddLine(txt, 0.4, 0.8, 1, true)
                if not craftShown then
                    craftShown = true
                    for _, ln in ipairs(ns:CraftDetailLines(id) or {}) do tt:AddLine(ln, 0.7, 0.85, 1, true) end
                end
            elseif s.kind == "quest" then tt:AddLine(txt, 1, 0.8, 0.3, true)
            elseif s.kind == "vendor" then tt:AddLine(txt, 0.6, 1, 0.6, true)
            else tt:AddLine(txt, 0.85, 0.85, 0.85, true) end
        end
    end
    if total > shown then tt:AddLine(string.format(L["... 외 %d곳"], total - shown), 0.6, 0.6, 0.6) end
    if total == 0 then tt:AddLine(L["획득처 정보 없음"], 0.6, 0.6, 0.6) end
    -- 출처 불명(신규)뿐이면 번호로 추정
    local onlyUnknown = total > 0
    for _, s in ipairs(rec.src) do if s.kind ~= "unknown" then onlyUnknown = false end end
    if onlyUnknown or total == 0 then
        local est = ns:EstimateSource(id)
        if est then
            tt:AddLine(L["추정 획득처: "] .. est.long, 0.75, 0.75, 0.75, true)
            tt:AddLine(string.format(L["(번호가 가까운 아이템 #%d 기준%s)"], est.near, est.sure and L[", 앞뒤 모두 같은 곳"] or ""), 0.55, 0.55, 0.55, true)
        end
    end
end

local errShown = false
local function OnItem(tt, data)
    local ok, err = pcall(function()
        local id = ItemIDFrom(tt, data)
        if id then Add(tt, id) end
    end)
    if not ok and not errShown and ns.db and ns.db.tipDebug then
        errShown = true
        print("|cff33ccffBest Gear Finder|r tooltip error: " .. tostring(err))
    end
    return ok
end

-- /bgf tip : 지금 마우스를 올린 아이템에 대해 툴팁 표시가 안 되는 이유를 알려준다
function ns:TooltipDiag()
    local P = function(t) print("|cff33ccffBGF tip|r " .. t) end
    P("TooltipDataProcessor=" .. tostring(TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and true or false)
        .. " option=" .. tostring(ns.db and ns.db.itemTooltip) .. " index=" .. tostring(ns.indexState))
    local ok, _, link = pcall(GameTooltip.GetItem, GameTooltip)
    local id = ok and type(link) == "string" and tonumber(link:match("item:(%d+)"))
    P("hover item=" .. tostring(id) .. " inData=" .. tostring(id and ns.index and ns.index[id] and true or false)
        .. " hookCalls=" .. tostring(ns.tipCalls or 0))
    ns.db.tipDebug = true
    errShown = false
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        ns.tipCalls = (ns.tipCalls or 0) + 1
        if tt == GameTooltip or tt == ItemRefTooltip or (tt and tt.GetName and tt:GetName() and tt:GetName():find("^ShoppingTooltip")) then
            OnItem(tt, data)
        end
    end)
else
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tt and tt.HookScript then tt:HookScript("OnTooltipSetItem", function(self) OnItem(self, nil) end) end
    end
end

-- 툴팁에 쓰려면 데이터를 미리 읽어 둔다 (로그인 몇 초 뒤, 전투 중이 아닐 때)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    C_Timer.After(5, function()
        if ns.db and ns.db.itemTooltip ~= false and not (InCombatLockdown and InCombatLockdown()) then
            ns:EnsureIndex()
        end
    end)
end)
ns._TooltipAdd = Add   -- 테스트용
