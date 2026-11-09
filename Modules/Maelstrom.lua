--[[
    ShammyForever - Maelstrom Weapon
    Five pips that fill with your Maelstrom Weapon stacks and light up at five
    ("instant Lightning Bolt").

    Buffs are secret in combat on Forever. Two sources, best first:
      1. The aura itself. Retail Midnight whitelists Maelstrom Weapon so addons
         can read it in combat; if Forever does the same we get exact stacks.
      2. The spell-activation glow on Lightning Bolt / Chain Lightning, which is
         never secret: we at least know when you are at five.
    /sham probe shows which one your client gives us.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local MW = NS:NewModule("maelstrom", {
    title = "Maelstrom Weapon",
    desc = "Stack pips, glow and sound at five stacks",
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

function MW:Init()
    frame = CreateFrame("Frame", "ShammyForeverMaelstrom", UIParent)
    frame:Hide()
    self.frame = frame
    for i = 1, MAX do
        local p = CreateFrame("Frame", nil, frame)
        UI:Skin(p, UI.palette.track, UI.palette.border, "xs")
        p.fill = p:CreateTexture(nil, "ARTWORK")
        if not UI.Sliced(p.fill, "Fill", "xs") then p.fill:SetTexture(UI.WHITE) end
        p.fill:SetPoint("TOPLEFT", 1, -1)
        p.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        pips[i] = p
    end
    self.label = UI:Text(frame, 11, UI.palette.textDim, "OUTLINE")
    self.label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 3)
    self.label:SetText("Maelstrom")
    self.hint = UI:Text(frame, 11, UI.palette.text, "OUTLINE")
    self.hint:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 3)
    self.hint:SetJustifyH("RIGHT")
    NS.Movers:Register(frame, "maelstrom", "Maelstrom", { "CENTER", "CENTER", 0, -130 })

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
    local inCombat = InCombatLockdown()
    if stacks then
        state.source = "aura"
        if inCombat then state.readableInCombat = true end
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
    local enabled = NS:IsEnabled("maelstrom")
    local stacks = state.stacks
    if NS.editing and not stacks then stacks = 3 end
    local show = enabled and (NS.editing or not db.hideEmpty or InCombatLockdown() or (stacks or 0) > 0 or state.full)
    frame:SetShown(show and true or false)
    if not show then return end

    local r, g, b = UI:Accent()
    local filled = state.full and MAX or (stacks or 0)
    for i = 1, MAX do
        local p = pips[i]
        if i <= filled then
            if state.full then p.fill:SetVertexColor(1, 0.82, 0.25, 1) else p.fill:SetVertexColor(r, g, b, 1) end
            p.fill:Show()
        else
            p.fill:Hide()
        end
    end
    if state.full then
        self.hint:SetText("|cffffd140Instant Bolt!|r")
        if db.glow then UI:Glow(frame, 1, 0.82, 0.25) end
    else
        self.hint:SetText(stacks and "" or "|cff7f8899?|r")
        UI:Glow(frame)
    end
end

function MW:Apply()
    if not frame then return end
    local s = NS.db.maelstrom.size
    for i, p in ipairs(pips) do
        p:SetSize(s, s * 0.6)
        p:ClearAllPoints()
        p:SetPoint("LEFT", frame, "LEFT", (i - 1) * (s + 4), 0)
    end
    frame:SetSize(MAX * (s + 4) - 4, s * 0.6)
    self:Update()
end
