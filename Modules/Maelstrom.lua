--[[
    ShammyForever - Maelstrom Weapon
    A five-segment bar that fills with your stacks and turns gold at five
    ("instant Lightning Bolt"), with an optional glow and sound.

    Stacks are drawn by the client through a native aura slot, so the bar is
    right even while the buff is secret. Glow and sound need us to *know* it
    is five, from (best first):
      1. the buff itself, when the client lets us read it,
      2. the spell-activation glow on Lightning Bolt / Chain Lightning, which
         is never secret.
    Without a native slot the bar falls back to our own pips.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local MW = NS:NewModule("maelstrom", {
    title = "Maelstrom Weapon",
    desc = "Five-segment stack bar, glow and sound at five",
    icon = "Interface\\Icons\\Spell_Shaman_MaelstromWeapon",
})

local MAX = 5
local state = { stacks = nil, full = false, source = "none", readableInCombat = false }
MW.state = state

local frame
local pips = {}

-- Exact stacks from the aura when the client lets us read it.
-- Returns stacks (0..MAX) or nil when we cannot tell.
function MW.ReadAura()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
    local learned = NS.db.learned.maelstromBuffID
    if learned and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, learned)
        if ok and aura then
            local n = NS.Readable(aura.applications)
            if n then return math.max(n, 1) end
        end
    end
    local sawSecret = false
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok then return nil end
        if not aura then break end
        local id, name = NS.Readable(aura.spellId), NS.Readable(aura.name)
        if not id and not name then
            sawSecret = true
        elseif Spells:KeyFor(id or name) == "maelstrom" then
            if id then NS.db.learned.maelstromBuffID = id end
            local n = NS.Readable(aura.applications)
            if n then return math.max(n, 1) end
            sawSecret = true
        end
    end
    if sawSecret then return nil end
    return 0
end

local GAP = 3

local function geometry()
    local db = NS.db.maelstrom
    local pipW = (db.width - GAP * (MAX - 1)) / MAX
    return db.width, db.height, pipW
end

function MW:Init()
    frame = CreateFrame("Frame", "ShammyForeverMaelstrom", UIParent)
    frame:Hide()
    UI:NativeHost(frame)
    self.frame = frame

    -- fallback pips (also the edit-mode preview)
    for i = 1, MAX do
        local p = CreateFrame("Frame", nil, frame)
        UI:Skin(p, UI.palette.track, UI.palette.border, "xs")
        p.fill = p:CreateTexture(nil, "ARTWORK")
        if not UI.Sliced(p.fill, "Fill", "xs") then p.fill:SetTexture(UI.WHITE) end
        p.fill:SetPoint("TOPLEFT", 1, -1)
        p.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        pips[i] = p
    end

    -- native mode: one bar the client fills, cut into five by dividers
    self.track = CreateFrame("Frame", nil, frame)
    self.track:SetAllPoints()
    UI:Skin(self.track, UI.palette.track, UI.palette.border, "xs")
    self.track:Hide()
    self.dividers = CreateFrame("Frame", nil, frame)
    self.dividers:SetAllPoints()
    self.dividers:SetFrameLevel(frame:GetFrameLevel() + 10)
    self.dividers.lines = {}
    for i = 1, MAX - 1 do
        local t = self.dividers:CreateTexture(nil, "OVERLAY")
        t:SetTexture(UI.WHITE)
        t:SetVertexColor(UI.palette.track[1], UI.palette.track[2], UI.palette.track[3], 1)
        self.dividers.lines[i] = t
    end
    self.dividers:Hide()
    self.native = NS.Native:Slot({
        key = "maelstrom", parent = frame, unit = "player", filter = "HELPFUL", level = 3,
        ids = function() return Spells:AuraIDs("maelstrom") end,
        init = function(b)
            local w, h = geometry()
            b:SetSize(w, h)
            local bar = CreateFrame("StatusBar", nil, b)
            bar:SetPoint("TOPLEFT", 1, -1)
            bar:SetPoint("BOTTOMRIGHT", -1, 1)
            bar:SetStatusBarTexture(UI.WHITE)
            bar:SetStatusBarColor(UI:Accent())
            b:SetApplicationBar(bar, { minApplications = 0, maxApplications = MAX })
            MW.nativeBar = bar
        end,
        onBuilt = function() MW:Apply() end,
    })

    -- only text: shown at five stacks
    self.hint = UI:Text(frame, 11, { 1, 0.82, 0.25, 1 }, "OUTLINE")
    self.hint:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 3)
    self.hint:SetJustifyH("RIGHT")
    self.hint:SetText("Instant Bolt!")
    self.hint:Hide()
    NS.Movers:Register(frame, "maelstrom", "Maelstrom", { "CENTER", "CENTER", 0, -118 })

    self.native:Build()
    NS:OnUnit("UNIT_AURA", "player", function() self:Update() end)
    NS:On("PLAYER_REGEN_ENABLED", function() self:Update() end)
    NS:On("PLAYER_REGEN_DISABLED", function() self:Update() end)
    NS:On("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", function(_, spellID)
        local key = Spells:KeyFor(spellID)
        if key == "lightningBolt" or key == "chainLightning" then
            state.procGlow = true
            self:Update()
        end
    end)
    NS:On("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", function(_, spellID)
        local key = Spells:KeyFor(spellID)
        if key == "lightningBolt" or key == "chainLightning" or spellID == nil then
            state.procGlow = false
            self:Update()
        end
    end)
    NS:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, _, spellID)
        local key = Spells:KeyFor(spellID)
        if key == "lightningBolt" or key == "chainLightning" then
            state.procGlow = false
            self:Update()
        end
    end)
end

function MW:Update()
    if not frame then return end
    local stacks = MW.ReadAura()
    if stacks then
        state.source = "aura"
        if InCombatLockdown() then state.readableInCombat = true end
    elseif state.procGlow ~= nil then
        state.source = "proc"
    end
    local wasFull = state.full
    state.stacks = stacks
    state.full = (stacks and stacks >= MAX) or (not stacks and state.procGlow) or false
    if state.full and not wasFull and NS.db.maelstrom.sound then UI:Sound("ALARM_CLOCK_WARNING_2") end
    self:Draw()
end

function MW:Draw()
    local db = NS.db.maelstrom
    local stacks = state.stacks
    if NS.editing and not stacks then stacks = 3 end
    -- not before you have the talent (or the client showed us stacks once)
    local have = Spells:Known("maelstrom") or NS.db.learned.maelstromBuffID ~= nil
    local show = NS:IsEnabled("maelstrom") and (NS.editing or have and (not db.hideEmpty or InCombatLockdown()
        or (stacks or 0) > 0 or state.full))
    UI:SafeShow(frame, show)
    if not show then return end

    local native = self.native:Active() and not NS.editing
    self.track:SetShown(native)
    self.dividers:SetShown(native)
    local r, g, b = UI:Accent()
    if self.nativeBar then
        if state.full then self.nativeBar:SetStatusBarColor(1, 0.82, 0.25) else self.nativeBar:SetStatusBarColor(r, g, b) end
    end
    local filled = state.full and MAX or (stacks or 0)
    for i = 1, MAX do
        local p = pips[i]
        p:SetShown(not native)
        p.fill:SetShown(i <= filled)
        if state.full then p.fill:SetVertexColor(1, 0.82, 0.25, 1) else p.fill:SetVertexColor(r, g, b, 1) end
    end
    self.hint:SetShown(state.full)
    if state.full and db.glow then UI:Glow(frame, 1, 0.82, 0.25) else UI:Glow(frame) end
end

function MW:Apply()
    if not frame then return end
    local w, h, pipW = geometry()
    frame:SetSize(w, h)
    for i, p in ipairs(pips) do
        p:SetSize(pipW, h)
        p:ClearAllPoints()
        p:SetPoint("LEFT", frame, "LEFT", (i - 1) * (pipW + GAP), 0)
    end
    for i, t in ipairs(self.dividers.lines) do
        t:ClearAllPoints()
        t:SetPoint("TOP", frame, "TOPLEFT", i * (pipW + GAP) - GAP / 2, 0)
        t:SetSize(GAP, h)
    end
    self.native:Restyle(function(b) b:SetSize(w, h) end)
    self:Update()
end
