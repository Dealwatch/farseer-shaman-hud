--[[
    ShammyForever - core
    Namespace, event bus, saved settings, module registry, slash commands and
    the secret-value helpers every module uses.

    WoW Forever runs the 12.x engine: in combat (and in encounters / PvP) many
    values reach addons as "secrets". A secret may be handed to a widget
    (FontString:SetText, StatusBar:SetValue, Texture:SetTexture, ...) but
    comparing it or doing arithmetic on it is a hard Lua error. So: logic only
    ever runs on NS.Readable() values, and secrets go straight into widgets.
]]

local ADDON, NS = ...
_G.ShammyForever = NS

NS.ADDON = ADDON
NS.TITLE = "Shammy Forever"
NS.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"
NS.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\"

---------------------------------------------------------------------------
-- Secrets
---------------------------------------------------------------------------

local issecretvalue = _G.issecretvalue

local issecrettable = _G.issecrettable

function NS.IsSecret(v)
    if issecretvalue ~= nil and issecretvalue(v) == true then return true end
    return issecrettable ~= nil and type(v) == "table" and issecrettable(v) == true
end

-- The value, or nil when the client hides it from us right now.
function NS.Readable(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Calls a client API defensively: missing function or a refusal -> nil.
function NS.Try(fn, ...)
    if not fn then return nil end
    local res = { pcall(fn, ...) }
    if not res[1] then return nil end
    return unpack(res, 2)
end

function NS.InCombat()
    return InCombatLockdown() or UnitAffectingCombat("player") and true or false
end

---------------------------------------------------------------------------
-- Printing
---------------------------------------------------------------------------

function NS.Print(...)
    print("|cff0070ddShammy|r|cffe8eaedForever|r:", ...)
end

---------------------------------------------------------------------------
-- Event bus (game events and our own "SF_" messages share it)
---------------------------------------------------------------------------

local bus = CreateFrame("Frame")
local handlers = {}

local function dispatch(list, event, ...)
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then geterrorhandler()(err) end
    end
end

bus:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if list then dispatch(list, event, ...) end
end)

-- Game event or internal message. Unknown game events are ignored so a
-- client that lacks one does not break the addon.
function NS:On(event, fn)
    local list = handlers[event]
    if not list then
        list = {}
        handlers[event] = list
        if not event:find("^SF_") then pcall(bus.RegisterEvent, bus, event) end
    end
    list[#list + 1] = fn
end

-- Unit-filtered events get their own frame so RegisterUnitEvent applies.
function NS:OnUnit(event, unit, fn)
    local f = CreateFrame("Frame")
    if pcall(f.RegisterUnitEvent, f, event, unit) then
        f:SetScript("OnEvent", function(_, ...)
            local ok, err = pcall(fn, ...)
            if not ok then geterrorhandler()(err) end
        end)
    end
end

function NS:Send(msg, ...)
    local list = handlers[msg]
    if list then dispatch(list, msg, ...) end
end

---------------------------------------------------------------------------
-- Work that must wait until combat ends (secure attributes, frame moves)
---------------------------------------------------------------------------

local afterCombat = {}

function NS.AfterCombat(key, fn)
    if not InCombatLockdown() then
        fn()
    else
        afterCombat[key] = fn
    end
end

NS:On("PLAYER_REGEN_ENABLED", function()
    for key, fn in pairs(afterCombat) do
        afterCombat[key] = nil
        local ok, err = pcall(fn)
        if not ok then geterrorhandler()(err) end
    end
end)

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

-- One clean HUD column (240 wide) under your character, one icon size (30)
-- for every icon row. Positions are CENTER offsets on UIParent.
NS.defaults = {
    modules = {
        swing = true, mana = true, totems = true, imbues = true,
        maelstrom = true, procs = true, shocks = true, reminders = true,
    },
    positions = {},
    appearance = {
        accent = "shaman",
        scale = 1.0,
        fontScale = 1.0,
        font = "Fonts\\FRIZQT__.TTF",
        texture = "smooth",
        sounds = true,
        grid = 16,
        idleAlpha = 0,          -- HUD opacity out of combat (0 = hidden; alerts and needed imbues stay)
        showOnTarget = true,    -- out of combat, show the HUD while an enemy is targeted (pre-pull)
    },
    swing = {
        width = 240, height = 12,
        offhand = true,         -- second, thinner bar while dual wielding
        showCast = true,        -- project casts onto the main hand swing
        hideIdle = true,        -- hide when not in combat / not swinging
        rangeTint = true,       -- grey the bar when the target is out of melee range
        showText = true,        -- time to the next swing
    },
    mana = {
        width = 240, height = 6,
        showText = false,       -- percentage on the bar
        hideFull = true,        -- hide out of combat at full mana
        lowPct = 25,            -- bar turns red below this
    },
    totems = {
        size = 30,
        spacing = 4,
        showTimers = true,
        showEmpty = true,       -- show empty element slots (dimmed)
        hideIdle = false,       -- hide the whole bar out of combat when no totem is down
        expireAlert = true,
        recallReminder = true,  -- after combat: "Totemic Recall" (refunds 25% of the totems' mana)
    },
    imbues = {
        mh = "windfury",
        oh = "flametongue",
        warnMinutes = 3,
        show = "missing",       -- "missing" (only when an imbue is missing / running out) | "always"
        inCombat = true,        -- also warn in combat
        size = 30,
    },
    procs = {
        size = 30,              -- icon size (applies after /reload: the client lays the row out)
    },
    maelstrom = {
        width = 240, height = 10,
        glow = true,
        sound = true,
        hideEmpty = true,       -- hide out of combat at 0 stacks
    },
    shocks = {
        prompt = true,          -- after Stormstrike: Earth Shock icon glows
        promptCard = false,     -- also a big "Shock now!" card
        promptWindow = 6,       -- seconds the prompt stays up
        flameShock = true,      -- Flame Shock timer bar
        flameShockDuration = 12,
        cooldowns = true,       -- cooldown icon row
        iconSize = 30,
        barWidth = 240,
    },
    reminders = {
        shield = true,
        shieldInCombat = true,
        ghostWolf = true,
        ankh = true,
        ankhMin = 1,
        snooze = 60,
        shieldIcon = true,      -- shield icon with charges (native aura slot)
        shieldSize = 30,
    },
    learned = {
        maelstromBuffID = nil,  -- learned from a readable aura
        durations = {},         -- spell name -> seconds, learned from readable auras
    },
}

local function fill(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            fill(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function copy(src)
    local t = {}
    for k, v in pairs(src) do t[k] = type(v) == "table" and copy(v) or v end
    return t
end

function NS:InitDB()
    if type(_G.ShammyForeverDB) ~= "table" then _G.ShammyForeverDB = {} end
    fill(_G.ShammyForeverDB, self.defaults)
    self.db = _G.ShammyForeverDB
end

function NS:ResetDB()
    _G.ShammyForeverDB = copy(self.defaults)
    self.db = _G.ShammyForeverDB
end

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------

NS.modules = {}
NS.moduleOrder = {}

-- info: { title, desc, icon }. A module may define:
--   :Init()   build frames, register events (once, at login)
--   :Apply()  re-read settings, show/hide (after every settings change)
function NS:NewModule(key, info)
    local m = info or {}
    m.key = key
    self.modules[key] = m
    self.moduleOrder[#self.moduleOrder + 1] = key
    return m
end

function NS:IsEnabled(key)
    return self.db and self.db.modules[key] and self.isShaman or false
end

function NS:SetModuleEnabled(key, on)
    self.db.modules[key] = on and true or false
    self:ApplyAll()
end

function NS:ApplyAll()
    for _, key in ipairs(self.moduleOrder) do
        local m = self.modules[key]
        if m.Apply then
            local ok, err = pcall(m.Apply, m)
            if not ok then geterrorhandler()(err) end
        end
    end
    self:Send("SF_APPLIED")
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

NS:On("PLAYER_LOGIN", function()
    NS:InitDB()
    local _, class = UnitClass("player")
    NS.isShaman = class == "SHAMAN"

    NS.Spells:Resolve()
    if NS.UI then NS.UI:ApplyAppearance() end

    for _, key in ipairs(NS.moduleOrder) do
        local m = NS.modules[key]
        if m.Init and NS.isShaman then
            local ok, err = pcall(m.Init, m)
            if not ok then geterrorhandler()(err) end
        end
    end
    NS:ApplyAll()

    if not NS.isShaman then
        NS.Print("not a Shaman - modules are off. /sham still opens the settings.")
    end
end)

local function onSpellsChanged()
    if not NS.db then return end
    NS.Spells:Resolve()
    NS:Send("SF_SPELLS")
end
NS:On("SPELLS_CHANGED", onSpellsChanged)
NS:On("PLAYER_TALENT_UPDATE", onSpellsChanged)
NS:On("LEARNED_SPELL_IN_SKILL_LINE", onSpellsChanged)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local commands = {}
NS.commands = commands

commands[""] = function() if NS.Options then NS.Options:Toggle() end end
commands["edit"] = function() if NS.Movers then NS.Movers:Toggle() end end
commands["test"] = function() if NS.Alerts then NS.Alerts:Test() end end
commands["reset"] = function(arg)
    if arg ~= "confirm" then
        NS.Print("type |cffffd100/sham reset confirm|r to reset all settings and positions.")
        return
    end
    NS:ResetDB()
    if NS.Movers then NS.Movers:RestoreAll() end
    if NS.UI then NS.UI:ApplyAppearance() end
    NS:ApplyAll()
    NS.Print("settings reset.")
end
commands["help"] = function()
    NS.Print("commands:")
    print("  /sham - settings window")
    print("  /sham edit - move frames")
    print("  /sham test - preview alerts")
    print("  /sham probe - what Forever lets the addon read (use it in combat too)")
    print("  /sham spells - copyable list of your spells and their IDs")
    print("  /sham reset confirm - reset everything")
end

-- Key bindings (Bindings.xml): Options > Key Bindings > AddOns > Shammy Forever
BINDING_HEADER_SHAMMYFOREVER = "Shammy Forever"
for _, el in ipairs({ "Earth", "Fire", "Water", "Air" }) do
    _G["BINDING_NAME_CLICK ShammyForeverTotem" .. el .. ":LeftButton"] = "Recast " .. el:lower() .. " totem"
end
_G["BINDING_NAME_CLICK ShammyForeverImbueMH:LeftButton"] = "Apply main hand imbue"
_G["BINDING_NAME_CLICK ShammyForeverImbueOH:LeftButton"] = "Apply off hand imbue"

SLASH_SHAMMYFOREVER1 = "/sham"
SLASH_SHAMMYFOREVER2 = "/shammy"
SlashCmdList.SHAMMYFOREVER = function(msg)
    msg = (msg or ""):lower()
    local cmd, arg = msg:match("^%s*(%S*)%s*(.-)%s*$")
    local fn = commands[cmd or ""] or commands.help
    if not NS.db then return end
    fn(arg)
end

function _G.ShammyForever_OnAddonCompartmentClick()
    commands[""]()
end
