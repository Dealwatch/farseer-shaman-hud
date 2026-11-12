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
        if k:match("^Set") then
            -- unknown setter: remember the last arguments so tests can see what changed
            return function(o, ...)
                local key = k == "SetPoint" and k .. tostring((...)) or k
                rawget(o, "_calls")[key] = { ... }
            end
        end
        return function() end   -- unknown widget method: no-op
    end
end

local function newObject(kind, parent)
    local o = setmetatable({ _kind = kind, _shown = true, _w = 0, _h = 0, _parent = parent, _scripts = {}, _attr = {}, _calls = {}, _alpha = 1, _min = 0, _max = 1, _val = 0, _scroll = 0 }, Object)
    allFrames[#allFrames + 1] = o
    o._id = #allFrames
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
function Object:SetFont(...) self._calls.SetFont = { ... }; return true end
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

-- Blizzard_AuraContainer (CustomAuraContainerTemplate)
local function kindIs(o, kind) return type(o) == "table" and o._kind == kind end
function Object:AddAuraSlot(key, filter, opts)
    assert(type(key) == "string" and type(filter) == "string", "slot key/filter")
    local ids = opts and opts.candidateFilters and opts.candidateFilters.includeSpellIDs
    assert(type(ids) == "table" and next(ids), "includeSpellIDs map")
    self._ids = ids
    local b = newObject("Button", self)
    if opts.initializeFrame then opts.initializeFrame(b) end
    return b
end
function Object:AddAuraGroup(key, filter, opts)
    assert(type(key) == "string" and type(filter) == "string", "group key/filter")
    local ids = opts and opts.candidateFilters and opts.candidateFilters.includeSpellIDs
    assert(type(ids) == "table" and next(ids), "group includeSpellIDs map")
    assert(opts.layout and opts.layout.elementWidth, "group layout")
    self._ids = ids
    for _ = 1, 2 do opts.initializeFrame(newObject("Button", self)) end
end
function Object:SetApplicationBar(bar, o) assert(kindIs(bar, "StatusBar") and o and o.maxApplications, "application bar") end
function Object:SetApplicationCount(fs) assert(kindIs(fs, "FontString"), "application count") end
function Object:SetDurationBar(bar) assert(kindIs(bar, "StatusBar"), "duration bar") end
function Object:SetDurationText(fs) assert(kindIs(fs, "FontString"), "duration text") end
function Object:SetDurationCooldown(cd) assert(kindIs(cd, "Cooldown"), "duration cooldown") end
function Object:SetIcon(t) assert(kindIs(t, "Texture"), "icon texture") end
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
-- current cast / channel: { name, tex, startMS, endMS }; values are secret in combat
local casting, channeling
function UnitCastingInfo()
    if not casting then return nil end
    return S(casting[1]), S(casting[1]), S(casting[2]), S(casting[3]), S(casting[4])
end
function UnitChannelInfo()
    if not channeling then return nil end
    return S(channeling[1]), S(channeling[1]), S(channeling[2]), S(channeling[3]), S(channeling[4])
end
function UnitCastingDuration() if casting then return { _duration = true } end end
function UnitChannelDuration() if channeling then return { _duration = true } end end
function GetShapeshiftForm() return S(0) end
function GetInventoryItemID(_, slot) return 1000 + slot end
GetBindingKey = function() return nil end
local mana = 1000
function UnitPower() return S(mana) end
function UnitPowerMax() return S(1000) end
function UnitCanAttack() return S(true) end
function PlaySound() end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
unpack = unpack or table.unpack

local SPELLS = {
    [17364] = "Stormstrike", [8042] = "Earth Shock", [8050] = "Flame Shock", [8056] = "Frost Shock",
    [403] = "Lightning Bolt", [324] = "Lightning Shield", [8232] = "Windfury Weapon", [8024] = "Flametongue Weapon",
    [2645] = "Ghost Wolf", [20608] = "Reincarnation", [3599] = "Searing Totem", [8075] = "Strength of Earth Totem",
    [53817] = "Maelstrom Weapon", [90001] = "Rage of the Farseer",
    [66842] = "Call of the Elements", [36936] = "Totemic Recall",
    [408341] = "Fire Nova", [8190] = "Magma Totem",
}
-- player knows these (spellbook, Forever-style unknown ID for Rage of the Farseer)
local BOOK = { 17364, 8042, 8050, 403, 324, 8232, 8024, 2645, 20608, 3599, 8075, 90001, 66842, 36936, 408341, 8190 }

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
local cvars = { showSwingTimer = "1" }
C_CVar = {
    GetCVar = function(k) return cvars[k] end,
    GetCVarBool = function(k) return cvars[k] == "1" end,
    SetCVar = function(k, v) cvars[k] = v end,
}
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

PlayerCastingBarFrame = CreateFrame("Frame", "PlayerCastingBarFrame", UIParent)

-- load the addon in TOC order
local NS = {}
local toc = assert(io.open(ROOT .. "FarseerShamanHUD.toc")):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        local path = ROOT .. line:gsub("\\", "/")
        local chunk = assert(loadfile(path))
        chunk("FarseerShamanHUD", NS)
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
    for _, key in ipairs({ "maelstrom", "flameshock", "shield", "procs" }) do
        assert(NS.Native.slots[key]:Active(), "native slot " .. key)
    end
    assert(NS.Native.slots.maelstrom.container._ids[408505], "maelstrom buff id in filter")
    assert(NS.Native.slots.flameshock.container._ids[10448], "flame shock ranks in filter")
    assert(NS.Native.slots.procs.container._ids[16257] and NS.Native.slots.procs.container._ids[425336], "proc ids in filter")
    assert(_G.FarseerHUDImbues:GetParent() == UIParent, "imbues stay outside the HUD root")
end)

run("cast bar", function()
    local cb = _G.FarseerHUDCastBar
    local mod = NS.modules.castbar
    assert(not PlayerCastingBarFrame:IsShown(), "Blizzard's cast bar hidden")
    assert(not cb:IsShown(), "no cast, no bar")
    assert(cb:GetParent() == UIParent, "cast bar shows while the HUD is hidden")

    casting = { "Healing Wave", 136052, now * 1000, now * 1000 + 2500 }
    fire("UNIT_SPELLCAST_START", "player", "cast-1", 331)
    assert(cb:IsShown() and mod.bar.name:GetText() == "Healing Wave", "cast shown")
    tick(1)
    assert(mod.bar.time:GetText() == "1.5", "time left: " .. tostring(mod.bar.time:GetText()))
    fire("UNIT_SPELLCAST_FAILED", "player", "other", 8042)   -- Earth Shock pressed while casting
    assert(mod.state.active and mod.bar.name:GetText() == "Healing Wave", "another spell failing is not ours")
    casting = nil
    fire("UNIT_SPELLCAST_STOP", "player", "cast-1", 331)
    assert(cb:IsShown(), "stays up a moment after the cast")
    tick(0.5)
    assert(not cb:IsShown(), "gone after the cast")

    casting = { "Ghost Wolf", 136095, now * 1000, now * 1000 + 3000 }
    fire("UNIT_SPELLCAST_START", "player", "cast-2", 2645)
    casting = nil
    fire("UNIT_SPELLCAST_INTERRUPTED", "player", "cast-2", 2645)
    fire("UNIT_SPELLCAST_FAILED", "player", "cast-2", 2645)
    fire("UNIT_SPELLCAST_STOP", "player", "cast-2", 2645)
    assert(cb:IsShown() and mod.bar.name:GetText() == "Interrupted", "interrupted shown")
    tick(0.5)
    assert(cb:IsShown(), "interrupt stays up a bit longer")
    tick(0.7)
    assert(not cb:IsShown(), "interrupt gone")

    channeling = { "Drain", 136000, now * 1000, now * 1000 + 3000 }
    fire("UNIT_SPELLCAST_CHANNEL_START", "player", nil, 1)
    assert(cb:IsShown() and mod.state.channel, "channel shown")
    channeling = nil
    fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", nil, 1)
    tick(0.5)
    assert(not cb:IsShown(), "channel gone")

    -- in combat the cast values are secret: bar still runs, no time text, no error
    combat = true
    casting = { "Lightning Bolt", 136048, now * 1000, now * 1000 + 2000 }
    fire("UNIT_SPELLCAST_START", "player", "cast-3", 403)
    assert(cb:IsShown() and mod.state.native, "secret cast runs on the duration object")
    tick(0.5)
    assert(mod.bar.time:GetText() == "", "no time text from secret values")
    casting = nil
    fire("UNIT_SPELLCAST_STOP", "player", "cast-3", 403)
    tick(0.5)
    assert(not cb:IsShown(), "secret cast gone")
    combat = false
end)

run("settings window, every page", function()
    SlashCmdList.FARSEERHUD("")
    for _, key in ipairs({ "overview", "rotation", "swing", "mana", "totems", "imbues", "maelstrom", "procs", "shocks", "reminders", "appearance" }) do
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
    SlashCmdList.FARSEERHUD("edit")
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
    SlashCmdList.FARSEERHUD("probe")
    SlashCmdList.FARSEERHUD("spells")
    SlashCmdList.FARSEERHUD("test")
end)

run("low level: unknown imbue falls back to a known one", function()
    NS.db.imbues.mh = "frostbrand"   -- not in the test spellbook
    local def = NS.modules.imbues.ChosenSpell({ key = "mh" })
    assert(def and def.key == "windfury", "falls back to the first known imbue")
    NS.db.imbues.mh = "windfury"
    assert(_G.FarseerHUDTotemEarth:IsShown() and _G.FarseerHUDTotemFire:IsShown(), "known elements shown")
    assert(not _G.FarseerHUDTotemWater:IsShown() and not _G.FarseerHUDTotemAir:IsShown(), "unknown elements hidden")
    assert(not _G.FarseerHUDMaelstrom:IsShown(), "no Maelstrom bar before the talent")
end)

run("fishing pole: no main hand imbue warning", function()
    local old = C_Item.GetWeaponEnchantInfo
    C_Item.GetWeaponEnchantInfo = function() return {} end
    C_Item.GetItemInfoInstant = function(id) return id, "Weapon", "Fishing Poles", "INVTYPE_2HWEAPON", 1, 2, 20 end
    NS.modules.imbues:Update()
    assert(not NS.Alerts.active.imbuemh, "no alert with a fishing pole")
    C_Item.GetItemInfoInstant = nil
    NS.modules.imbues:Update()
    assert(NS.Alerts.active.imbuemh, "alert with a real weapon")
    C_Item.GetWeaponEnchantInfo = old
    NS.modules.imbues:Update()
end)

run("mana bar", function()
    mana = 1000
    NS.modules.mana:Update()
    assert(not _G.FarseerHUDMana:IsShown(), "hidden at full mana out of combat")
    mana = 200
    NS.modules.mana:Update()
    assert(_G.FarseerHUDMana:IsShown(), "shown when not full")
    assert(NS.modules.mana.Fraction() == 0.2, "fraction")
end)

run("combat with secrets", function()
    fire("PLAYER_REGEN_DISABLED")
    combat = true
    fire("PLAYER_ENTER_COMBAT")
    fire("PLAYER_SWING", 2.6, 0)
    fire("PLAYER_SWING", 1.8, 1)
    tick(0.5)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 17364)   -- Stormstrike
    assert(not _G.FarseerHUDShockPrompt:IsShown(), "no card by default: the icon glows")
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8050)    -- Flame Shock
    fire("UNIT_POWER_FREQUENT", "player", "MANA")               -- secret mana in combat
    assert(_G.FarseerHUDFlameShock:IsShown() and _G.FarseerHUDFlameShock:GetAlpha() == 1, "flame shock bar")
    assert(NS.UI.root:GetAlpha() == 1, "HUD not faded in combat")
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 3599)    -- Searing Totem
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 66842)   -- Call of the Elements (secret totem info)
    fire("PLAYER_TOTEM_UPDATE", 3)
    fire("PLAYER_TOTEM_UPDATE", 4)
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
    SlashCmdList.FARSEERHUD("probe")
    NS.Options:Show("overview")
    tick(1)
end)

run("leave combat", function()
    combat = false
    fire("PLAYER_LEAVE_COMBAT")
    fire("PLAYER_REGEN_ENABLED")
    tick(2)
    assert(NS.db.probe.combat and NS.db.probe.outOfCombat and NS.db.probe.spells, "probe saved")
    assert(NS.Alerts.active.recall, "Totemic Recall reminder after combat with totems down")
    totems[2] = nil
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 36936)   -- Totemic Recall
    assert(not NS.Alerts.active.recall, "reminder cleared by the recall")
    fire("PLAYER_TOTEM_UPDATE", 2)
    assert(not NS.Alerts.active.totem2, "no 'totem is gone' alert after Totemic Recall")
    _G.FarseerHUDOptions:Hide()   -- an open settings window keeps the HUD visible
    UnitCanAttack = function() return false end
    fire("PLAYER_TARGET_CHANGED")
    assert(not NS.UI.root:IsShown(), "HUD hidden out of combat without an enemy")
    UnitCanAttack = function() return true end
    fire("PLAYER_TARGET_CHANGED")
    assert(NS.UI.root:IsShown() and NS.UI.root:GetAlpha() == 1, "enemy targeted out of combat: HUD shown")
end)

-- Regressions reported from the Mage HUD review (combat start happens BEFORE lockdown:
-- PLAYER_REGEN_DISABLED fires while InCombatLockdown() is still false).
run("regression: pull with 0 Maelstrom stacks keeps the bar", function()
    NS.db.learned.maelstromBuffID = NS.db.learned.maelstromBuffID or 408505
    playerAuras[2] = nil
    fire("UNIT_AURA", "player", {})
    fire("PLAYER_REGEN_DISABLED")            -- not locked yet
    combat = true
    fire("UNIT_AURA", "player", {})
    local f = _G.FarseerHUDMaelstrom
    assert(f:IsShown() and f:GetAlpha() == 1, "Maelstrom bar visible in combat after a 0-stack pull")
    combat = false
    fire("PLAYER_REGEN_ENABLED")
end)

run("regression: edit mode open at the pull", function()
    UnitCanAttack = function() return false end
    NS.Movers:Toggle(true)
    fire("PLAYER_REGEN_DISABLED")
    combat = true
    assert(NS.UI.root:IsShown(), "HUD root shown in combat although edit mode was open at the pull")
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    UnitCanAttack = function() return true end
end)

run("regression: auras secret out of combat (BG / encounter)", function()
    local old = C_Secrets.ShouldAurasBeSecret
    C_Secrets.ShouldAurasBeSecret = function() return true end
    local h = NS.Native:Slot({ key = "regress", parent = CreateFrame("Frame"), unit = "player", filter = "HELPFUL",
        ids = function() return { 324 } end, init = function() end })
    h:Build()                 -- must not recurse forever
    fire("SF_SPELLS")         -- refilter every slot while secret
    assert(not h:Active(), "not built while secret")
    C_Secrets.ShouldAurasBeSecret = old
end)

run("mana red below threshold with secret values (colour curve)", function()
    local colour
    C_CurveUtil = { CreateColorCurve = function()
        local pts = {}
        return { SetType = function() end, AddPoint = function(self, x, c) pts[#pts + 1] = { x, c } end, _pts = pts }
    end }
    CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, GetRGB = function(self) return self.r, self.g, self.b end } end
    UnitPowerPercent = function(_, _, _, crv) local p = mana / 1000; local pick = crv._pts[1][2]
        for _, pt in ipairs(crv._pts) do if p >= pt[1] then pick = pt[2] end end; return pick end
    local bar = NS.modules.mana.bar
    local orig = bar.SetStatusBarColor
    bar.SetStatusBarColor = function(self, r, g, b) colour = { r, g, b } end
    NS.modules.mana:Apply()
    combat = true
    mana = 100
    NS.modules.mana:Update()
    assert(colour and colour[1] > 0.9 and colour[3] < 0.5, "red in combat below 25% via the curve")
    mana = 900
    NS.modules.mana:Update()
    assert(colour[3] > 0.9, "blue above the threshold")
    combat = false
    bar.SetStatusBarColor = orig
end)

run("cooldown ready flash", function()
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8050)   -- Flame Shock arms the shared shock icon
    local icon
    for _, f in ipairs(NS.modules.shocks.cdIcons) do if f.key == "earthShock" then icon = f end end
    assert(icon.armed, "shock icon armed by Flame Shock")
    icon.cd._scripts.OnCooldownDone(icon.cd)
    assert(icon.sfFlash and icon.sfFlash:IsShown(), "icon flashes when ready")
    assert(not icon.armed, "flashes only once")
end)

run("regression: every settings slider saves and applies", function()
    -- drive the real settings page, not a stand-in widget
    NS.Options:Show("shocks")
    local pages
    for i = 1, 20 do
        local name, v = debug.getupvalue(NS.Options.Show, i)
        if name == "pages" then pages = v end
    end
    local slider
    for _, p in ipairs(pages) do
        if p.key == "shocks" then
            for _, card in ipairs(p.blocks) do
                for _, r in ipairs(card.rows or {}) do
                    if r.label and r.label:GetText() == "Cooldown icon size" then slider = r.slider end
                end
            end
        end
    end
    assert(slider, "cooldown icon size slider found")
    for _, p in ipairs(pages) do
        NS.Options:Show(p.key)
        for _, card in ipairs(p.blocks) do
            for _, r in ipairs(card.rows or {}) do
                if r.slider then
                    local lo, hi = r.slider:GetMinMaxValues()
                    local before = r.slider:GetValue()
                    local v = before == hi and lo or hi
                    r.slider._scripts.OnValueChanged(r.slider, v)
                    assert(r.slider:GetValue() == v, "slider '" .. r.label:GetText() .. "' on " .. p.key .. " saves")
                    r.slider._scripts.OnValueChanged(r.slider, before)
                end
            end
        end
    end
    NS.Options:Show("shocks")
    slider._scripts.OnValueChanged(slider, 44)   -- what the client sends while dragging
    assert(NS.db.shocks.iconSize == 44, "slider value saved")
    local icon = NS.modules.shocks.cdIcons[1]
    assert(icon:GetWidth() == 44, "cooldown icons resized")
    _G.FarseerHUDOptions:Hide()
end)

run("every setting changes something on screen", function()
    local function upv(fn, name)
        for i = 1, 60 do
            local n, v = debug.getupvalue(fn, i)
            if not n then return end
            if n == name then return v end
        end
    end
    local function ser(v)
        if issecretvalue(v) then return "secret" end
        if type(v) ~= "table" then return tostring(v) end
        if v._id then return "#" .. v._id end
        return table.concat({ tostring(v[1] or v.r), tostring(v[2] or v.g), tostring(v[3] or v.b), tostring(v[4] or v.a) }, ",")
    end
    local opts = _G.FarseerHUDOptions
    local function hud(o)
        local p = o
        while p do
            if p == opts then return false end
            p = p._parent
        end
        return true
    end
    local function snap()
        local out = {}
        for _, o in ipairs(allFrames) do
            if hud(o) then
                local parts = { ser(o._w), ser(o._h), tostring(o._shown), ser(o._alpha), ser(o._val), ser(o._text), ser(o._min), ser(o._max) }
                local keys = {}
                for k in pairs(o._calls) do keys[#keys + 1] = k end
                table.sort(keys)
                for _, k in ipairs(keys) do
                    local a = {}
                    for i, v in ipairs(o._calls[k]) do a[i] = ser(v) end
                    parts[#parts + 1] = k .. "(" .. table.concat(a, ",") .. ")"
                end
                out[o._id] = table.concat(parts, "|")
            end
        end
        return out
    end
    local function changed(a, b)
        local n = 0
        for id, v in pairs(b) do if a[id] ~= v then n = n + 1 end end
        return n
    end

    local pages
    for i = 1, 20 do
        local name, v = debug.getupvalue(NS.Options.Show, i)
        if name == "pages" then pages = v end
    end
    local controls = {}
    local function add(label, get, set, alt)
        controls[#controls + 1] = { label = label, get = get, set = set, alt = alt }
    end
    for _, p in ipairs(pages) do
        NS.Options:Show(p.key)
        for _, card in ipairs(p.blocks) do
            if card.switch and card.title then
                local click = card.switch._scripts.OnClick
                add(p.key .. ": [" .. card.title:GetText() .. "]", upv(click, "get"), upv(click, "set"))
            end
            for _, r in ipairs(card.rows or {}) do
                local label = p.key .. ": " .. (r.label and r.label:GetText() or "?")
                if r.slider then
                    local fn = r.slider._scripts.OnValueChanged
                    local lo, hi = r.slider:GetMinMaxValues()
                    add(label, upv(fn, "get"), upv(fn, "set"), function(v) return v == hi and lo or hi end)
                elseif r.switch then
                    local click = r.switch._scripts.OnClick
                    add(label, upv(click, "get"), upv(click, "set"))
                elseif r.buttons then
                    local click = r.buttons[1]._scripts.OnClick
                    local set = upv(click, "set")
                    local get = upv(r.Refresh, "get")
                    local values = {}
                    for _, b in ipairs(r.buttons) do values[#values + 1] = b.value end
                    add(label, get, set, function(v) for _, x in ipairs(values) do if x ~= v then return x end end end)
                end
            end
        end
    end
    -- dropdowns are rows with a Button child whose OnClick opens the menu
    _G.FarseerHUDOptions:Hide()

    local function sweep()
        local silent = {}
        for _, c in ipairs(controls) do
            assert(c.get and c.set, c.label .. ": no get/set found")
            local before = c.get()
            local v
            if c.alt then v = c.alt(before) else v = not before end
            local a = snap()
            c.set(v)
            if changed(a, snap()) == 0 then silent[c.label] = tostring(v) end
            c.set(before)
        end
        return silent
    end

    -- 1) out of combat, enemy targeted, low mana
    mana = 100
    local idle = sweep()
    -- 2) in combat: swinging, Stormstrike + Flame Shock just cast
    fire("PLAYER_REGEN_DISABLED")
    combat = true
    fire("PLAYER_ENTER_COMBAT")
    fire("PLAYER_SWING", 2.6, 0)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 17364)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8050)
    local fight = sweep()
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    -- 3) edit mode
    NS.Movers:Toggle()
    local edit = sweep()
    NS.Movers:Toggle()
    mana = 900

    -- settings that only act on a later event (a sound, an alert, a timer, a cast, a state the
    -- test character is not in); each one was checked by hand to read its value at that moment
    local eventOnly = {
        ["shocks: Flash when a spell is ready again"] = true,      -- OnCooldownDone
        ["shocks: Glow on the next spell"] = true,                 -- a spell that is ready, in combat
        ["totems: Pulse before a totem runs out"] = true,          -- a totem in its last seconds
        ["shocks: Flame Shock duration"] = true,                   -- next Flame Shock cast
        ["swing: Project casts onto the bar"] = true,              -- next cast
        ["swing: Grey out when out of melee range"] = true,        -- out of range
        ["swing: Hide Blizzard's own swing timer"] = true,         -- a CVar, not our frame
        ["mana: Show percentage"] = true,                          -- needs height >= 9 (said in the option)
        ["mana: Hide at full mana out of combat"] = true,          -- full mana
        ["mana: Red below"] = true,                                -- mana between old and new threshold
        ["imbues: Warn when less than"] = true,                    -- imbue running low
        ["totems: Alert when a totem dies or expires"] = true,     -- totem dies
        ["totems: Totemic Recall reminder after combat"] = true,   -- leaving combat with totems
        ["maelstrom: Glow at five stacks"] = true,                 -- five stacks
        ["maelstrom: Sound at five stacks"] = true,                -- five stacks
        ["reminders: Shield reminder in combat too"] = true,       -- shield missing in combat
        ["reminders: Ghost Wolf on in combat"] = true,             -- wolf form in combat
        ["reminders: Warn below"] = true,                          -- Reincarnation known
        ["reminders: Snooze on right-click"] = true,               -- right-click on an alert
        ["appearance: Play sounds"] = true,                        -- next sound
        ["appearance: Out of combat"] = true,                      -- no enemy targeted
        ["swing: Hide Blizzard's cast bar"] = true,                -- turning it back on needs a /reload
    }
    print("  " .. #controls .. " settings checked")
    for label in pairs(idle) do
        if fight[label] and edit[label] then
            assert(eventOnly[label], "setting has no visible effect: " .. label)
        end
    end
end)

run("layout: text size, alert stack, edit mode", function()
    -- HUD text follows the text size, fixed layouts (settings, edit mode, alert cards) do not
    NS.db.appearance.fontScale = 1.5
    NS.UI:ApplyAppearance()
    NS.Alerts:Test()
    assert(NS.modules.maelstrom.hint._calls.SetFont[2] == 11 * 1.5, "HUD text scales")
    assert(NS.Alerts.cards[1].title._calls.SetFont[2] == 13, "alert text keeps its size")
    assert(NS.Alerts.cards[1]._calls.SetScale[1] == 1.5, "the alert card scales as a whole")
    NS.db.appearance.fontScale = 1
    NS.UI:ApplyAppearance()
    -- never more than four alert cards at once
    for i = 1, 6 do NS.Alerts:Set("many" .. i, { title = "t", priority = i }) end
    local shown = 0
    for _, c in ipairs(NS.Alerts.cards) do if c:IsShown() then shown = shown + 1 end end
    assert(shown == 4 and NS.Alerts.cards[1].key == "test1", "four cards, highest priority first")
    for i = 1, 6 do NS.Alerts:Clear("many" .. i) end
    -- edit mode closes the settings window (it would cover the HUD)
    NS.Options:Show("overview")
    NS.Movers:Toggle(true)
    assert(not NS.Options:IsShown(), "settings window closed by edit mode")
    NS.Movers:Toggle(false)
    -- default layout: totems left of the 240px bar column, shield and imbues right of it,
    -- so the icons you press stand alone on their line
    local d = function(key) return NS.Movers.byKey[key].default[3] end
    assert(d("totems") + (4 * 30 + 3 * 4) / 2 <= -120 - 8, "totems left of the bar column")
    assert(d("shield") - 15 >= 120 + 8, "shield right of the bar column")
    assert(d("imbues") - (2 * 30 + 4) / 2 - 3 > d("shield") + 15, "imbue glow clear of the shield")
    assert(NS.Movers.byKey.totems.default[4] > NS.Movers.byKey.cooldowns.default[4] + 30, "upkeep is not on the line of the icons you press")
end)

run("next-spell glow: one icon, in the guides' order", function()
    local S = NS.modules.shocks
    local function icon(key) for _, f in ipairs(S.cdIcons) do if f.key == key then return f end end end
    local function lit(f) return f.sfGlow ~= nil and f.sfGlow:IsShown() end
    local function cast(id) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", id) end
    local mw = _G.FarseerHUDMaelstrom
    tick(30)                                    -- cooldowns and timers of earlier steps are over
    assert(S.Advice() == nil, "nothing glows out of combat")
    fire("PLAYER_REGEN_DISABLED")
    combat = true
    fire("PLAYER_TARGET_CHANGED")               -- a fresh target has no Flame Shock
    tick(0.2)
    assert(S.Advice() == "flameShock" and lit(icon("earthShock")), "Flame Shock first: " .. tostring(S.Advice()))
    assert(icon("earthShock").shock == "flameShock", "the shock icon shows Flame Shock")
    cast(8050)
    tick(0.2)
    assert(S.Advice() == "stormstrike" and lit(icon("stormstrike")) and not lit(icon("earthShock")), "then Stormstrike, one glow only")
    local g = icon("stormstrike").sfGlow
    assert(g.wash and g.halo and g.wash._calls.SetVertexColor[4] > 0, "the icon to press also shimmers")
    assert(_G.FarseerHUDTotemFire.sfGlow.wash == nil, "other glows (totem pulse) stay plain rings")
    tick(3)
    cast(17364)
    tick(0.2)
    assert(S.Advice() == nil, "everything on cooldown: nothing glows")
    tick(2.9)                                   -- shock ready, Flame Shock still has 6 s
    assert(S.Advice() == "earthShock" and icon("earthShock").shock == "earthShock", "Earth Shock as filler: " .. tostring(S.Advice()))
    cast(8042)
    tick(3)                                     -- Stormstrike ready again, five Maelstrom stacks
    playerAuras[2] = { name = "Maelstrom Weapon", spellId = 53817, applications = 5, whitelisted = true }
    fire("UNIT_AURA", "player", {})
    tick(0.2)
    assert(S.Advice() == "stormstrike" and not lit(mw), "Stormstrike before the Bolt; the Maelstrom bar waits")
    cast(17364)
    tick(0.2)
    assert(S.Advice() == "lightningBolt" and lit(mw) and lit(icon("lightningBolt")), "Bolt at five stacks: its icon and the Maelstrom bar glow")
    assert(icon("lightningBolt"):GetAlpha() == 1 and icon("lightningBolt").bonus:IsShown(), "Bolt bright and marked as boosted by Stormstrike")
    playerAuras[2] = nil
    cast(403)
    fire("UNIT_AURA", "player", {})
    tick(0.2)
    assert(S.Advice() == nil and not lit(mw), "Bolt spent")

    -- what you cannot press looks different: the Bolt below five stacks, Fire Nova without a fire totem
    NS.db.learned.maelstromBuffID = NS.db.learned.maelstromBuffID or 408505
    S:UpdateCooldowns()
    assert(icon("lightningBolt"):IsShown() and icon("lightningBolt"):GetAlpha() < 1, "Bolt icon dimmed below five stacks")
    assert(icon("fireNova"):GetAlpha() < 1, "Fire Nova dimmed without a fire totem")
    assert(icon("stormstrike"):GetAlpha() == 1, "Stormstrike is not dimmed while it is only on cooldown")
    -- out of melee range: Stormstrike turns red and the glow moves on to what reaches the target
    tick(6)
    cast(8050)                                  -- Flame Shock had run out: it comes first
    tick(0.2)
    assert(S.Advice() == "stormstrike", "in range: Stormstrike")
    fire("PLAYER_SWING_RANGE_UPDATE", 0, false, true)
    tick(0.2)
    assert(S.Advice() ~= "stormstrike" and icon("stormstrike").why == "range", "out of range: not Stormstrike: " .. tostring(S.Advice()))
    fire("PLAYER_SWING_RANGE_UPDATE", 0, true, true)
    tick(0.2)
    assert(S.Advice() == "stormstrike" and not icon("stormstrike").why, "back in range")
    -- not enough mana: the icons turn blue (as on the action bars) and nothing glows
    local usable = C_Spell.IsSpellUsable
    C_Spell.IsSpellUsable = function() return false, true end
    tick(0.2)
    local ss = icon("stormstrike")
    local tint = ss.icon._calls.SetVertexColor
    assert(ss.why == "mana" and tint[3] == 1 and tint[1] < 0.6, "Stormstrike blue without mana")
    assert(ss:GetAlpha() == 1 and S.Advice() == nil and not lit(ss), "tinted, not dimmed, and nothing to press")
    C_Spell.IsSpellUsable = function() return false, false end
    tick(0.2)
    assert(ss.why == "unusable" and ss:GetAlpha() < 1, "unusable for another reason: dimmed, not blue")
    C_Spell.IsSpellUsable = usable
    tick(0.2)
    assert(not ss.why and ss.icon._calls.SetVertexColor[1] == 1 and S.Advice() == "stormstrike", "mana back: normal again")
    cast(17364)

    -- Magma Totem down = a group: Fire Nova goes first; the slot pulses before the totem runs out
    tick(6)
    cast(8190)
    tick(0.2)
    assert(NS.modules.totems.FireTotem() == "magmaTotem" and S.Advice() == "fireNova", "Fire Nova first with Magma down: " .. tostring(S.Advice()))
    cast(408341)
    tick(0.2)
    assert(S.Advice() ~= "fireNova", "Fire Nova on cooldown")
    local fireSlot = _G.FarseerHUDTotemFire
    assert(not lit(fireSlot), "no pulse yet")
    tick(15.1)
    assert(lit(fireSlot), "slot pulses in the totem's last seconds")
    tick(5)
    assert(not lit(fireSlot) and NS.modules.totems.FireTotem() == nil, "totem over: pulse off, single-target order again")
    assert(S.Advice() ~= "fireNova", "no Fire Nova without Magma")

    -- another target mid-fight: its Flame Shock is unknown, so it is asked for again
    cast(8050)
    tick(0.2)
    fire("PLAYER_TARGET_CHANGED")
    tick(6.2)
    assert(icon("earthShock").shock == "flameShock", "new target: Flame Shock again")
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    assert(S.Advice() == nil and not lit(icon("stormstrike")), "glow off after the fight")
    NS.db.shocks.prompt = false
    fire("PLAYER_REGEN_DISABLED")
    combat = true
    tick(0.2)
    assert(S.Advice() == nil, "switched off: nothing glows")
    combat = false
    fire("PLAYER_REGEN_ENABLED")
    NS.db.shocks.prompt = true
end)

run("regression: a totem that runs out still gets its 'is gone' alert", function()
    totems[1] = { name = "Searing Totem" }
    fire("PLAYER_TOTEM_UPDATE", 1)
    for _ = 1, 300 do tick(1) end      -- the slot times out on our own clock first
    assert(not NS.modules.totems.HasFire(), "slot dimmed when its time is up")
    totems[1] = nil
    fire("PLAYER_TOTEM_UPDATE", 1)     -- then the client says it is gone
    assert(NS.Alerts.active.totem1, "'is gone' alert after the slot timed out")
    NS.Alerts:Clear("totem1")
end)

run("reset", function()
    SlashCmdList.FARSEERHUD("reset confirm")
end)

print("all good")
