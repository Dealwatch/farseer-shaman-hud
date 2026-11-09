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
function UnitCastingInfo() return nil end
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
}
-- player knows these (spellbook, Forever-style unknown ID for Rage of the Farseer)
local BOOK = { 17364, 8042, 8050, 403, 324, 8232, 8024, 2645, 20608, 3599, 8075, 90001, 66842, 36936 }

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

run("settings window, every page", function()
    SlashCmdList.FARSEERHUD("")
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

run("regression: slider drag saves and applies (no userInput flag)", function()
    local db = NS.db.shocks
    local row = NS.Widgets.Slider(UIParent, "Cooldown icon size", nil, 20, 56, 1,
        function() return db.iconSize end,
        function(v) db.iconSize = v; NS:ApplyAll() end)
    row.slider._scripts.OnValueChanged(row.slider, 44)   -- what the client sends while dragging
    assert(db.iconSize == 44, "slider value saved")
    local icon = NS.modules.shocks.cdIcons[1]
    assert(icon:GetWidth() == 44, "cooldown icons resized")
end)

run("reset", function()
    SlashCmdList.FARSEERHUD("reset confirm")
end)

print("all good")
