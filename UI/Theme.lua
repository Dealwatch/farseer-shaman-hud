--[[
    Farseer - theme
    Palette, accents, fonts and the small drawing helpers every frame uses:
    flat surfaces with 1px borders, bars, icons and a pulse glow.
]]

local _, NS = ...

local UI = {}
NS.UI = UI

UI.WHITE = "Interface\\Buttons\\WHITE8X8"

UI.TEXTURES = {
    { key = "smooth",   label = "Smooth (flat)", path = "Interface\\Buttons\\WHITE8X8" },
    { key = "blizzard", label = "Blizzard",      path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { key = "raid",     label = "Raid bar",      path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
}

UI.FONTS = {
    { key = "Fonts\\FRIZQT__.TTF", label = "Friz Quadrata" },
    { key = "Fonts\\ARIALN.TTF",   label = "Arial Narrow" },
    { key = "Fonts\\skurri.ttf",   label = "Skurri" },
    { key = "Fonts\\MORPHEUS.TTF", label = "Morpheus" },
}

UI.palette = {
    bg       = { 0.039, 0.051, 0.067, 0.94 },
    surface  = { 0.071, 0.086, 0.106, 0.97 },
    surface2 = { 0.098, 0.118, 0.145, 1 },
    surface3 = { 0.137, 0.161, 0.196, 1 },
    track    = { 0.027, 0.035, 0.047, 0.90 },
    border   = { 0.165, 0.200, 0.243, 1 },
    text     = { 0.925, 0.937, 0.953, 1 },
    textDim  = { 0.600, 0.643, 0.698, 1 },
    textMute = { 0.420, 0.459, 0.510, 1 },
    good     = { 0.333, 0.851, 0.522, 1 },
    warn     = { 1.000, 0.737, 0.282, 1 },
    danger   = { 0.969, 0.357, 0.357, 1 },
}

-- Accent presets: Shaman blue plus the four elements.
UI.ACCENTS = {
    { key = "shaman", label = "Shaman",  color = { 0.000, 0.592, 1.000 } },
    { key = "air",    label = "Air",     color = { 0.700, 0.880, 1.000 } },
    { key = "water",  label = "Water",   color = { 0.200, 0.780, 0.860 } },
    { key = "fire",   label = "Fire",    color = { 1.000, 0.490, 0.180 } },
    { key = "earth",  label = "Earth",   color = { 0.800, 0.620, 0.380 } },
}

function UI:Accent()
    local key = NS.db and NS.db.appearance.accent or "shaman"
    for _, a in ipairs(self.ACCENTS) do
        if a.key == key then return a.color[1], a.color[2], a.color[3] end
    end
    return 0, 0.592, 1
end

function UI:BarTexture()
    local key = NS.db and NS.db.appearance.texture or "smooth"
    for _, t in ipairs(self.TEXTURES) do
        if t.key == key then return t.path end
    end
    return self.WHITE
end

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------

local fontStrings = setmetatable({}, { __mode = "k" })   -- fs -> { size, flags }

function UI:Font(fs, size, flags)
    fontStrings[fs] = { size = size, flags = flags or "" }
    local a = NS.db and NS.db.appearance
    local path = a and a.font or "Fonts\\FRIZQT__.TTF"
    local scale = a and a.fontScale or 1
    if not fs:SetFont(path, size * scale, flags or "") then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size * scale, flags or "")
    end
    return fs
end

function UI:Text(parent, size, color, flags, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    self:Font(fs, size or 12, flags)
    local c = color or self.palette.text
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

---------------------------------------------------------------------------
-- Surfaces
---------------------------------------------------------------------------

-- Rounded corners come from small white textures drawn as nine-slices
-- (Texture:SetTextureSliceMargins). Shapes, by the smallest size they fit:
--   lg  radius 10 - windows, cards, buttons, alerts (needs >= 24px)
--   sm  radius 4  - icons, normal bars            (needs >= 12px)
--   xs  radius 2  - thin bars, pips               (needs >= 6px)
--   flat          - square, for anything thinner
UI.SHAPE_MARGIN = { lg = 12, sm = 6, xs = 3 }
local canSlice = nil

local function sliced(tex, base, shape)
    local m = UI.SHAPE_MARGIN[shape]
    if canSlice == nil then canSlice = tex.SetTextureSliceMargins ~= nil end
    if not (m and canSlice) then return false end
    tex:SetTexture(NS.MEDIA .. "Media\\" .. base .. "_" .. shape)
    tex:SetTextureSliceMargins(m, m, m, m)
    if tex.SetTextureSliceMode then
        tex:SetTextureSliceMode(Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched or 0)
    end
    return true
end
UI.Sliced = sliced

-- Filled texture of a shape (for highlights inside rounded frames).
function UI:ShapeTexture(parent, shape, layer, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    if not sliced(t, "Fill", shape) then t:SetTexture(self.WHITE) end
    return t
end

local function flatEdges(frame, thickness)
    local b = {}
    for i = 1, 4 do
        b[i] = frame:CreateTexture(nil, "BORDER", nil, 7)
        b[i]:SetTexture(UI.WHITE)
    end
    b[1]:SetPoint("TOPLEFT"); b[1]:SetPoint("TOPRIGHT"); b[1]:SetHeight(thickness)
    b[2]:SetPoint("BOTTOMLEFT"); b[2]:SetPoint("BOTTOMRIGHT"); b[2]:SetHeight(thickness)
    b[3]:SetPoint("TOPLEFT"); b[3]:SetPoint("BOTTOMLEFT"); b[3]:SetWidth(thickness)
    b[4]:SetPoint("TOPRIGHT"); b[4]:SetPoint("BOTTOMRIGHT"); b[4]:SetWidth(thickness)
    return b
end

-- Background plus a 1px border in the given shape (default "sm").
function UI:Skin(frame, bg, border, shape)
    bg = bg or self.palette.surface
    border = border or self.palette.border
    if not frame.sfBg then
        shape = shape or "sm"
        frame.sfShape = shape
        frame.sfBg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        frame.sfBg:SetAllPoints()
        if not sliced(frame.sfBg, "Fill", shape) then frame.sfBg:SetTexture(self.WHITE) end
        local edge = frame:CreateTexture(nil, "BORDER", nil, 7)
        edge:SetAllPoints()
        if sliced(edge, "Border", shape) then
            frame.sfBorder = { edge }
        else
            edge:Hide()
            frame.sfBorder = flatEdges(frame, 1)
        end
    end
    frame.sfBg:SetVertexColor(bg[1], bg[2], bg[3], bg[4] or 1)
    self:SetBorderColor(frame, border[1], border[2], border[3], border[4] or 1)
    return frame
end

function UI:SetBorderColor(frame, r, g, b, a)
    if not frame.sfBorder then return end
    for _, t in ipairs(frame.sfBorder) do t:SetVertexColor(r, g, b, a or 1) end
end

-- Soft drop shadow around a frame (a few stacked translucent rounded rects).
function UI:Shadow(frame)
    if frame.sfShadow then return end
    frame.sfShadow = {}
    for i = 1, 3 do
        local t = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        if not sliced(t, "Fill", "lg") then t:SetTexture(self.WHITE) end
        t:SetVertexColor(0, 0, 0, 0.16)
        t:SetPoint("TOPLEFT", -i * 2, i * 2)
        t:SetPoint("BOTTOMRIGHT", i * 2, -i * 2)
        frame.sfShadow[i] = t
    end
end

---------------------------------------------------------------------------
-- Bars
---------------------------------------------------------------------------

local bars = setmetatable({}, { __mode = "k" })

function UI:Bar(parent, w, h)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(w, h)
    bar:SetStatusBarTexture(self:BarTexture())
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    self:Skin(bar, self.palette.track, self.palette.border, h >= 12 and "sm" or h >= 6 and "xs" or "flat")
    bar.spark = bar:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture(self.WHITE)
    bar.spark:SetVertexColor(1, 1, 1, 0.9)
    bar.spark:SetSize(2, h)
    bar.spark:Hide()
    bars[bar] = true
    return bar
end

---------------------------------------------------------------------------
-- Icons
---------------------------------------------------------------------------

function UI:Icon(parent, size, template, name)
    local f = CreateFrame(template and "Button" or "Frame", name, parent, template)
    f:SetSize(size, size)
    self:Skin(f, self.palette.track, self.palette.border)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 1, -1)
    f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return f
end

function UI:Cooldown(parent)
    local cd = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
    cd:SetPoint("TOPLEFT", 1, -1)
    cd:SetPoint("BOTTOMRIGHT", -1, 1)
    cd:SetDrawEdge(false)
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    return cd
end

---------------------------------------------------------------------------
-- Pulse glow (accent border that breathes)
---------------------------------------------------------------------------

function UI:Glow(frame, r, g, b)
    if not frame.sfGlow then
        local glow = CreateFrame("Frame", nil, frame)
        glow:SetPoint("TOPLEFT", -3, 3)
        glow:SetPoint("BOTTOMRIGHT", 3, -3)
        glow:SetFrameLevel(frame:GetFrameLevel() + 5)
        local ring = glow:CreateTexture(nil, "OVERLAY")
        ring:SetAllPoints()
        if sliced(ring, "Glow", frame.sfShape == "lg" and "lg" or "sm") then
            glow.sfBorder = { ring }
        else
            ring:Hide()
            glow.sfBorder = flatEdges(glow, 2)
        end
        local ag = glow:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(1)
        a:SetToAlpha(0.25)
        a:SetDuration(0.45)
        glow.anim = ag
        glow:Hide()
        frame.sfGlow = glow
    end
    local glow = frame.sfGlow
    if r then
        self:SetBorderColor(glow, r, g, b, 1)
        glow:Show()
        glow.anim:Play()
    else
        glow.anim:Stop()
        glow:Hide()
    end
end

---------------------------------------------------------------------------
-- Frames that host a native aura container: never Show/Hide them in combat
-- (the container may count as protected), fade them instead.
---------------------------------------------------------------------------

UI.nativeHosts = {}

function UI:NativeHost(frame)
    self.nativeHosts[#self.nativeHosts + 1] = frame
end

function UI:SafeShow(frame, show)
    show = show and true or false
    if NS.InCombat() then
        -- in combat these frames are never hidden, only faded; Show() still works
        -- in the moment between PLAYER_REGEN_DISABLED and the lockdown
        if not frame:IsShown() and not InCombatLockdown() then frame:Show() end
        frame:SetAlpha(show and 1 or 0)
    else
        frame:SetAlpha(1)
        frame:SetShown(show)
    end
end

-- right before combat locks down: hidden hosts become shown but invisible,
-- so they can still appear in combat by alpha alone
NS:On("PLAYER_REGEN_DISABLED", function()
    for _, f in ipairs(UI.nativeHosts) do
        if not f:IsShown() then f:SetAlpha(0); f:Show() end
    end
end)

---------------------------------------------------------------------------
-- Sounds
---------------------------------------------------------------------------

function UI:Sound(kit)
    if not (NS.db and NS.db.appearance.sounds) then return end
    local id = SOUNDKIT and SOUNDKIT[kit] or kit
    if type(id) == "number" then pcall(PlaySound, id, "Master") end
end

---------------------------------------------------------------------------
-- HUD root: every HUD frame hangs from it, so out of combat the whole HUD
-- hides (or fades) as one. Alerts and the imbue buttons live outside it:
-- they are the basics that stay. Only shown/hidden out of combat (it holds
-- secure buttons); in combat it is always shown.
---------------------------------------------------------------------------

UI.root = CreateFrame("Frame", "FarseerHUDHUD", UIParent)
UI.root:SetAllPoints(UIParent)

local function hostileTarget()
    if not UnitExists("target") then return false end
    local ok, can = pcall(UnitCanAttack, "player", "target")
    if not ok then return false end
    if NS.IsSecret(can) then return true end
    return can and true or false
end

function UI:UpdateFade(forceActive)
    if not NS.db then return end
    local a = NS.db.appearance
    local active = forceActive or NS.InCombat() or NS.editing
        or (NS.Options and NS.Options:IsShown()) or (a.showOnTarget and hostileTarget())
    if active then
        self.root:Show()
        self.root:SetAlpha(1)
    else
        -- only reached out of combat, where hiding secure children is allowed;
        -- hiding (not alpha 0) also keeps invisible buttons from catching clicks
        self.root:SetShown(a.idleAlpha > 0.01)
        self.root:SetAlpha(a.idleAlpha)
    end
end

NS:On("PLAYER_REGEN_DISABLED", function() UI:UpdateFade(true) end)
NS:On("PLAYER_REGEN_ENABLED", function() UI:UpdateFade() end)
NS:On("PLAYER_TARGET_CHANGED", function() UI:UpdateFade() end)
NS:On("SF_APPLIED", function() UI:UpdateFade() end)

---------------------------------------------------------------------------
-- HUD frames (scaled together, re-skinned on appearance changes)
---------------------------------------------------------------------------

UI.hud = {}

function UI:RegisterHUD(frame)
    self.hud[#self.hud + 1] = frame
    frame:SetScale(NS.db and NS.db.appearance.scale or 1)
end

function UI:ApplyAppearance()
    local scale = NS.db.appearance.scale or 1
    for _, f in ipairs(self.hud) do
        NS.AfterCombat("scale" .. tostring(f), function() f:SetScale(scale) end)
    end
    for fs, info in pairs(fontStrings) do self:Font(fs, info.size, info.flags) end
    local tex = self:BarTexture()
    for bar in pairs(bars) do bar:SetStatusBarTexture(tex) end
    NS:Send("SF_APPEARANCE")
end
