-- Best Gear Finder : 화면 위에 떠 있는 실행 아이콘 (드래그로 이동, 클릭으로 열기/닫기)
local ADDON, ns = ...
local L = ns.L

local ICON = "Interface\\AddOns\\BestGearFinder\\Media\\icon"
local SIZE = 40
local btn

local function SavePosition(self)
    local point, _, relPoint, x, y = self:GetPoint()
    ns.db.iconPos = { point, relPoint, x, y }
end

local function ApplyPosition()
    btn:ClearAllPoints()
    local p = ns.db.iconPos
    if p and p[1] then
        btn:SetPoint(p[1], UIParent, p[2] or p[1], p[3] or 0, p[4] or 0)
    else
        btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -200)   -- 기본 위치: 화면 왼쪽 위
    end
end

local function Build()
    btn = CreateFrame("Button", "BestGearFinderLauncher", UIParent)
    btn:SetSize(SIZE, SIZE)
    btn:SetFrameStrata("MEDIUM")
    btn:SetClampedToScreen(true)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.icon:SetTexture(ICON)

    btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.hl:SetAllPoints()
    btn.hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    btn.hl:SetBlendMode("ADD")

    btn:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self.dragging = true
        GameTooltip:Hide()
        self:StartMoving()
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.dragging = false
        SavePosition(self)
    end)
    btn:SetScript("OnClick", function(self, button)
        if self.dragging then return end
        ns:Toggle()
    end)
    btn:SetScript("OnEnter", function(self)
        if self.dragging then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Best Gear Finder", 1, 0.82, 0)
        GameTooltip:AddLine(L["클릭: 열기 / 닫기"], 1, 1, 1)
        GameTooltip:AddLine(L["드래그: 아이콘 옮기기"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["/bgf icon : 아이콘 숨기기 / 보이기"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- 설정(ns.db.iconShown)과 저장된 위치를 반영한다.
function ns:UpdateLauncher()
    if not self.db then return end
    if not btn then
        Build()
        ApplyPosition()          -- 위치는 처음 만들 때와 초기화할 때만 적용 (드래그 중 덮어쓰지 않도록)
    end
    if self.db.iconShown then btn:Show() else btn:Hide() end
end

function ns:ResetLauncher()
    if not self.db then return end
    self.db.iconPos = nil
    if btn then ApplyPosition() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() ns:UpdateLauncher() end)
