--[[
    Farseer - alerts
    One stack of reminder cards. Modules call Alerts:Set(key, info) while a
    condition holds and Alerts:Clear(key) when it is gone. Right-click a card
    to snooze it.
]]

local _, NS = ...
local UI = NS.UI

local Alerts = { active = {}, cards = {}, snoozed = {} }
NS.Alerts = Alerts

local CARD_W, CARD_H, GAP = 300, 44, 6

local anchor = CreateFrame("Frame", "FarseerHUDAlerts", UIParent)
anchor:SetSize(CARD_W, CARD_H)
Alerts.anchor = anchor

local function makeCard(i)
    local c = CreateFrame("Button", nil, anchor)
    c:SetSize(CARD_W, CARD_H)
    UI:Skin(c, UI.palette.surface, UI.palette.border, "lg")
    UI:Shadow(c)
    c.strip = c:CreateTexture(nil, "ARTWORK")
    c.strip:SetTexture(UI.WHITE)
    c.strip:SetPoint("TOPLEFT", 1, -9)
    c.strip:SetPoint("BOTTOMLEFT", 1, 9)
    c.strip:SetWidth(3)
    c.iconFrame = UI:Icon(c, CARD_H - 12)
    c.iconFrame:SetPoint("LEFT", 10, 0)
    c.title = UI:Text(c, 13)
    c.title:SetPoint("TOPLEFT", c.iconFrame, "TOPRIGHT", 10, -1)
    c.title:SetPoint("RIGHT", -8, 0)
    c.sub = UI:Text(c, 11, UI.palette.textDim)
    c.sub:SetPoint("BOTTOMLEFT", c.iconFrame, "BOTTOMRIGHT", 10, 1)
    c.sub:SetPoint("RIGHT", -8, 0)
    c:RegisterForClicks("RightButtonUp")
    c:SetScript("OnClick", function(self)
        if self.key then Alerts:Snooze(self.key) end
    end)
    c:Hide()
    Alerts.cards[i] = c
    return c
end

function Alerts:Layout()
    local list = {}
    for key, info in pairs(self.active) do
        local until_ = self.snoozed[key]
        if not until_ or GetTime() >= until_ then
            self.snoozed[key] = nil
            list[#list + 1] = info
        end
    end
    table.sort(list, function(a, b)
        if (a.priority or 0) ~= (b.priority or 0) then return (a.priority or 0) > (b.priority or 0) end
        return a.key < b.key
    end)
    for i = 1, math.max(#list, #self.cards) do
        local info = list[i]
        local c = self.cards[i] or (info and makeCard(i))
        if c then
            if info then
                local col = info.color or UI.palette.warn
                c.key = info.key
                c.strip:SetVertexColor(col[1], col[2], col[3], 1)
                c.iconFrame.icon:SetTexture(info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                c.title:SetText(info.title or "")
                c.sub:SetText(info.text or "")
                c:ClearAllPoints()
                c:SetPoint("TOP", anchor, "TOP", 0, -(i - 1) * (CARD_H + GAP))
                c:Show()
            else
                c.key = nil
                c:Hide()
            end
        end
    end
end

-- info: { title, text, icon, color, priority, sound }
function Alerts:Set(key, info)
    local old = self.active[key]
    info.key = key
    self.active[key] = info
    if not old and info.sound then UI:Sound(info.sound) end
    self:Layout()
end

function Alerts:Clear(key)
    if self.active[key] then
        self.active[key] = nil
        self:Layout()
    end
end

function Alerts:Snooze(key)
    local secs = NS.db and NS.db.reminders.snooze or 60
    self.snoozed[key] = GetTime() + secs
    self:Layout()
    C_Timer.After(secs + 0.1, function() Alerts:Layout() end)
end

function Alerts:Test()
    local r, g, b = UI:Accent()
    self:Set("test1", { title = "Alerts appear here", text = "Right-click a card to snooze it", icon = "Interface\\Icons\\Spell_Nature_LightningShield", color = { r, g, b }, priority = 9 })
    self:Set("test2", { title = "No Windfury on main hand", text = "Click the imbue button to apply", icon = "Interface\\Icons\\Spell_Nature_Cyclone", priority = 5, sound = "RAID_WARNING" })
    self:Set("test3", { title = "Searing Totem expired", text = "Fire slot is empty", icon = "Interface\\Icons\\Spell_Fire_SearingTotem", color = UI.palette.danger, priority = 1 })
    C_Timer.After(8, function()
        Alerts:Clear("test1"); Alerts:Clear("test2"); Alerts:Clear("test3")
    end)
end

NS:On("PLAYER_LOGIN", function()
    NS.Movers:Register(anchor, "alerts", "Alerts", { "TOP", "TOP", 0, -180 }, true)
end)

-- keep the anchor visible in edit mode so it can be placed
NS:On("SF_APPLIED", function()
    if NS.editing then
        if not next(Alerts.active) then Alerts:Set("edit", { title = "Alerts appear here", text = "Reminders stack from this point", icon = "Interface\\Icons\\Spell_Nature_LightningShield" }) end
    else
        Alerts:Clear("edit")
    end
end)
