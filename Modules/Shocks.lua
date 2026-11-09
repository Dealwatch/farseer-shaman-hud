--[[
    ShammyForever - Stormstrike, shocks and cooldowns
      * "Shock now!" prompt right after Stormstrike: its bonus applies to the
        next Nature hit, so Earth Shock should follow immediately.
      * Flame Shock timer for your target, started from your own cast (target
        debuffs are secret in combat) and corrected from the real aura
        whenever the client lets us read it.
      * A row of cooldown icons. GetSpellCooldownDuration returns a duration
        object the cooldown swirl takes even when the numbers are secret.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local Shocks = NS:NewModule("shocks", {
    title = "Stormstrike & Shocks",
    desc = "Shock-now prompt, Flame Shock timer, cooldown row",
    icon = "Interface\\Icons\\Ability_Shaman_Stormstrike",
})

local COOLDOWNS = { "stormstrike", "earthShock", "fireNova", "rageFarseer", "shamanisticRage", "elementalMastery" }
local SHOCKS = { earthShock = true, flameShock = true, frostShock = true }

local prompt, fsBar, cdRow
local cdIcons = {}
local fs = { start = 0, ends = 0 }
local promptUntil = 0

---------------------------------------------------------------------------
-- Shock prompt
---------------------------------------------------------------------------

local function buildPrompt()
    prompt = CreateFrame("Frame", "ShammyForeverShockPrompt", UIParent)
    prompt:SetSize(170, 40)
    UI:Skin(prompt, UI.palette.surface, UI.palette.border, "lg")
    prompt.iconFrame = UI:Icon(prompt, 32)
    prompt.iconFrame:SetPoint("LEFT", 4, 0)
    prompt.text = UI:Text(prompt, 15, { 1, 0.82, 0.25, 1 }, "OUTLINE")
    prompt.text:SetPoint("LEFT", prompt.iconFrame, "RIGHT", 8, 0)
    prompt.text:SetText("Shock now!")
    prompt:Hide()
    NS.Movers:Register(prompt, "shockprompt", "Shock prompt", { "CENTER", "CENTER", 0, -80 })
end

function Shocks:ShowPrompt(on)
    if on then
        local def = Spells:Get("earthShock")
        prompt.iconFrame.icon:SetTexture(def and def.icon or "Interface\\Icons\\Spell_Nature_EarthShock")
        prompt:Show()
        UI:Glow(prompt.iconFrame, 1, 0.82, 0.25)
    else
        UI:Glow(prompt.iconFrame)
        prompt:SetShown(NS.editing and NS:IsEnabled("shocks") and NS.db.shocks.prompt or false)
    end
end

---------------------------------------------------------------------------
-- Flame Shock bar
---------------------------------------------------------------------------

local function buildFlameShock()
    fsBar = CreateFrame("Frame", "ShammyForeverFlameShock", UIParent)
    fsBar:SetSize(NS.db.shocks.barWidth, 18)
    fsBar.iconFrame = UI:Icon(fsBar, 18)
    fsBar.iconFrame:SetPoint("LEFT")
    fsBar.bar = UI:Bar(fsBar, NS.db.shocks.barWidth - 20, 18)
    fsBar.bar:SetPoint("LEFT", fsBar.iconFrame, "RIGHT", 2, 0)
    fsBar.bar:SetStatusBarColor(1, 0.45, 0.16)
    fsBar.name = UI:Text(fsBar.bar, 11, UI.palette.text, "OUTLINE")
    fsBar.name:SetPoint("LEFT", 4, 0)
    fsBar.name:SetPoint("RIGHT", -36, 0)
    fsBar.time = UI:Text(fsBar.bar, 11, UI.palette.text, "OUTLINE")
    fsBar.time:SetPoint("RIGHT", -4, 0)
    fsBar.time:SetJustifyH("RIGHT")
    fsBar:Hide()
    UI:NativeHost(fsBar)
    fsBar:SetScript("OnUpdate", function() Shocks:DrawFlameShock() end)
    NS.Movers:Register(fsBar, "flameshock", "Flame Shock", { "CENTER", "CENTER", 0, -205 })

    -- native slot: your own Flame Shock on the target, real time left even in combat
    Shocks.native = NS.Native:Slot({
        key = "flameshock", parent = fsBar, unit = "target", filter = "HARMFUL|PLAYER",
        ids = function() return Spells:AuraIDs("flameShock") end,
        init = function(b)
            local w = NS.db.shocks.barWidth
            b:SetSize(w, 18)
            local iconFrame = CreateFrame("Frame", nil, b)
            iconFrame:SetSize(18, 18)
            iconFrame:SetPoint("LEFT")
            UI:Skin(iconFrame, UI.palette.track, UI.palette.border)
            local tex = iconFrame:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT", 1, -1)
            tex:SetPoint("BOTTOMRIGHT", -1, 1)
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b:SetIcon(tex)
            local bar = CreateFrame("StatusBar", nil, b)
            bar:SetPoint("LEFT", iconFrame, "RIGHT", 2, 0)
            bar:SetSize(w - 20, 18)
            UI:Skin(bar, UI.palette.track, UI.palette.border, "sm")
            bar:SetStatusBarTexture(UI:BarTexture())
            bar:SetStatusBarColor(1, 0.45, 0.16)
            b:SetDurationBar(bar, { direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1 })
            local name = UI:Text(bar, 11, UI.palette.text, "OUTLINE")
            name:SetPoint("LEFT", 4, 0)
            local def = Spells:Get("flameShock")
            name:SetText(def and def.name or "Flame Shock")
            local time = UI:Text(bar, 11, UI.palette.text, "OUTLINE")
            time:SetPoint("RIGHT", -4, 0)
            time:SetJustifyH("RIGHT")
            b:SetDurationText(time)
            Shocks.nativeBar = bar
        end,
        onBuilt = function() Shocks:Apply() end,
    })
end

local function flameShockDuration()
    local def = Spells:Get("flameShock")
    return (def and NS.db.learned.durations[def.name]) or NS.db.shocks.flameShockDuration
end

-- Correct the timer from the real debuff when the client lets us read it.
local function readTargetFlameShock()
    local def = Spells:Get("flameShock")
    if not (def and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "target", def.name, "HARMFUL|PLAYER")
    if not ok then return end
    if aura then
        local dur, exp = NS.Readable(aura.duration), NS.Readable(aura.expirationTime)
        if dur and exp and dur > 0 then
            NS.db.learned.durations[def.name] = dur
            fs.start, fs.ends = exp - dur, exp
        end
    elseif not NS.IsSecret(aura) and fs.ends > GetTime() and UnitExists("target") and not InCombatLockdown() then
        fs.ends = 0   -- readable and gone
    end
end

function Shocks:DrawFlameShock()
    local native = Shocks.native and Shocks.native:Active() and not NS.editing
    fsBar.iconFrame:SetShown(not native)
    fsBar.bar:SetShown(not native)
    if native then return end   -- the client draws it
    local now = GetTime()
    local left = fs.ends - now
    if NS.editing and left <= 0 then
        fsBar.bar:SetValue(0.6); fsBar.time:SetText("7.2"); fsBar.name:SetText("Flame Shock")
        return
    end
    if left <= 0 then UI:SafeShow(fsBar, false) return end
    local total = math.max(fs.ends - fs.start, 0.1)
    fsBar.bar:SetValue(left / total)
    fsBar.time:SetText(string.format("%.1f", left))
    if left < 3 then fsBar.bar:SetStatusBarColor(1, 0.25, 0.25) else fsBar.bar:SetStatusBarColor(1, 0.45, 0.16) end
end

function Shocks:StartFlameShock()
    local def = Spells:Get("flameShock")
    fs.start = GetTime()
    fs.ends = fs.start + flameShockDuration()
    fsBar.iconFrame.icon:SetTexture(def and def.icon or "Interface\\Icons\\Spell_Fire_FlameShock")
    -- the name may be secret: SetText accepts it, but a boolean test would error
    local target = UnitName("target")
    if NS.IsSecret(target) or target then fsBar.name:SetText(target) else fsBar.name:SetText(def and def.name or "Flame Shock") end
    if NS:IsEnabled("shocks") and NS.db.shocks.flameShock then UI:SafeShow(fsBar, true) end
    if Shocks.native then Shocks.native:Refresh() end
end

---------------------------------------------------------------------------
-- Cooldown row
---------------------------------------------------------------------------

local function buildCooldowns()
    cdRow = CreateFrame("Frame", "ShammyForeverCooldowns", UIParent)
    cdRow:SetSize(100, 32)
    cdRow:Hide()
    for _, key in ipairs(COOLDOWNS) do
        local f = UI:Icon(cdRow, NS.db.shocks.iconSize)
        f.cd = UI:Cooldown(f)
        f.key = key
        cdIcons[#cdIcons + 1] = f
    end
    NS.Movers:Register(cdRow, "cooldowns", "Cooldowns", { "CENTER", "CENTER", 0, -265 })
end

local function setCooldown(f, def)
    if C_Spell.GetSpellCooldownDuration then
        local ok, d = pcall(C_Spell.GetSpellCooldownDuration, def.id)
        if ok and d and pcall(f.cd.SetCooldownFromDurationObject, f.cd, d, true) then return end
    end
    local ok, info = pcall(C_Spell.GetSpellCooldown, def.id)
    if ok and info then
        local start, dur = NS.Readable(info.startTime), NS.Readable(info.duration)
        if start and dur and dur > 0 then f.cd:SetCooldown(start, dur) else f.cd:Clear() end
    end
end

function Shocks:UpdateCooldowns()
    if not cdRow then return end
    local size = NS.db.shocks.iconSize
    local x = 0
    for _, f in ipairs(cdIcons) do
        local def = Spells:Get(f.key)
        local show = def and (def.known or (NS.editing and f.key == "stormstrike"))
        f:SetShown(show and true or false)
        if show then
            f:SetSize(size, size)
            f:ClearAllPoints()
            f:SetPoint("LEFT", cdRow, "LEFT", x, 0)
            x = x + size + 4
            f.icon:SetTexture(def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            setCooldown(f, def)
            local usable = true
            if C_Spell.IsSpellUsable then
                local ok, u = pcall(C_Spell.IsSpellUsable, def.id)
                if ok and NS.Readable(u) == false then usable = false end
            end
            f.icon:SetDesaturated(not usable)
        end
    end
    cdRow:SetSize(math.max(x - 4, 1), size)
    cdRow:SetShown(NS:IsEnabled("shocks") and NS.db.shocks.cooldowns and x > 0 or false)
end

---------------------------------------------------------------------------

function Shocks:Init()
    buildPrompt()
    buildFlameShock()
    buildCooldowns()

    NS:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, _, spellID)
        local key = Spells:KeyFor(spellID)
        if not key or not NS:IsEnabled("shocks") then return end
        if key == "stormstrike" and NS.db.shocks.prompt then
            promptUntil = GetTime() + NS.db.shocks.promptWindow
            self:ShowPrompt(true)
            C_Timer.After(NS.db.shocks.promptWindow, function()
                if GetTime() >= promptUntil then self:ShowPrompt(false) end
            end)
        elseif SHOCKS[key] then
            promptUntil = 0
            self:ShowPrompt(false)
            if key == "flameShock" then self:StartFlameShock() end
        end
    end)
    NS:OnUnit("UNIT_AURA", "target", readTargetFlameShock)
    NS:On("PLAYER_TARGET_CHANGED", function()
        readTargetFlameShock()
        if self.native then self.native:Refresh() end
    end)
    self.native:Build()
    NS:On("PLAYER_REGEN_ENABLED", function()
        promptUntil = 0
        self:ShowPrompt(false)
        if fs.ends > GetTime() and not UnitExists("target") then fs.ends = 0 end
    end)
    NS:On("SPELL_UPDATE_COOLDOWN", function() self:UpdateCooldowns() end)
    NS:On("SPELL_UPDATE_USABLE", function() self:UpdateCooldowns() end)
    NS:On("SF_SPELLS", function() self:UpdateCooldowns() end)
end

function Shocks:Apply()
    if not prompt then return end
    local db = NS.db.shocks
    local on = NS:IsEnabled("shocks")
    fsBar:SetWidth(db.barWidth)
    fsBar.bar:SetWidth(db.barWidth - 20)
    prompt:SetShown(on and db.prompt and (NS.editing or GetTime() < promptUntil) or false)
    local native = self.native and self.native:Active()
    UI:SafeShow(fsBar, on and db.flameShock and (native or NS.editing or fs.ends > GetTime()))
    if native then
        self.native:Restyle(function(b)
            b:SetSize(db.barWidth, 18)
            if Shocks.nativeBar then Shocks.nativeBar:SetSize(db.barWidth - 20, 18) end
        end)
    end
    self:UpdateCooldowns()
end
