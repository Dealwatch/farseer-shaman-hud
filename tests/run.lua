--[[
    Offline smoke test: loads the addon into a fake WoW client and drives it
    through login, every settings page, edit mode, combat (with secret values)
    and the diagnostics. Any Lua error fails the run.

        lua5.1 tests/run.lua
]]

local ROOT = (arg and arg[0] or ""):match("^(.*)tests[/\\]run%.lua$") or "./"

---------------------------------------------------------------------------
-- Secret values: userdata that errors on comparison, arithmetic, concat
---------------------------------------------------------------------------

local secrets = setmetatable({}, { __mode = "k" })
local function secret()
    local u = newproxy(true)
    local mt = getmetatable(u)
    local function boom() error("secret value used in logic", 2) end
    mt.__lt, mt.__le, mt.__add, mt.__sub, mt.__mul, mt.__div, mt.__concat, mt.__unm = boom, boom, boom, boom, boom, boom, boom, boom
    mt.__tostring = boom
    mt.__index = boom
    secrets[u] = true
    return u
end
function issecretvalue(v) return secrets[v] == true end

local combat = false
local function S(v) if combat then return secret() end return v end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

local now = 1000
local eventFrames = {}     -- event -> { frame = true }
local unitEventFrames = {}
local allFrames = {}

local Object = {}
Object.__index = function(self, k)
    local m = Object[k]
    if m ~= nil then return m end
    if type(k) == "string" and k:match("^%u") then
        return function() end   -- unknown widget method: no-op
    end
end

local function newObject(kind, parent)
    local o = setmetatable({ _kind = kind, _shown = true, _w = 0, _h = 0, _parent = parent, _scripts = {}, _attr = {}, _alpha = 1, _min = 0, _max = 1, _val = 0, _scroll = 0 }, Object)
    allFrames[#allFrames + 1] = o
    return o
end

function Object:SetSize(w, h) self._w, self._h = w, h end
function Object:SetWidth(w) self._w = w end
function Object:SetHeight(h) self._h = h end
function Object:GetWidth() return self._w end
function Object:GetHeight() return self._h end
function Object:GetSize() return self._w, self._h end
function Object:Show() self._shown = true end
function Object:Hide()
    local was = self._shown
    self._shown = false
    if was and self._scripts.OnHide then self._scripts.OnHide(self) end
end
function Object:SetShown(v) if v then self:Show() else self:Hide() end end
function Object:IsShown() return self._shown end
function Object:IsVisible() return self._shown end
function Object:SetScript(name, fn) self._scripts[name] = fn end
function Object:GetScript(name) return self._scripts[name] end
function Object:HookScript(name, fn) self._scripts[name] = fn end
function Object:GetCenter() return 500, 400 end
function Object:GetEffectiveScale() return 1 end
function Object:GetScale() return 1 end
function Object:GetFrameLevel() return 1 end
function Object:GetParent() return self._parent end
function Object:SetAttribute(k, v) self._attr[k] = v end
function Object:GetAttribute(k) return self._attr[k] end
function Object:SetAlpha(a) self._alpha = a end
function Object:GetAlpha() return self._alpha end
function Object:SetMinMaxValues(a, b) self._min, self._max = a, b end
function Object:GetMinMaxValues() return self._min, self._max end
function Object:SetValue(v)
    assert(not issecretvalue(v) or self._kind == "StatusBar", "secret into non-statusbar")
    self._val = v
    if self._scripts.OnValueChanged then self._scripts.OnValueChanged(self, v, false) end
end
function Object:GetValue() return self._val end
function Object:SetText(t) self._text = t end
function Object:GetText() return self._text end
function Object:SetFont() return true end
function Object:GetVerticalScroll() return self._scroll end
function Object:SetVerticalScroll(v) self._scroll = v end
function Object:SetScrollChild(c) self._child = c end
function Object:GetScrollChild() return self._child end
function Object:GetThumbTexture() return self._thumb end
function Object:SetThumbTexture() self._thumb = newObject("Texture", self) end
function Object:RegisterEvent(e)
    eventFrames[e] = eventFrames[e] or {}
    eventFrames[e][self] = true
end
function Object:RegisterUnitEvent(e, unit)
    unitEventFrames[e] = unitEventFrames[e] or {}
    unitEventFrames[e][self] = unit
end
function Object:CreateTexture() return newObject("Texture", self) end
function Object:CreateFontString() return newObject("FontString", self) end
function Object:CreateAnimationGroup() return newObject("AnimationGroup", self) end
function Object:CreateAnimation() return newObject("Animation", self) end
function Object:SetCooldown(start, dur)
    assert(type(start) == "number" and type(dur) == "number", "SetCooldown needs numbers")
end
function Object:SetCooldownFromDurationObject(d) assert(type(d) == "table" and d._duration, "needs duration object") end
function Object:SetTimerDuration(d) assert(type(d) == "table" and d._duration, "needs duration object") end
function Object:SetTexture(t) self._tex = t end
function Object:IsMouseOver() return false end

function CreateFrame(kind, name, parent, template)
    local f = newObject(kind, parent)
    if name then _G[name] = f end
    f._template = template
    return f
end

UIParent = newObject("Frame")
UIParent._w, UIParent._h = 1920, 1080
GameTooltip = newObject("GameTooltip")
ChatFontNormal = {}
UISpecialFrames = {}
SlashCmdList = {}
SOUNDKIT = { RAID_WARNING = 8959, ALARM_CLOCK_WARNING_2 = 18871, ALARM_CLOCK_WARNING_3 = 12889, IG_MAINMENU_OPTION_CHECKBOX_ON = 856 }

---------------------------------------------------------------------------
-- Client API
---------------------------------------------------------------------------

local errors = {}
function geterrorhandler() return function(e) errors[#errors + 1] = e; print("ERROR: " .. tostring(e)) end end
function GetTime() return now end
function date(fmt) return os.date(fmt) end
function GetLocale() return "enUS" end
function GetBuildInfo() return "1.60.1", "70862", "Nov 7 2026", 16001 end
function UnitClass() return "Shaman", "SHAMAN" end
function UnitLevel() return 40 end
function UnitName(u) if u == "target" then return S("Kobold Miner") end return "Tester" end
function UnitExists() return true end
function UnitAffectingCombat() return combat end
function UnitIsDeadOrGhost() return false end
function IsMounted() return false end
function IsShiftKeyDown() return false end
function InCombatLockdown() return combat end
function UnitCastingInfo() return nil end
function GetShapeshiftForm() return S(0) end
function GetInventoryItemID(_, slot) return 1000 + slot end
function PlaySound() end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
unpack = unpack or table.unpack

local SPELLS = {
    [17364] = "Stormstrike", [8042] = "Earth Shock", [8050] = "Flame Shock", [8056] = "Frost Shock",
    [403] = "Lightning Bolt", [324] = "Lightning Shield", [8232] = "Windfury Weapon", [8024] = "Flametongue Weapon",
    [2645] = "Ghost Wolf", [20608] = "Reincarnation", [3599] = "Searing Totem", [8075] = "Strength of Earth Totem",
    [53817] = "Maelstrom Weapon", [90001] = "Rage of the Farseer",
}
-- player knows these (spellbook, Forever-style unknown ID for Rage of the Farseer)
local BOOK = { 17364, 8042, 8050, 403, 324, 8232, 8024, 2645, 20608, 3599, 8075, 90001 }

C_Spell = {
    GetSpellName = function(id) return SPELLS[id] end,
    GetSpellTexture = function(id) return SPELLS[id] and 1000 + id end,
    GetSpellCooldown = function() return { startTime = S(0), duration = S(0) } end,
    GetSpellCooldownDuration = function() return { _duration = true } end,
    IsSpellUsable = function() return true, false end,
    GetSpellDisplayCount = function() return S("") end,
    GetSpellCastCount = function() return S(0) end,
}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { name = "Enhancement", itemIndexOffset = 0, numSpellBookItems = #BOOK } end,
    GetSpellBookItemInfo = function(i) local id = BOOK[i]; return id and { name = SPELLS[id], spellID = id, actionID = id, subName = "", isPassive = false } end,
    IsSpellKnown = function(id) for _, b in ipairs(BOOK) do if b == id then return true end end return false end,
}
local playerAuras = {}
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, i)
        local a = unit == "player" and playerAuras[i]
        if not a then return nil end
        if combat and not a.whitelisted then return { name = secret(), spellId = secret(), applications = secret() } end
        return a
    end,
    GetPlayerAuraBySpellID = function(id)
        for _, a in ipairs(playerAuras) do if a.spellId == id and (a.whitelisted or not combat) then return a end end
    end,
    GetAuraDataBySpellName = function(unit, name)
        if combat then return nil end
        for _, a in ipairs(unit == "player" and playerAuras or {}) do if a.name == name then return a end end
    end,
}
C_Secrets = { ShouldAurasBeSecret = function() return combat end, ShouldCooldownsBeSecret = function() return combat end }
C_Item = {
    GetItemCount = function() return 0 end,
    GetWeaponEnchantInfo = function(slot)
        return { { hasEnchant = true, enchantType = 1, timeLeft = 0, charges = 0, enchantID = 1 },
                 { hasEnchant = slot == 0, enchantType = 3, timeLeft = 50 * 60 * 1000, charges = 0, enchantID = 283 } }
    end,
}
C_PaperDollInfo = { OffhandHasWeapon = function() return true end }
C_SwingTimer = { EnableRangeCheck = function() end, IsTargetWithinSwingRange = function() return S(true) end }
C_SpellActivationOverlay = { IsSpellOverlayed = function() return false end }
C_AddOns = { GetAddOnMetadata = function() return "0.1.0-test" end }
local timers = {}
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function(_, fn) timers[#timers + 1] = fn; return { Cancel = function() end } end,
}
local totems = {}
function GetTotemInfo(slot)
    local t = totems[slot]
    if combat then return secret(), secret(), secret(), secret(), secret() end
    if t then return true, t.name, now - 5, 300, 1234 end
    return false, "", 0, 0, 0
end
function GetTotemDuration() return { _duration = true } end
Enum = {
    PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 },
    SpellBookSpellBank = { Player = 0, Pet = 1 },
    WeaponSlot = { MainHand = 0, OffHand = 1 },
    ItemEnchantType = { None = 0, Permanent = 1, Temporary = 2, Imbue = 3 },
    StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
    StatusBarInterpolation = { Immediate = 0 },
}

---------------------------------------------------------------------------
-- Driver
---------------------------------------------------------------------------

local function fire(event, ...)
    for f in pairs(eventFrames[event] or {}) do
        local fn = f._scripts.OnEvent
        if fn then fn(f, event, ...) end
    end
    for f, unit in pairs(unitEventFrames[event] or {}) do
        local u = ...
        if u == unit then
            local fn = f._scripts.OnEvent
            if fn then fn(f, event, ...) end
        end
    end
end

local function runTimers()
    local list = timers
    timers = {}
    for _, fn in ipairs(list) do fn() end
end

local function tick(dt)
    now = now + (dt or 0.1)
    for _, f in ipairs(allFrames) do
        if f._shown and f._scripts.OnUpdate then f._scripts.OnUpdate(f, dt or 0.1) end
    end
end

-- load the addon in TOC order
local NS = {}
local toc = assert(io.open(ROOT .. "ShammyForever.toc")):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        local path = ROOT .. line:gsub("\\", "/")
        local chunk = assert(loadfile(path))
        chunk("ShammyForever", NS)
    end
end

local step
local function check(name)
    if #errors > 0 then
        print(("FAIL after step '%s': %d error(s)"):format(name, #errors))
        os.exit(1)
    end
    print("ok  " .. name)
end
local function run(name, fn)
    step = name
    local ok, err = pcall(fn)
    if not ok then errors[#errors + 1] = err; print("ERROR: " .. tostring(err)) end
    runTimers()
    check(name)
end

run("login", function()
    fire("PLAYER_LOGIN")
    fire("PLAYER_ENTERING_WORLD")
    assert(NS.db and NS.isShaman, "db/shaman")
    assert(NS.Spells:Get("stormstrike").known, "stormstrike resolved")
    assert(NS.Spells:Get("rageFarseer").known and NS.Spells:Get("rageFarseer").id == 90001, "resolved by name from spellbook")
    assert(not NS.Spells:Get("chainLightning").known, "unknown spell stays unknown")
end)

run("settings window, every page", function()
    SlashCmdList.SHAMMYFOREVER("")
    for _, key in ipairs({ "overview", "swing", "totems", "imbues", "maelstrom", "shocks", "reminders", "appearance" }) do
        NS.Options:Show(key)
    end
    NS.Options:Toggle()
end)

run("settings change", function()
    NS.db.appearance.accent = "fire"
    NS.UI:ApplyAppearance()
    NS:SetModuleEnabled("totems", false)
    NS:SetModuleEnabled("totems", true)
    NS.db.swing.width = 300
    NS:ApplyAll()
end)

run("edit mode", function()
    SlashCmdList.SHAMMYFOREVER("edit")
    tick(0.1)
    NS.Movers:Toggle(false)
end)

run("out of combat events", function()
    totems[2] = { name = "Strength of Earth Totem" }
    fire("PLAYER_TOTEM_UPDATE", 2)
    playerAuras[1] = { name = "Lightning Shield", spellId = 324, applications = 3, duration = 600 }
    fire("UNIT_AURA", "player", {})
    assert(NS.modules.reminders.ShieldState() == true, "shield read")
    assert(NS.modules.imbues.Read({ key = "mh", inv = 16, slot = 0 }) == true, "mh imbue (imbue entry, not the stone)")
    assert(NS.modules.imbues.Read({ key = "oh", inv = 17, slot = 1 }) == false, "oh imbue missing")
    assert(NS.Alerts.active.imbueoh, "missing off hand imbue alert")
    SlashCmdList.SHAMMYFOREVER("probe")
    SlashCmdList.SHAMMYFOREVER("spells")
    SlashCmdList.SHAMMYFOREVER("test")
end)

run("combat with secrets", function()
    fire("PLAYER_REGEN_DISABLED")
    combat = true
    fire("PLAYER_ENTER_COMBAT")
    fire("PLAYER_SWING", 2.6, 0)
    fire("PLAYER_SWING", 1.8, 1)
    tick(0.5)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 17364)   -- Stormstrike
    assert(NS.modules.shocks and _G.ShammyForeverShockPrompt:IsShown(), "shock prompt shown")
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8050)    -- Flame Shock
    assert(not _G.ShammyForeverShockPrompt:IsShown(), "prompt cleared by shock")
    assert(_G.ShammyForeverFlameShock:IsShown(), "flame shock bar")
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 3599)    -- Searing Totem
    fire("PLAYER_TOTEM_UPDATE", 1)
    fire("SPELL_UPDATE_COOLDOWN")
    fire("UNIT_AURA", "player", {})
    fire("UNIT_AURA", "target", {})
    fire("PLAYER_TARGET_CHANGED")
    fire("PLAYER_SWING_RANGE_UPDATE", 0, false, true)
    tick(0.2)
    -- Maelstrom: whitelisted aura readable in combat
    playerAuras[2] = { name = "Maelstrom Weapon", spellId = 53817, applications = 5, whitelisted = true }
    fire("UNIT_AURA", "player", {})
    assert(NS.modules.maelstrom.state.full and NS.modules.maelstrom.state.source == "aura", "maelstrom exact")
    -- not whitelisted: falls back to the proc glow
    playerAuras[2].whitelisted = false
    fire("UNIT_AURA", "player", {})
    fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 403)
    assert(NS.modules.maelstrom.state.full and NS.modules.maelstrom.state.source == "proc", "maelstrom via glow")
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 403)
    assert(not NS.modules.maelstrom.state.full, "bolt consumed")
    SlashCmdList.SHAMMYFOREVER("probe")
    NS.Options:Show("overview")
    tick(1)
end)

run("leave combat", function()
    combat = false
    fire("PLAYER_LEAVE_COMBAT")
    fire("PLAYER_REGEN_ENABLED")
    tick(2)
    assert(NS.db.probe.combat and NS.db.probe.outOfCombat and NS.db.probe.spells, "probe saved")
end)

run("reset", function()
    SlashCmdList.SHAMMYFOREVER("reset confirm")
end)

print("all good")
