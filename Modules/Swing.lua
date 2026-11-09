--[[
    ShammyForever - swing timer
    Main hand and off hand bars driven by Forever's native swing events
    (PLAYER_SWING carries the swing duration and which hand swung), so it is
    exact without the combat log. Casts are projected onto the main hand bar
    and turn red when they run past the next swing. The bar greys out when
    the target leaves melee range (C_SwingTimer range check).
]]

local _, NS = ...
local UI = NS.UI

local Swing = NS:NewModule("swing", {
    title = "Swing Timer",
    desc = "Main and off hand swings, cast clipping, melee range",
    icon = "Interface\\Icons\\INV_Axe_09",
})

local MH = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.MainHand or 0
local OH = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.OffHand or 1
local LINGER = 1.5

local state = {
    [MH] = { start = 0, dur = 0 },
    [OH] = { start = 0, dur = 0 },
    attacking = false, inCombat = false, outOfRange = false,
    castStart = 0, castEnd = 0, lastSwing = 0,
}
Swing.state = state

local frame

local function hasOffhand()
    if C_PaperDollInfo and C_PaperDollInfo.OffhandHasWeapon then
        local ok, has = pcall(C_PaperDollInfo.OffhandHasWeapon)
        if ok then return has and true or false end
    end
    return state[OH].dur > 0 and GetTime() - state[OH].start < 10
end

local function makeBar(label, h)
    local db = NS.db.swing
    local bar = UI:Bar(frame, db.width, h)
    bar.label = UI:Text(bar, 11, UI.palette.text, "OUTLINE")
    bar.label:SetPoint("LEFT", 4, 0)
    bar.label:SetText(label)
    bar.time = UI:Text(bar, 11, UI.palette.text, "OUTLINE")
    bar.time:SetPoint("RIGHT", -4, 0)
    bar.time:SetJustifyH("RIGHT")
    return bar
end

function Swing:Init()
    frame = CreateFrame("Frame", "ShammyForeverSwing", UIParent)
    frame:SetSize(NS.db.swing.width, 40)
    frame:Hide()
    self.frame = frame
    self.color = { UI:Accent() }

    self.mh = makeBar("Main Hand", NS.db.swing.height)
    self.mh:SetPoint("TOP")
    self.oh = makeBar("Off Hand", math.max(6, math.floor(NS.db.swing.height * 0.7)))
    self.oh:SetPoint("TOP", self.mh, "BOTTOM", 0, -3)

    -- cast projection on the main hand bar
    self.cast = self.mh:CreateTexture(nil, "OVERLAY")
    self.cast:SetTexture(UI.WHITE)
    self.cast:Hide()

    self.range = UI:Text(frame, 11, UI.palette.danger, "OUTLINE")
    self.range:SetPoint("BOTTOM", self.mh, "TOP", 0, 3)
    self.range:SetText("Out of range")
    self.range:Hide()

    NS.Movers:Register(frame, "swing", "Swing Timer", { "CENTER", "CENTER", 0, -170 })

    NS:On("PLAYER_SWING", function(_, duration, swingType)
        local hand = state[swingType]
        duration = NS.Readable(duration)
        if not hand or not duration then return end
        hand.start, hand.dur = GetTime(), duration
        state.lastSwing = hand.start
        self:Refresh()
    end)
    NS:On("PLAYER_ENTER_COMBAT", function() state.attacking = true; self:Refresh() end)
    NS:On("PLAYER_LEAVE_COMBAT", function() state.attacking = false; self:Refresh() end)
    NS:On("PLAYER_REGEN_DISABLED", function() state.inCombat = true; self:Refresh() end)
    NS:On("PLAYER_REGEN_ENABLED", function() state.inCombat = false; self:Refresh() end)
    NS:On("PLAYER_SWING_RANGE_UPDATE", function(_, swingType, inRange, checks)
        if swingType ~= MH then return end
        state.outOfRange = NS.Readable(checks) and NS.Readable(inRange) == false or false
        self:Refresh()
    end)
    NS:On("PLAYER_TARGET_CHANGED", function()
        state.outOfRange = false
        if C_SwingTimer and C_SwingTimer.IsTargetWithinSwingRange then
            local ok, inRange = pcall(C_SwingTimer.IsTargetWithinSwingRange, MH)
            if ok and NS.Readable(inRange) == false then state.outOfRange = true end
        end
        self:Refresh()
    end)
    NS:On("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" then self:Refresh() end end)

    local function castUpdate()
        local _, _, _, startMS, endMS = UnitCastingInfo("player")
        startMS, endMS = NS.Readable(startMS), NS.Readable(endMS)
        if startMS and endMS then
            state.castStart, state.castEnd = startMS / 1000, endMS / 1000
        else
            state.castStart, state.castEnd = 0, 0
        end
    end
    for _, ev in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_STOP",
                          "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
        NS:OnUnit(ev, "player", castUpdate)
    end

    if C_SwingTimer and C_SwingTimer.EnableRangeCheck then
        pcall(C_SwingTimer.EnableRangeCheck, MH, true)
    end

    frame:SetScript("OnUpdate", function() self:OnUpdate() end)
end

function Swing:Apply()
    if not frame then return end
    local db = NS.db.swing
    frame:SetWidth(db.width)
    self.mh:SetSize(db.width, db.height)
    self.oh:SetSize(db.width, math.max(6, math.floor(db.height * 0.7)))
    self.mh.spark:SetHeight(db.height)
    self.oh.spark:SetHeight(self.oh:GetHeight())
    self.mh.time:SetShown(db.showText)
    self.oh.time:SetShown(db.showText)
    self.mh.label:SetShown(db.showText and db.height >= 10)
    self.oh.label:SetShown(db.showText and db.height >= 14)
    local r, g, b = UI:Accent()
    self.color = { r, g, b }
    self:Refresh()
end

function Swing:Visible()
    if not NS:IsEnabled("swing") then return false end
    if NS.editing or not NS.db.swing.hideIdle then return true end
    return state.attacking or state.inCombat or (GetTime() - state.lastSwing < LINGER)
end

function Swing:Refresh()
    if not frame then return end
    local show = self:Visible()
    frame:SetShown(show)
    if not show then return end
    local oh = NS.db.swing.offhand and (hasOffhand() or NS.editing)
    self.oh:SetShown(oh and true or false)
    frame:SetHeight(oh and (self.mh:GetHeight() + self.oh:GetHeight() + 3) or self.mh:GetHeight())
    self.range:SetShown(NS.db.swing.rangeTint and state.outOfRange)
end

local function drawHand(bar, hand, now, color, dim)
    local value, left = 0, 0
    if NS.editing and hand.dur == 0 then
        value = (now % 2.6) / 2.6; left = 2.6 - value * 2.6
    elseif hand.dur > 0 then
        local elapsed = now - hand.start
        value = math.min(elapsed / hand.dur, 1)
        left = math.max(hand.dur - elapsed, 0)
    end
    bar:SetValue(value)
    if dim then
        bar:SetStatusBarColor(0.45, 0.47, 0.5)
    else
        bar:SetStatusBarColor(color[1], color[2], color[3])
    end
    if value > 0 and value < 1 then
        bar.spark:ClearAllPoints()
        bar.spark:SetPoint("CENTER", bar, "LEFT", value * bar:GetWidth(), 0)
        bar.spark:Show()
    else
        bar.spark:Hide()
    end
    bar.time:SetText(left > 0 and string.format("%.1f", left) or "")
end

function Swing:OnUpdate()
    local now = GetTime()
    local dim = NS.db.swing.rangeTint and state.outOfRange
    drawHand(self.mh, state[MH], now, self.color, dim)
    if self.oh:IsShown() then drawHand(self.oh, state[OH], now, self.color, dim) end

    -- cast projection: where the current cast ends relative to the next main hand swing
    local hand = state[MH]
    if NS.db.swing.showCast and state.castEnd > now and hand.dur > 0 then
        local w = self.mh:GetWidth()
        local nextSwing = hand.start + hand.dur
        local function x(t) return math.max(0, math.min(1, (t - hand.start) / hand.dur)) * w end
        local x1, x2 = x(math.max(state.castStart, now)), x(state.castEnd)
        if x2 - x1 >= 1 then
            self.cast:ClearAllPoints()
            self.cast:SetPoint("TOPLEFT", self.mh, "TOPLEFT", x1, 0)
            self.cast:SetPoint("BOTTOMLEFT", self.mh, "BOTTOMLEFT", x1, 0)
            self.cast:SetWidth(x2 - x1)
            if state.castEnd > nextSwing then
                self.cast:SetVertexColor(UI.palette.danger[1], UI.palette.danger[2], UI.palette.danger[3], 0.75)
            else
                self.cast:SetVertexColor(1, 1, 1, 0.35)
            end
            self.cast:Show()
        else
            self.cast:Hide()
        end
    else
        self.cast:Hide()
    end

    -- the bar hides itself once idle long enough
    if NS.db.swing.hideIdle and not NS.editing and not state.attacking and not state.inCombat
        and now - state.lastSwing >= LINGER then
        self:Refresh()
    end
end
