--[[
    ShammyForever - settings window (/sham)
    Navigation on the left, pages of cards on the right. Every page is built
    once and refreshed whenever it is shown or a setting changes.
]]

local _, NS = ...
local UI, W, Spells = NS.UI, NS.Widgets, NS.Spells
local P = UI.palette

local Options = {}
NS.Options = Options

local WIN_W, WIN_H, NAV_W = 920, 640, 230
local win, pages, navButtons, current = nil, {}, {}, nil

---------------------------------------------------------------------------
-- Setting bindings
---------------------------------------------------------------------------

local function bind(section, key, after)
    return function() return NS.db[section][key] end,
        function(v)
            NS.db[section][key] = v
            if after then after(v) end
            NS:ApplyAll()
            if current then current:Refresh() end
        end
end

local function bindAppearance(key)
    return bind("appearance", key, function() UI:ApplyAppearance(); Options:Restyle() end)
end

local function bindModule(key)
    return function() return NS.db.modules[key] end,
        function(v) NS:SetModuleEnabled(key, v); if current then current:Refresh() end end
end

local function secs(v)
    if v >= 60 then return string.format("%dm %02ds", math.floor(v / 60), v % 60) end
    return v .. "s"
end
local function px(v) return tostring(v) end
local function mult(v) return string.format("%.2fx", v) end
local function oneDec(v) return string.format("%.1fs", v) end

---------------------------------------------------------------------------
-- Page framework
---------------------------------------------------------------------------

local function newPage(key, title, sub, icon)
    local p = { key = key, title = title, sub = sub, icon = icon, blocks = {} }
    function p:Add(block) self.blocks[#self.blocks + 1] = block; return block end
    function p:Layout()
        local width = win.scroll:GetWidth() - 8
        local y = 0
        for _, b in ipairs(self.blocks) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
            y = y + b:Layout(width) + 14
        end
        self.content:SetSize(width, y)
    end
    function p:Refresh()
        for _, b in ipairs(self.blocks) do if b.Refresh then b:Refresh() end end
    end
    pages[#pages + 1] = p
    return p
end

---------------------------------------------------------------------------
-- Overview blocks
---------------------------------------------------------------------------

local function buildInfo()
    local _, build, _, iface = GetBuildInfo()
    local forever = iface and iface >= 16000 and iface < 20000
    return build, iface, forever
end

local function heroBlock(parent)
    local h = CreateFrame("Frame", nil, parent)
    UI:Skin(h, P.surface2, P.border, "lg")
    h.logo = UI:Icon(h, 84)
    h.logo:SetPoint("LEFT", 24, 0)
    h.logo.icon:SetTexture("Interface\\Icons\\Spell_Nature_LightningShield")
    h.title = UI:Text(h, 26)
    h.title:SetPoint("TOPLEFT", h.logo, "TOPRIGHT", 20, -6)
    h.ver = UI:Text(h, 14, P.textDim)
    h.ver:SetPoint("BOTTOMLEFT", h.title, "BOTTOMRIGHT", 10, 3)
    h.line1 = UI:Text(h, 13)
    h.line1:SetPoint("TOPLEFT", h.title, "BOTTOMLEFT", 0, -8)
    h.line2 = UI:Text(h, 12, P.textDim)
    h.line2:SetPoint("TOPLEFT", h.line1, "BOTTOMLEFT", 0, -6)
    h.line2:SetText("/sham opens this window  -  /sham edit moves frames  -  /sham probe tests the client")
    h.edit = W.Button(h, "Edit layout", true, function() NS.Movers:Toggle(true) end, 160)
    h.edit:SetPoint("TOPRIGHT", -20, -24)
    h.test = W.Button(h, "Test alerts", false, function() NS.Alerts:Test() end, 160)
    h.test:SetPoint("TOPRIGHT", h.edit, "BOTTOMRIGHT", 0, -10)
    function h:Layout(width) self:SetSize(width, 130) return 130 end
    function h:Refresh()
        local r, g, b = UI:Accent()
        self.title:SetText(string.format("|cff%02x%02x%02xShammy|r Forever", r * 255, g * 255, b * 255))
        self.ver:SetText("v" .. NS.VERSION)
        local build, iface, forever = buildInfo()
        self.line1:SetText(string.format("%s  -  build %s  -  interface %s", forever and "WoW Forever" or "WoW", tostring(build), tostring(iface)))
        self.edit:Refresh(); self.test:Refresh()
    end
    return h
end

local function imbueText()
    local mod = NS.modules.imbues
    local function one(key, label)
        local has, left = mod.Read and mod.Read({ key = key, inv = key == "mh" and 16 or 17, slot = key == "mh" and 0 or 1 })
        if has == nil then return label .. " ?" end
        if not has then return label .. " |cffff5555none|r" end
        return label .. " " .. (left and math.floor(left / 60) .. "m" or "on")
    end
    return one("mh", "MH") .. "   " .. one("oh", "OH")
end

local function tilesBlock(parent)
    local t = CreateFrame("Frame", nil, parent)
    t.tiles = {}
    local defs = {
        { label = "IMBUES", icon = "Interface\\Icons\\Spell_Nature_Cyclone", value = imbueText },
        { label = "SHIELD", icon = "Interface\\Icons\\Spell_Nature_LightningShield", value = function()
            local s = NS.modules.reminders.ShieldState and NS.modules.reminders.ShieldState()
            if s == true then return "|cff55d985up|r" elseif s == false then return "|cffff5555missing|r" end
            return "unknown"
        end },
        { label = "MAELSTROM", icon = "Interface\\Icons\\Spell_Shaman_MaelstromWeapon", value = function()
            local st = NS.modules.maelstrom.state
            if st.source == "aura" then return st.readableInCombat and "exact stacks" or "exact (out of combat)" end
            if st.source == "proc" then return "5-stack glow" end
            return "not seen yet"
        end },
    }
    for i, d in ipairs(defs) do
        local f = CreateFrame("Frame", nil, t)
        UI:Skin(f, P.surface2, P.border, "lg")
        f.iconFrame = UI:Icon(f, 40)
        f.iconFrame:SetPoint("LEFT", 14, 0)
        f.iconFrame.icon:SetTexture(d.icon)
        f.label = UI:Text(f, 11, P.textDim)
        f.label:SetPoint("TOPLEFT", f.iconFrame, "TOPRIGHT", 12, -2)
        f.label:SetText(d.label)
        f.value = UI:Text(f, 15)
        f.value:SetPoint("BOTTOMLEFT", f.iconFrame, "BOTTOMRIGHT", 12, 2)
        f.value:SetPoint("RIGHT", -8, 0)
        f.def = d
        t.tiles[i] = f
    end
    function t:Layout(width)
        local w = (width - 2 * 14) / 3
        for i, f in ipairs(self.tiles) do
            f:SetSize(w, 70)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", (i - 1) * (w + 14), 0)
        end
        self:SetSize(width, 70)
        return 70
    end
    function t:Refresh()
        for _, f in ipairs(self.tiles) do f.value:SetText(f.def.value()) end
    end
    return t
end

local function modulesBlock(parent)
    local m = CreateFrame("Frame", nil, parent)
    m.header = UI:Text(m, 14, P.textDim)
    m.header:SetPoint("TOPLEFT", 0, 0)
    m.header:SetText("MODULES")
    m.cards = {}
    for _, key in ipairs(NS.moduleOrder) do
        local mod = NS.modules[key]
        local c = CreateFrame("Frame", nil, m)
        UI:Skin(c, P.surface2, P.border, "lg")
        c.iconFrame = UI:Icon(c, 36)
        c.iconFrame:SetPoint("LEFT", 14, 0)
        c.iconFrame.icon:SetTexture(mod.icon)
        c.title = UI:Text(c, 14)
        c.title:SetPoint("TOPLEFT", c.iconFrame, "TOPRIGHT", 12, -1)
        c.title:SetText(mod.title)
        c.desc = UI:Text(c, 11, P.textDim)
        c.desc:SetPoint("BOTTOMLEFT", c.iconFrame, "BOTTOMRIGHT", 12, 1)
        c.desc:SetPoint("RIGHT", -70, 0)
        c.desc:SetText(mod.desc)
        local get, set = bindModule(key)
        c.switch = W.Switch(c, get, set)
        c.switch:SetPoint("RIGHT", -14, 0)
        m.cards[#m.cards + 1] = c
    end
    function m:Layout(width)
        local w = (width - 14) / 2
        for i, c in ipairs(self.cards) do
            local col, rowI = (i - 1) % 2, math.floor((i - 1) / 2)
            c:SetSize(w, 64)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", col * (w + 14), -26 - rowI * 76)
        end
        local h = 26 + math.ceil(#self.cards / 2) * 76
        self:SetSize(width, h)
        return h
    end
    function m:Refresh() for _, c in ipairs(self.cards) do c.switch:Refresh() end end
    return m
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------

local function buildPages()
    local p

    p = newPage("overview", "Overview", "Everything an Enhancement Shaman needs, built for WoW Forever.", "Interface\\Icons\\Spell_Nature_LightningShield")
    p.build = function(self, parent)
        self:Add(heroBlock(parent))
        self:Add(tilesBlock(parent))
        self:Add(modulesBlock(parent))
    end

    p = newPage("swing", "Swing Timer", "Main and off hand swings from Forever's native swing events.", "Interface\\Icons\\INV_Axe_09")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Swing timer", self.icon, bindModule("swing")))
        c:Add(W.Slider(c, "Width", nil, 120, 420, 10, bind("swing", "width"), px))
        c:Add(W.Slider(c, "Height", nil, 6, 30, 1, bind("swing", "height"), px))
        c:Add(W.Toggle(c, "Off hand bar", "A thin second line while dual wielding.", bind("swing", "offhand")))
        c:Add(W.Toggle(c, "Project casts onto the bar", "Turns red when a cast runs past your next main hand swing.", bind("swing", "showCast")))
        c:Add(W.Toggle(c, "Grey out when out of melee range", nil, bind("swing", "rangeTint")))
        c:Add(W.Toggle(c, "Time to next swing", nil, bind("swing", "showText")))
        c:Add(W.Toggle(c, "Hide when not fighting", nil, bind("swing", "hideIdle")))
    end

    p = newPage("mana", "Mana Bar", "A thin mana bar in the HUD column.", "Interface\\Icons\\Spell_Nature_ManaRegenTotem")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Mana bar", self.icon, bindModule("mana")))
        c:Add(W.Slider(c, "Width", nil, 120, 420, 10, bind("mana", "width"), px))
        c:Add(W.Slider(c, "Height", nil, 3, 24, 1, bind("mana", "height"), px))
        c:Add(W.Slider(c, "Red below", nil, 5, 60, 5, bind("mana", "lowPct"), function(v) return v .. "%" end))
        c:Add(W.Toggle(c, "Show percentage", "Needs a height of 9 or more.", bind("mana", "showText")))
        c:Add(W.Toggle(c, "Hide at full mana out of combat", nil, bind("mana", "hideFull")))
    end

    p = newPage("totems", "Totems", "One button per element. Left-click recasts, right-click destroys.", "Interface\\Icons\\Spell_Nature_StoneSkinTotem")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Totem bar", self.icon, bindModule("totems")))
        c:Add(W.Slider(c, "Icon size", nil, 24, 60, 1, bind("totems", "size"), px))
        c:Add(W.Slider(c, "Spacing", nil, 0, 16, 1, bind("totems", "spacing"), px))
        c:Add(W.Toggle(c, "Show time left", nil, bind("totems", "showTimers")))
        c:Add(W.Toggle(c, "Show empty slots", "Dimmed element icons for slots without a totem.", bind("totems", "showEmpty")))
        c:Add(W.Toggle(c, "Hide out of combat when no totem is down", nil, bind("totems", "hideIdle")))
        c:Add(W.Toggle(c, "Alert when a totem dies or expires", "Only when the client tells us (out of combat or not secret).", bind("totems", "expireAlert")))
    end

    p = newPage("imbues", "Weapon Imbues", "Timers per hand. Click a button to apply your imbue.", "Interface\\Icons\\Spell_Nature_Cyclone")
    p.build = function(self, parent)
        local function imbueOptions()
            local o = {}
            for _, key in ipairs(Spells.IMBUES) do
                local def = Spells:Get(key)
                o[#o + 1] = { value = key, label = (def.name or def.en) .. (def.known and "" or " (not learned)") }
            end
            return o
        end
        local c = self:Add(W.Card(parent, "Weapon imbues", self.icon, bindModule("imbues")))
        c:Add(W.Dropdown(c, "Main hand", nil, imbueOptions, bind("imbues", "mh")))
        c:Add(W.Dropdown(c, "Off hand", "Only used while dual wielding.", imbueOptions, bind("imbues", "oh")))
        c:Add(W.Slider(c, "Warn when less than", nil, 1, 15, 1, bind("imbues", "warnMinutes"), function(v) return v .. " min" end))
        c:Add(W.Segment(c, "Show buttons", nil, { { value = "always", label = "Always" }, { value = "missing", label = "When needed" } }, bind("imbues", "show")))
        c:Add(W.Toggle(c, "Also warn in combat", nil, bind("imbues", "inCombat")))
        c:Add(W.Slider(c, "Icon size", nil, 24, 60, 1, bind("imbues", "size"), px))
    end

    p = newPage("maelstrom", "Maelstrom Weapon", "A five-segment bar that turns gold at five stacks: time for an instant Lightning Bolt.", "Interface\\Icons\\Spell_Shaman_MaelstromWeapon")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Maelstrom Weapon", self.icon, bindModule("maelstrom")))
        c:Add(W.Slider(c, "Width", nil, 100, 420, 10, bind("maelstrom", "width"), px))
        c:Add(W.Slider(c, "Height", nil, 4, 30, 1, bind("maelstrom", "height"), px))
        c:Add(W.Toggle(c, "Glow at five stacks", nil, bind("maelstrom", "glow")))
        c:Add(W.Toggle(c, "Sound at five stacks", nil, bind("maelstrom", "sound")))
        c:Add(W.Toggle(c, "Hide at zero stacks out of combat", nil, bind("maelstrom", "hideEmpty")))
        local info = c:Add(W.ButtonRow(c, "Detection", "The client fills the stack bar itself (native aura slot), also in combat. Glow and sound need the buff or the Lightning Bolt glow to be readable.", "Run probe", function() NS.commands.probe() end))
        local base = info.Refresh
        function info:Refresh()
            base(self)
            local st = NS.modules.maelstrom.state
            local native = NS.Native.slots.maelstrom and NS.Native.slots.maelstrom:Active()
            self.label:SetText("Detection: " .. (native and "native stack bar" or st.source == "aura" and "exact stacks" or st.source == "proc" and "five-stack glow" or "not seen yet"))
        end
    end

    p = newPage("shocks", "Stormstrike & Shocks", "Shock-now prompt, Flame Shock timer and your cooldowns.", "Interface\\Icons\\Ability_Shaman_Stormstrike")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Stormstrike & shocks", self.icon, bindModule("shocks")))
        c:Add(W.Toggle(c, "Shock prompt after Stormstrike", "Stormstrike boosts your next Nature damage: the Earth Shock icon glows.", bind("shocks", "prompt")))
        c:Add(W.Toggle(c, "Also show a big \"Shock now!\" card", "Used anyway when the cooldown row is off.", bind("shocks", "promptCard")))
        c:Add(W.Slider(c, "Prompt stays for", nil, 2, 12, 1, bind("shocks", "promptWindow"), function(v) return v .. "s" end))
        c:Add(W.Toggle(c, "Flame Shock timer", "Starts from your cast; corrected from the real debuff when readable.", bind("shocks", "flameShock")))
        c:Add(W.Slider(c, "Flame Shock duration", "Used until the addon has read the real duration once.", 6, 30, 1, bind("shocks", "flameShockDuration"), function(v) return v .. "s" end))
        c:Add(W.Slider(c, "Flame Shock bar width", nil, 120, 360, 10, bind("shocks", "barWidth"), px))
        c:Add(W.Toggle(c, "Cooldown icons", "Stormstrike, shocks, Rage of the Farseer and other cooldowns you know.", bind("shocks", "cooldowns")))
        c:Add(W.Slider(c, "Cooldown icon size", nil, 20, 56, 1, bind("shocks", "iconSize"), px))
    end

    p = newPage("reminders", "Reminders", "Alerts stack in one place. Right-click an alert to snooze it.", "Interface\\Icons\\Spell_Nature_LightningShield")
    p.build = function(self, parent)
        local c = self:Add(W.Card(parent, "Reminders", self.icon, bindModule("reminders")))
        c:Add(W.Toggle(c, "Shield icon with charges", "Charges and time left come straight from the client, also in combat.", bind("reminders", "shieldIcon")))
        c:Add(W.Slider(c, "Shield icon size", nil, 20, 60, 1, bind("reminders", "shieldSize"), px))
        c:Add(W.Toggle(c, "Lightning Shield missing", nil, bind("reminders", "shield")))
        c:Add(W.Toggle(c, "Shield reminder in combat too", nil, bind("reminders", "shieldInCombat")))
        c:Add(W.Toggle(c, "Ghost Wolf on in combat", nil, bind("reminders", "ghostWolf")))
        c:Add(W.Toggle(c, "Low on Ankhs", "Turn off if Reincarnation needs no Ankh on Forever.", bind("reminders", "ankh")))
        c:Add(W.Slider(c, "Warn below", nil, 1, 10, 1, bind("reminders", "ankhMin"), function(v) return v .. " Ankh" end))
        c:Add(W.Slider(c, "Snooze on right-click", nil, 15, 600, 15, bind("reminders", "snooze"), secs))
    end

    p = newPage("appearance", "Appearance", "Look and feel for every Shammy Forever frame.", "Interface\\Icons\\Spell_Nature_Bloodlust")
    p.build = function(self, parent)
        local look = self:Add(W.Card(parent, "Look", "Interface\\Icons\\INV_Misc_Gem_Sapphire_02"))
        local accents = {}
        for _, a in ipairs(UI.ACCENTS) do accents[#accents + 1] = { value = a.key, label = a.label } end
        local fonts = {}
        for _, f in ipairs(UI.FONTS) do fonts[#fonts + 1] = { value = f.key, label = f.label } end
        local textures = {}
        for _, t in ipairs(UI.TEXTURES) do textures[#textures + 1] = { value = t.key, label = t.label } end
        look:Add(W.Dropdown(look, "Accent colour", nil, accents, bindAppearance("accent")))
        look:Add(W.Dropdown(look, "Font", nil, fonts, bindAppearance("font")))
        look:Add(W.Slider(look, "Text size", nil, 0.7, 1.5, 0.05, bindAppearance("fontScale"), mult))
        look:Add(W.Dropdown(look, "Bar texture", nil, textures, bindAppearance("texture")))
        look:Add(W.Toggle(look, "Play sounds", nil, bind("appearance", "sounds")))
        look:Add(W.Slider(look, "Fade out of combat", "HUD opacity without combat or an enemy target. 100% = never fade.", 0.1, 1.0, 0.05, bind("appearance", "idleAlpha"), function(v) return math.floor(v * 100 + 0.5) .. "%" end))

        local layout = self:Add(W.Card(parent, "Layout", "Interface\\Icons\\INV_Misc_Map_01"))
        layout:Add(W.Slider(layout, "HUD scale", nil, 0.5, 2.0, 0.05, bindAppearance("scale"), mult))
        layout:Add(W.Slider(layout, "Edit mode grid", nil, 0, 64, 4, bind("appearance", "grid"), px))
        layout:Add(W.ButtonRow(layout, "Frames", nil, "Open Edit Mode", function() NS.Movers:Toggle(true) end))
        layout:Add(W.ButtonRow(layout, "Positions", "Puts every frame back where it started.", "Reset positions", function()
            wipe(NS.db.positions); NS.Movers:RestoreAll()
        end))

        local diag = self:Add(W.Card(parent, "Diagnostics", "Interface\\Icons\\INV_Misc_Spyglass_03"))
        diag:Add(W.ButtonRow(diag, "Client probe", "What Forever lets the addon read right now. Run it in combat too.", "Run probe", function() NS.commands.probe() end))
        diag:Add(W.ButtonRow(diag, "Spell list", "Copyable list of your spells and their IDs.", "Show spells", function() NS.commands.spells() end))
    end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function navButton(page, i)
    local b = CreateFrame("Button", nil, win.nav)
    b:SetSize(NAV_W - 24, 40)
    b:SetPoint("TOPLEFT", 12, -96 - (i - 1) * 44)
    b.bg = UI:ShapeTexture(b, "lg")
    b.bg:SetAllPoints()
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetTexture(UI.WHITE)
    b.bar:SetPoint("TOPLEFT", 0, -10); b.bar:SetPoint("BOTTOMLEFT", 0, 10); b.bar:SetWidth(3)
    b.iconFrame = UI:Icon(b, 24)
    b.iconFrame:SetPoint("LEFT", 14, 0)
    b.iconFrame.icon:SetTexture(page.icon)
    b.text = UI:Text(b, 14)
    b.text:SetPoint("LEFT", b.iconFrame, "RIGHT", 12, 0)
    b.text:SetText(page.title)
    b:SetScript("OnClick", function() Options:Show(page.key) end)
    b:SetScript("OnEnter", function(self) if current ~= page then self.bg:SetVertexColor(1, 1, 1, 0.03) end end)
    b:SetScript("OnLeave", function() Options:Restyle() end)
    b.page = page
    navButtons[#navButtons + 1] = b
end

local function build()
    win = CreateFrame("Frame", "ShammyForeverOptions", UIParent)
    win:SetSize(WIN_W, WIN_H)
    win:SetPoint("CENTER")
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    UI:Skin(win, P.surface, P.border, "lg")
    UI:Shadow(win)
    tinsert(UISpecialFrames, "ShammyForeverOptions")

    -- navigation
    win.nav = CreateFrame("Frame", nil, win)
    win.nav:SetPoint("TOPLEFT"); win.nav:SetPoint("BOTTOMLEFT"); win.nav:SetWidth(NAV_W)
    -- darker nav panel: rounded on the outer corners, a separator line inside
    win.navBg = win:CreateTexture(nil, "BACKGROUND", nil, -6)
    if not UI.Sliced(win.navBg, "Fill", "lg") then win.navBg:SetTexture(UI.WHITE) end
    win.navBg:SetPoint("TOPLEFT", win, "TOPLEFT", 1, -1)
    win.navBg:SetPoint("BOTTOMRIGHT", win, "BOTTOMLEFT", NAV_W + 12, 1)
    win.navBg:SetVertexColor(P.bg[1], P.bg[2], P.bg[3], 1)
    win.navCover = win:CreateTexture(nil, "BACKGROUND", nil, -5)
    win.navCover:SetTexture(UI.WHITE)
    win.navCover:SetPoint("TOPLEFT", NAV_W, -1)
    win.navCover:SetPoint("BOTTOMLEFT", NAV_W, 1)
    win.navCover:SetWidth(14)
    win.navCover:SetVertexColor(P.surface[1], P.surface[2], P.surface[3], 1)
    win.navLine = win:CreateTexture(nil, "BORDER")
    win.navLine:SetTexture(UI.WHITE)
    win.navLine:SetPoint("TOPLEFT", NAV_W, -1)
    win.navLine:SetPoint("BOTTOMLEFT", NAV_W, 1)
    win.navLine:SetWidth(1)
    win.navLine:SetVertexColor(P.border[1], P.border[2], P.border[3], 1)
    win.logo = UI:Icon(win.nav, 44)
    win.logo:SetPoint("TOPLEFT", 18, -22)
    win.logo.icon:SetTexture("Interface\\Icons\\Spell_Nature_LightningShield")
    win.name = UI:Text(win.nav, 18)
    win.name:SetPoint("TOPLEFT", win.logo, "TOPRIGHT", 12, -3)
    win.name:SetText(NS.TITLE)
    win.ver = UI:Text(win.nav, 11, P.textDim)
    win.ver:SetPoint("TOPLEFT", win.name, "BOTTOMLEFT", 0, -4)
    for i, page in ipairs(pages) do navButton(page, i) end

    win.status = CreateFrame("Frame", nil, win.nav)
    win.status:SetSize(NAV_W - 24, 30)
    win.status:SetPoint("BOTTOMLEFT", 12, 58)
    UI:Skin(win.status, P.surface, P.border, "lg")
    win.status.dot = win.status:CreateTexture(nil, "ARTWORK")
    win.status.dot:SetTexture(NS.MEDIA .. "Media\\Circle")
    win.status.dot:SetSize(8, 8)
    win.status.dot:SetPoint("LEFT", 12, 0)
    win.status.text = UI:Text(win.status, 12)
    win.status.text:SetPoint("LEFT", win.status.dot, "RIGHT", 10, 0)
    win.editBtn = W.Button(win.nav, "Edit layout", true, function() NS.Movers:Toggle(true) end, NAV_W - 24)
    win.editBtn:SetPoint("BOTTOMLEFT", 12, 14)

    -- page area
    win.titleText = UI:Text(win, 26)
    win.titleText:SetPoint("TOPLEFT", NAV_W + 28, -24)
    win.subText = UI:Text(win, 13, P.textDim)
    win.subText:SetPoint("TOPLEFT", win.titleText, "BOTTOMLEFT", 0, -6)
    win.close = CreateFrame("Button", nil, win)
    win.close:SetSize(28, 28)
    win.close:SetPoint("TOPRIGHT", -14, -14)
    win.close.text = UI:Text(win.close, 18, P.textDim)
    win.close.text:SetPoint("CENTER")
    win.close.text:SetText("x")
    win.close:SetScript("OnClick", function() win:Hide() end)

    win.scroll = CreateFrame("ScrollFrame", nil, win)
    win.scroll:SetPoint("TOPLEFT", NAV_W + 28, -96)
    win.scroll:SetPoint("BOTTOMRIGHT", -24, 20)
    win.scroll:EnableMouseWheel(true)
    win.scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, (self:GetScrollChild() and self:GetScrollChild():GetHeight() or 0) - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 50)))
    end)

    for _, page in ipairs(pages) do
        page.content = CreateFrame("Frame", nil, win.scroll)
        page.content:SetSize(WIN_W - NAV_W - 60, 10)
        page:build(page.content)
        page.content:Hide()
    end
    win:SetScript("OnHide", function() W.CloseMenu(); UI:UpdateFade() end)
    win:SetScript("OnShow", function() UI:UpdateFade() end)
    win:Hide()
end

function Options:Restyle()
    if not win then return end
    local r, g, b = UI:Accent()
    for _, nb in ipairs(navButtons) do
        if nb.page == current then
            nb.bg:SetVertexColor(1, 1, 1, 0.06)
            nb.bar:SetVertexColor(r, g, b, 1)
            nb.bar:Show()
        else
            nb.bg:SetVertexColor(0, 0, 0, 0)
            nb.bar:Hide()
        end
    end
    local _, iface, forever = buildInfo()
    win.status.dot:SetVertexColor(forever and r or P.warn[1], forever and g or P.warn[2], forever and b or P.warn[3], 1)
    win.status.text:SetText(forever and "WoW Forever detected" or ("Interface " .. tostring(iface)))
    win.ver:SetText("v" .. NS.VERSION .. "  -  Enhancement")
    win.editBtn:Refresh()
    if current then current:Refresh() end
end

function Options:Show(key)
    if not win then
        buildPages()
        build()
    end
    local page = pages[1]
    for _, p in ipairs(pages) do if p.key == key then page = p end end
    if current and current ~= page then current.content:Hide() end
    current = page
    win.titleText:SetText(page.title)
    win.subText:SetText(page.sub)
    win.scroll:SetScrollChild(page.content)
    win.scroll:SetVerticalScroll(0)
    page.content:Show()
    win:Show()
    page:Layout()
    self:Restyle()
end

function Options:IsShown() return win ~= nil and win:IsShown() end

function Options:Toggle()
    if win and win:IsShown() then win:Hide() else self:Show(current and current.key or "overview") end
end

-- keep the overview tiles live while the window is open
C_Timer.NewTicker(1, function()
    if win and win:IsShown() and current and current.key == "overview" then current:Refresh() end
end)
