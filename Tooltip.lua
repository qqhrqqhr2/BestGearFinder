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
    if ns.tipSuppressed or not ns.db or ns.db.itemTooltip == false then return end
    local okO, owner = pcall(tt.GetOwner, tt)
    if okO and type(owner) == "table" and owner.bgfRow then return end
    if ns.indexState ~= "done" or not ns.index then return end
    local rec = ns.index[id]
    if not rec then return end
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
end

local function OnItem(tt, data)
    local ok = pcall(function()
        local id = ItemIDFrom(tt, data)
        if id then Add(tt, id) end
    end)
    return ok
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
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
