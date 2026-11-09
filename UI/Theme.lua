--[[
    ShammyForever - theme
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

-- Flat background plus a 1px border. Returns the border textures so callers
-- can recolor them (accent highlights, glows).
function UI:Skin(frame, bg, border)
    bg = bg or self.palette.surface
    border = border or self.palette.border
    if not frame.sfBg then
        frame.sfBg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        frame.sfBg:SetTexture(self.WHITE)
        frame.sfBg:SetAllPoints()
        local b = {}
        for i = 1, 4 do
            b[i] = frame:CreateTexture(nil, "BORDER", nil, 7)
            b[i]:SetTexture(self.WHITE)
        end
        b[1]:SetPoint("TOPLEFT"); b[1]:SetPoint("TOPRIGHT"); b[1]:SetHeight(1)
        b[2]:SetPoint("BOTTOMLEFT"); b[2]:SetPoint("BOTTOMRIGHT"); b[2]:SetHeight(1)
        b[3]:SetPoint("TOPLEFT"); b[3]:SetPoint("BOTTOMLEFT"); b[3]:SetWidth(1)
        b[4]:SetPoint("TOPRIGHT"); b[4]:SetPoint("BOTTOMRIGHT"); b[4]:SetWidth(1)
        frame.sfBorder = b
    end
    frame.sfBg:SetVertexColor(bg[1], bg[2], bg[3], bg[4] or 1)
    self:SetBorderColor(frame, border[1], border[2], border[3], border[4] or 1)
    return frame
end

function UI:SetBorderColor(frame, r, g, b, a)
    if not frame.sfBorder then return end
    for i = 1, 4 do frame.sfBorder[i]:SetVertexColor(r, g, b, a or 1) end
end

-- Soft drop shadow around a frame (a few stacked translucent rects).
function UI:Shadow(frame)
    if frame.sfShadow then return end
    frame.sfShadow = {}
    for i = 1, 3 do
        local t = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        t:SetTexture(self.WHITE)
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
    self:Skin(bar, self.palette.track, self.palette.border)
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

function UI:Icon(parent, size, template)
    local f = CreateFrame(template and "Button" or "Frame", nil, parent, template)
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
        self:Skin(glow, { 0, 0, 0, 0 }, { 1, 1, 1, 1 })
        for i = 1, 4 do
            if i <= 2 then glow.sfBorder[i]:SetHeight(2) else glow.sfBorder[i]:SetWidth(2) end
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
-- Sounds
---------------------------------------------------------------------------

function UI:Sound(kit)
    if not (NS.db and NS.db.appearance.sounds) then return end
    local id = SOUNDKIT and SOUNDKIT[kit] or kit
    if type(id) == "number" then pcall(PlaySound, id, "Master") end
end

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
