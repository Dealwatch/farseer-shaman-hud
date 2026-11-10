--[[
    Farseer - Stormstrike, shocks and cooldowns
      * Next-spell glow: exactly one thing glows gold, the next press. Order
        (the Forever guides agree on it): Fire Nova while Magma Totem is down
        (a group), Flame Shock when it is missing or about to run out,
        Stormstrike, Lightning Bolt at five Maelstrom (the Maelstrom bar
        glows), Earth Shock as filler. The shock icon shows the shock to use.
      * Stormstrike boosts your next Earth Shock, Lightning Bolt or Chain
        Lightning by 20% for 12 s: a gold line under the cooldown row drains
        while that bonus is unspent.
      * Flame Shock timer for your target, started from your own cast (target
        debuffs are secret in combat) and corrected from the real aura
        whenever the client lets us read it.
      * A row of cooldown icons. GetSpellCooldownDuration returns a duration
        object the cooldown swirl takes even when the numbers are secret.

    In combat cooldown numbers can be secret, so "ready" comes from the
    client when it is readable and from your own casts otherwise.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local Shocks = NS:NewModule("shocks", {
    title = "Stormstrike & Shocks",
    desc = "Next-spell glow, Flame Shock timer, cooldown row",
    icon = "Interface\\Icons\\Ability_Shaman_Stormstrike",
})

local COOLDOWNS = { "stormstrike", "earthShock", "fireNova", "rageFarseer", "elementalMastery" }
local SHOCKS = { earthShock = true, flameShock = true, frostShock = true }
local SPENDS_BONUS = { earthShock = true, lightningBolt = true, chainLightning = true }
local GOLD = { 1, 0.82, 0.25 }
local BONUS_WINDOW = 12     -- seconds Stormstrike's +20% waits for a shock or bolt
local FS_REFRESH = 3        -- refresh Flame Shock below this many seconds (its bar turns red there too)
-- cooldowns in seconds until the client has told us the real ones (learned whenever they are readable)
local BASE_CD = { stormstrike = 6, earthShock = 6, fireNova = 10 }

local FS_H = 16            -- Flame Shock bar height (icon is square)
local prompt, fsBar, cdRow
local cdIcons = {}
Shocks.cdIcons = cdIcons
local fs = { start = 0, ends = 0 }
local fsBy = {}             -- target GUID -> { start, ends } of your Flame Shock there (this fight)
local cdEnd = {}            -- icon key -> when the cooldown your own cast started is over
local bonusUntil = 0        -- Stormstrike's bonus is unspent until then
local advice, advising      -- what glows now; whether the glow logic is running at all
local bonusBar

---------------------------------------------------------------------------
-- Shock prompt
---------------------------------------------------------------------------

local function buildPrompt()
    prompt = CreateFrame("Frame", "FarseerHUDShockPrompt", UIParent)
    prompt:SetSize(190, 40)
    UI:Skin(prompt, UI.palette.surface, UI.palette.border, "lg")
    prompt.iconFrame = UI:Icon(prompt, 32)
    prompt.iconFrame:SetPoint("LEFT", 4, 0)
    prompt.text = UI:Text(prompt, 15, { 1, 0.82, 0.25, 1 }, "OUTLINE")
    prompt.text:SetPoint("LEFT", prompt.iconFrame, "RIGHT", 8, 0)
    prompt.text:SetText("Shock now!")
    prompt:Hide()
    NS.Movers:Register(prompt, "shockprompt", "Shock card", { "CENTER", "CENTER", 0, -36 })
end

local function shockIcon()
    for _, f in ipairs(cdIcons) do
        if f.key == "earthShock" and f:IsShown() and cdRow:IsShown() then return f end
    end
end

---------------------------------------------------------------------------
-- Next-spell glow
---------------------------------------------------------------------------

local function ready(key)
    local def = Spells:Get(key)
    if not (def and def.known) then return false end
    if C_Spell.IsSpellUsable then
        local ok, u = pcall(C_Spell.IsSpellUsable, def.id)
        if ok and NS.Readable(u) == false then return false end   -- no mana, no fire totem, ...
    end
    local iconKey = SHOCKS[key] and "earthShock" or key           -- shocks share one cooldown
    local ok, info = pcall(C_Spell.GetSpellCooldown, def.id)
    local start = ok and info and NS.Readable(info.startTime)
    local dur = start and NS.Readable(info.duration)
    if dur then
        if dur <= 1.5 then return true end                        -- only the global cooldown
        NS.db.learned.cooldowns[iconKey] = dur
        return start + dur <= GetTime()
    end
    return GetTime() >= (cdEnd[iconKey] or 0)                     -- secret: go by your own cast
end

-- The shock the shock icon stands for right now.
local function shockToUse()
    if Spells:Known("flameShock") and fs.ends - GetTime() < FS_REFRESH then return "flameShock" end
    return Spells:Known("earthShock") and "earthShock" or nil
end

local function pick()
    local shock = shockToUse()
    local group = NS.modules.totems.FireTotem and NS.modules.totems.FireTotem() == "magmaTotem"
    if group and ready("fireNova") then return "fireNova" end
    if shock == "flameShock" and ready(shock) then return shock end
    if ready("stormstrike") then return "stormstrike" end
    if NS.modules.maelstrom.state.full and Spells:Known("lightningBolt") then return "lightningBolt" end
    if shock and ready(shock) then return shock end
end

function Shocks.Advice() return advice end
function Shocks.Advising() return advising or false end

-- Called on every event that can change the answer and a few times a second in combat.
function Shocks:Advise()
    local db = NS.db.shocks
    local on = NS:IsEnabled("shocks") and db.prompt
    advising = on and NS.InCombat() and UI.HostileTarget() or false
    local now = GetTime()
    local new = advising and pick() or nil
    local bonus = advising and now < bonusUntil

    local shock = shockToUse() or "earthShock"
    local icon = shockIcon()
    if icon and icon.shock ~= shock then
        icon.shock = shock
        icon.icon:SetTexture(Spells:Get(shock).icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    end

    bonusBar:SetShown(bonus)
    if bonus then bonusBar:SetValue(bonusUntil - now) end

    -- the big card: "shock now, it is boosted" (also when there is no icon to light up)
    local card = bonus and new == "earthShock" and (db.promptCard or not icon)
        or (NS.editing and on and db.promptCard) or false
    if card ~= prompt:IsShown() then
        prompt.iconFrame.icon:SetTexture(Spells:Get("earthShock").icon or "Interface\\Icons\\Spell_Nature_EarthShock")
        prompt:SetShown(card)
        if card and not NS.editing then UI:Glow(prompt.iconFrame, GOLD[1], GOLD[2], GOLD[3]) else UI:Glow(prompt.iconFrame) end
    end

    if new == advice then return end
    local old = advice
    advice = new
    for _, f in ipairs(cdIcons) do
        local mine = new ~= nil and (f.key == new or (f.key == "earthShock" and SHOCKS[new] == true))
        if mine ~= (f.lit or false) then
            f.lit = mine
            if mine then UI:Glow(f, GOLD[1], GOLD[2], GOLD[3]) else UI:Glow(f) end
        end
    end
    -- the Maelstrom bar is the Lightning Bolt "icon"
    if new == "lightningBolt" or old == "lightningBolt" then NS.modules.maelstrom:Draw() end
end

---------------------------------------------------------------------------
-- Flame Shock bar
---------------------------------------------------------------------------

local function buildFlameShock()
    local w = NS.db.shocks.barWidth
    fsBar = CreateFrame("Frame", "FarseerHUDFlameShock", UIParent)
    fsBar:SetSize(w, FS_H)
    fsBar.iconFrame = UI:Icon(fsBar, FS_H)
    fsBar.iconFrame:SetPoint("LEFT")
    fsBar.bar = UI:Bar(fsBar, w - FS_H - 2, FS_H)
    fsBar.bar:SetPoint("LEFT", fsBar.iconFrame, "RIGHT", 2, 0)
    fsBar.bar:SetStatusBarColor(1, 0.45, 0.16)
    fsBar.time = UI:Text(fsBar.bar, 10, UI.palette.text, "OUTLINE")
    fsBar.time:SetPoint("RIGHT", -4, 0)
    fsBar.time:SetJustifyH("RIGHT")
    fsBar:Hide()
    UI:NativeHost(fsBar)
    fsBar:SetScript("OnUpdate", function() Shocks:DrawFlameShock() end)
    NS.Movers:Register(fsBar, "flameshock", "Flame Shock", { "CENTER", "CENTER", 0, -178 })

    -- native slot: your own Flame Shock on the target, real time left even in combat
    Shocks.native = NS.Native:Slot({
        key = "flameshock", parent = fsBar, unit = "target", filter = "HARMFUL|PLAYER",
        ids = function() return Spells:AuraIDs("flameShock") end,
        init = function(b)
            local bw = NS.db.shocks.barWidth
            b:SetSize(bw, FS_H)
            local iconFrame = CreateFrame("Frame", nil, b)
            iconFrame:SetSize(FS_H, FS_H)
            iconFrame:SetPoint("LEFT")
            UI:Skin(iconFrame, UI.palette.track, UI.palette.border)
            local tex = iconFrame:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT", 1, -1)
            tex:SetPoint("BOTTOMRIGHT", -1, 1)
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b:SetIcon(tex)
            local bar = CreateFrame("StatusBar", nil, b)
            bar:SetPoint("LEFT", iconFrame, "RIGHT", 2, 0)
            bar:SetSize(bw - FS_H - 2, FS_H)
            UI:Skin(bar, UI.palette.track, UI.palette.border, "sm")
            bar:SetStatusBarTexture(UI:BarTexture())
            bar:SetStatusBarColor(1, 0.45, 0.16)
            b:SetDurationBar(bar, { direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1 })
            local time = UI:Text(bar, 10, UI.palette.text, "OUTLINE")
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
        fsBar.bar:SetValue(0.6); fsBar.time:SetText("7.2")
        return
    end
    if left <= 0 then UI:SafeShow(fsBar, false) return end
    local total = math.max(fs.ends - fs.start, 0.1)
    fsBar.bar:SetValue(left / total)
    fsBar.time:SetText(string.format("%.1f", left))
    if left < 3 then fsBar.bar:SetStatusBarColor(1, 0.25, 0.25) else fsBar.bar:SetStatusBarColor(1, 0.45, 0.16) end
end

-- Your Flame Shock is per target: switching targets must not carry the timer along.
local function targetGUID()
    local guid = NS.Readable(NS.Try(UnitGUID, "target"))
    return type(guid) == "string" and guid or nil
end

local function targetChanged()
    local known = fsBy[targetGUID() or 0]
    -- unknown target (or its GUID is secret): assume no Flame Shock there
    fs.start, fs.ends = known and known[1] or 0, known and known[2] or 0
end

function Shocks:StartFlameShock()
    local def = Spells:Get("flameShock")
    fs.start = GetTime()
    fs.ends = fs.start + flameShockDuration()
    local guid = targetGUID()
    if guid then fsBy[guid] = { fs.start, fs.ends } end
    fsBar.iconFrame.icon:SetTexture(def and def.icon or "Interface\\Icons\\Spell_Fire_FlameShock")
    if NS:IsEnabled("shocks") and NS.db.shocks.flameShock then UI:SafeShow(fsBar, true) end
    if Shocks.native then Shocks.native:Refresh() end
end

---------------------------------------------------------------------------
-- Cooldown row
---------------------------------------------------------------------------

local function buildCooldowns()
    cdRow = CreateFrame("Frame", "FarseerHUDCooldowns", UIParent)
    cdRow:SetSize(100, 32)
    cdRow:Hide()
    for _, key in ipairs(COOLDOWNS) do
        local f = UI:Icon(cdRow, NS.db.shocks.iconSize)
        f.cd = UI:Cooldown(f)
        f.key = key
        -- flash once when the cooldown that your own cast started runs out
        f.cd:SetScript("OnCooldownDone", function()
            if f.armed and NS.db.shocks.readyFlash and f:IsShown() then UI:Flash(f) end
            f.armed = false
            cdEnd[key] = 0
            Shocks:Advise()
        end)
        cdIcons[#cdIcons + 1] = f
    end
    -- Stormstrike's unspent bonus: a gold line under the row, draining over 12 s
    bonusBar = CreateFrame("StatusBar", nil, cdRow)
    bonusBar:SetPoint("TOPLEFT", cdRow, "BOTTOMLEFT", 0, -5)
    bonusBar:SetPoint("TOPRIGHT", cdRow, "BOTTOMRIGHT", 0, -5)
    bonusBar:SetHeight(2)
    bonusBar:SetStatusBarTexture(UI.WHITE)
    bonusBar:SetStatusBarColor(GOLD[1], GOLD[2], GOLD[3])
    bonusBar:SetMinMaxValues(0, BONUS_WINDOW)
    bonusBar:Hide()
    -- a few times a second in combat: cooldowns and timers run out without an event
    local since = 0
    cdRow.ticker = CreateFrame("Frame")
    cdRow.ticker:SetScript("OnUpdate", function(_, dt)
        since = since + (dt or 0)
        if since < 0.1 then return end
        since = 0
        if advising or NS.InCombat() then Shocks:Advise() end
    end)
    NS.Movers:Register(cdRow, "cooldowns", "Cooldowns", { "CENTER", "CENTER", 0, -210 })
end

local function setCooldown(f, def)
    if C_Spell.GetSpellCooldownDuration then
        local ok, d = pcall(C_Spell.GetSpellCooldownDuration, def.id, true)   -- true: ignore the GCD
        if ok and d and pcall(f.cd.SetCooldownFromDurationObject, f.cd, d, true) then return end
    end
    local ok, info = pcall(C_Spell.GetSpellCooldown, def.id)
    if ok and info then
        local start, dur = NS.Readable(info.startTime), NS.Readable(info.duration)
        if start and dur and dur > 1.5 then f.cd:SetCooldown(start, dur) else f.cd:Clear() end   -- 1.5: skip the GCD
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
            f.icon:SetTexture(Spells:Get(f.shock or f.key).icon or "Interface\\Icons\\INV_Misc_QuestionMark")
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
        local iconKey = SHOCKS[key] and "earthShock" or key   -- shocks share one cooldown
        for _, f in ipairs(cdIcons) do if f.key == iconKey then f.armed = true end end
        local cd = NS.db.learned.cooldowns[iconKey] or BASE_CD[iconKey]
        if cd then cdEnd[iconKey] = GetTime() + cd end
        if key == "stormstrike" then
            bonusUntil = GetTime() + BONUS_WINDOW
        elseif SPENDS_BONUS[key] then
            bonusUntil = 0
        end
        if key == "flameShock" then self:StartFlameShock() end
        self:Advise()
    end)
    NS:OnUnit("UNIT_AURA", "target", function() readTargetFlameShock(); self:Advise() end)
    NS:On("PLAYER_TARGET_CHANGED", function()
        targetChanged()
        readTargetFlameShock()
        if fs.ends > GetTime() and NS:IsEnabled("shocks") and NS.db.shocks.flameShock then UI:SafeShow(fsBar, true) end
        if self.native then self.native:Refresh() end
        self:Advise()
    end)
    self.native:Build()
    NS:On("PLAYER_REGEN_DISABLED", function() self:Advise() end)
    NS:On("PLAYER_REGEN_ENABLED", function()
        bonusUntil = 0
        wipe(fsBy)
        if fs.ends > GetTime() and not UnitExists("target") then fs.ends = 0 end
        self:Advise()
    end)
    NS:On("SPELL_UPDATE_COOLDOWN", function() self:UpdateCooldowns() end)
    NS:On("SPELL_UPDATE_USABLE", function() self:UpdateCooldowns() end)
    NS:On("SF_SPELLS", function() self:UpdateCooldowns(); self:Advise() end)
end

function Shocks:Apply()
    if not prompt then return end
    local db = NS.db.shocks
    local on = NS:IsEnabled("shocks")
    fsBar:SetWidth(db.barWidth)
    fsBar.bar:SetWidth(db.barWidth - FS_H - 2)
    local native = self.native and self.native:Active()
    UI:SafeShow(fsBar, on and db.flameShock and (native or NS.editing or fs.ends > GetTime()))
    if native then
        self.native:Restyle(function(b)
            b:SetSize(db.barWidth, FS_H)
            if Shocks.nativeBar then Shocks.nativeBar:SetSize(db.barWidth - FS_H - 2, FS_H) end
        end)
    end
    self:UpdateCooldowns()
    self:Advise()
end
