--[[
    Farseer - settings widgets
    Cards with rows: toggle, slider, dropdown, segmented choice, button.
    Every widget has :Refresh() which re-reads its value from the settings.
]]

local _, NS = ...
local UI = NS.UI

local W = {}
NS.Widgets = W

local P = UI.palette
local ROW_PAD = 16

local function accent() return UI:Accent() end

---------------------------------------------------------------------------
-- Row base: label (+ optional description) on the left, control on the right
---------------------------------------------------------------------------

local function row(parent, label, desc)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(desc and 52 or 40)
    f.label = UI:Text(f, 13)
    f.label:SetText(label)
    if desc then
        f.label:SetPoint("TOPLEFT", ROW_PAD, -9)
        f.desc = UI:Text(f, 11, P.textDim)
        f.desc:SetPoint("TOPLEFT", f.label, "BOTTOMLEFT", 0, -4)
        f.desc:SetPoint("RIGHT", f, "RIGHT", -260, 0)
        f.desc:SetWordWrap(true)
        f.desc:SetText(desc)
    else
        f.label:SetPoint("LEFT", ROW_PAD, 0)
    end
    f.sep = f:CreateTexture(nil, "ARTWORK")
    f.sep:SetTexture(UI.WHITE)
    f.sep:SetVertexColor(1, 1, 1, 0.06)
    f.sep:SetPoint("TOPLEFT", ROW_PAD, 0)
    f.sep:SetPoint("TOPRIGHT", -ROW_PAD, 0)
    f.sep:SetHeight(1)
    return f
end

---------------------------------------------------------------------------
-- Toggle switch
---------------------------------------------------------------------------

function W.Switch(parent, get, set)
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(46, 24)
    UI:Skin(s, P.surface3, P.border, "lg")
    s.knob = s:CreateTexture(nil, "OVERLAY")
    s.knob:SetTexture(NS.MEDIA .. "Media\\Circle")
    s.knob:SetSize(18, 18)
    function s:Refresh()
        local on = get()
        self.knob:ClearAllPoints()
        if on then
            local r, g, b = accent()
            self.sfBg:SetVertexColor(r, g, b, 1)
            UI:SetBorderColor(self, r, g, b, 1)
            self.knob:SetPoint("RIGHT", -3, 0)
            self.knob:SetVertexColor(1, 1, 1, 1)
        else
            self.sfBg:SetVertexColor(P.surface3[1], P.surface3[2], P.surface3[3], 1)
            UI:SetBorderColor(self, P.border[1], P.border[2], P.border[3], 1)
            self.knob:SetPoint("LEFT", 3, 0)
            self.knob:SetVertexColor(0.75, 0.78, 0.82, 1)
        end
    end
    s:SetScript("OnClick", function(self)
        set(not get())
        self:Refresh()
        UI:Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    end)
    s:Refresh()
    return s
end

function W.Toggle(parent, label, desc, get, set)
    local f = row(parent, label, desc)
    f.switch = W.Switch(f, get, set)
    f.switch:SetPoint("RIGHT", -ROW_PAD, 0)
    function f:Refresh() self.switch:Refresh() end
    return f
end

---------------------------------------------------------------------------
-- Slider
---------------------------------------------------------------------------

-- fmt comes before get/set: bind() returns both and must be the last argument
function W.Slider(parent, label, desc, min, max, step, fmt, get, set)
    local f = row(parent, label, desc)
    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(180, 16)
    s:SetPoint("RIGHT", -70, 0)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s.track = s:CreateTexture(nil, "BACKGROUND")
    if not UI.Sliced(s.track, "Fill", "xs") then s.track:SetTexture(UI.WHITE) end
    s.track:SetVertexColor(P.surface3[1], P.surface3[2], P.surface3[3], 1)
    s.track:SetPoint("LEFT"); s.track:SetPoint("RIGHT"); s.track:SetHeight(6)
    s.fill = s:CreateTexture(nil, "ARTWORK")
    if not UI.Sliced(s.fill, "Fill", "xs") then s.fill:SetTexture(UI.WHITE) end
    s.fill:SetPoint("LEFT"); s.fill:SetHeight(6)
    s:SetThumbTexture(UI.WHITE)
    local thumb = s:GetThumbTexture()
    thumb:SetTexture(NS.MEDIA .. "Media\\Circle")
    thumb:SetSize(14, 14)
    thumb:SetVertexColor(1, 1, 1, 1)
    f.value = UI:Text(f, 13)
    f.value:SetPoint("RIGHT", -ROW_PAD, 0)
    f.value:SetJustifyH("RIGHT")
    local function show(v)
        f.value:SetText(fmt and fmt(v) or tostring(v))
        local pct = (v - min) / (max - min)
        s.fill:SetWidth(math.max(pct * s:GetWidth(), 1))
        local r, g, b = accent()
        s.fill:SetVertexColor(r, g, b, 1)
    end
    -- save whatever differs from the setting (SetValue from Refresh lands here too)
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        show(v)
        if v ~= get() then set(v) end
    end)
    function f:Refresh()
        local v = get()
        s:SetValue(v)
        show(v)
    end
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(_, delta)
        local v = math.min(max, math.max(min, get() + delta * step))
        set(v); f:Refresh()
    end)
    f.slider = s
    f:Refresh()
    return f
end

---------------------------------------------------------------------------
-- Dropdown (one shared popup list)
---------------------------------------------------------------------------

local menu

local function closeMenu() if menu then menu:Hide() end end
W.CloseMenu = closeMenu

local function openMenu(owner, options, get, set, onChange)
    if not menu then
        menu = CreateFrame("Frame", nil, UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetClampedToScreen(true)
        UI:Skin(menu, P.surface2, P.border, "lg")
        UI:Shadow(menu)
        menu.items = {}
        menu:EnableMouse(true)
    end
    if menu:IsShown() and menu.owner == owner then menu:Hide() return end
    menu.owner = owner
    local w = owner:GetWidth()
    for i, opt in ipairs(options) do
        local it = menu.items[i]
        if not it then
            it = CreateFrame("Button", nil, menu)
            it:SetHeight(26)
            it.hl = UI:ShapeTexture(it, "sm")
            it.hl:SetAllPoints()
            it.hl:SetVertexColor(1, 1, 1, 0.06)
            it.hl:Hide()
            it.text = UI:Text(it, 12)
            it.text:SetPoint("LEFT", 10, 0)
            it:SetScript("OnEnter", function(self) self.hl:Show() end)
            it:SetScript("OnLeave", function(self) self.hl:Hide() end)
            menu.items[i] = it
        end
        it:ClearAllPoints()
        it:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 26)
        it:SetWidth(w - 8)
        it.text:SetText(opt.label)
        local r, g, b = accent()
        if opt.value == get() then it.text:SetTextColor(r, g, b, 1) else it.text:SetTextColor(P.text[1], P.text[2], P.text[3], 1) end
        it:SetScript("OnClick", function()
            set(opt.value)
            menu:Hide()
            if onChange then onChange() end
        end)
        it:Show()
    end
    for i = #options + 1, #menu.items do menu.items[i]:Hide() end
    menu:SetSize(w, #options * 26 + 8)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    menu:Show()
end

function W.Dropdown(parent, label, desc, options, get, set)
    local f = row(parent, label, desc)
    local b = CreateFrame("Button", nil, f)
    b:SetSize(220, 28)
    b:SetPoint("RIGHT", -ROW_PAD, 0)
    UI:Skin(b, P.surface3, P.border, "lg")
    b.text = UI:Text(b, 12)
    b.text:SetPoint("LEFT", 10, 0)
    b.text:SetPoint("RIGHT", -24, 0)
    b.arrow = UI:Text(b, 12, P.textDim)
    b.arrow:SetPoint("RIGHT", -10, 0)
    b.arrow:SetText("v")
    function f:Refresh()
        local v = get()
        local opts = type(options) == "function" and options() or options
        for _, o in ipairs(opts) do
            if o.value == v then b.text:SetText(o.label) return end
        end
        b.text:SetText(tostring(v))
    end
    b:SetScript("OnClick", function()
        local opts = type(options) == "function" and options() or options
        openMenu(b, opts, get, set, function() f:Refresh() end)
    end)
    b:SetScript("OnHide", closeMenu)
    f:Refresh()
    return f
end

---------------------------------------------------------------------------
-- Segmented choice
---------------------------------------------------------------------------

function W.Segment(parent, label, desc, options, get, set)
    local f = row(parent, label, desc)
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(#options * 90 + 4, 28)
    holder:SetPoint("RIGHT", -ROW_PAD, 0)
    UI:Skin(holder, P.surface3, P.border, "lg")
    f.buttons = {}
    for i, opt in ipairs(options) do
        local b = CreateFrame("Button", nil, holder)
        b:SetSize(88, 24)
        b:SetPoint("LEFT", 2 + (i - 1) * 90, 0)
        b.bg = UI:ShapeTexture(b, "lg")
        b.bg:SetAllPoints()
        b.text = UI:Text(b, 12)
        b.text:SetPoint("CENTER")
        b.text:SetJustifyH("CENTER")
        b.text:SetText(opt.label)
        b:SetScript("OnClick", function() set(opt.value); f:Refresh() end)
        b.value = opt.value
        f.buttons[i] = b
    end
    function f:Refresh()
        local v = get()
        local r, g, bl = accent()
        for _, b in ipairs(self.buttons) do
            if b.value == v then
                b.bg:SetVertexColor(r, g, bl, 1)
                b.text:SetTextColor(0.02, 0.05, 0.08, 1)
            else
                b.bg:SetVertexColor(0, 0, 0, 0)
                b.text:SetTextColor(P.text[1], P.text[2], P.text[3], 1)
            end
        end
    end
    f:Refresh()
    return f
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

function W.Button(parent, text, primary, onClick, width)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 150, 32)
    b.text = UI:Text(b, 13)
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b.text:SetText(text)
    function b:Refresh()
        if primary then
            local r, g, bl = accent()
            UI:Skin(self, { r, g, bl, 1 }, { r, g, bl, 1 }, "lg")
            self.text:SetTextColor(0.02, 0.05, 0.08, 1)
        else
            UI:Skin(self, P.surface3, P.border, "lg")
            self.text:SetTextColor(P.text[1], P.text[2], P.text[3], 1)
        end
    end
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self) self.sfBg:SetAlpha(0.85) end)
    b:SetScript("OnLeave", function(self) self.sfBg:SetAlpha(1) end)
    b:Refresh()
    return b
end

function W.ButtonRow(parent, label, desc, text, onClick)
    local f = row(parent, label, desc)
    f.button = W.Button(f, text, false, onClick, 180)
    f.button:SetPoint("RIGHT", -ROW_PAD, 0)
    function f:Refresh() self.button:Refresh() end
    return f
end

---------------------------------------------------------------------------
-- Card: a titled section that stacks rows. Optional master toggle.
---------------------------------------------------------------------------

function W.Card(parent, title, icon, get, set)
    local c = CreateFrame("Frame", nil, parent)
    UI:Skin(c, P.surface2, P.border, "lg")
    c.rows = {}
    c.head = 48
    c.iconFrame = UI:Icon(c, 24)
    c.iconFrame:SetPoint("TOPLEFT", ROW_PAD, -12)
    c.iconFrame.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    c.title = UI:Text(c, 15)
    c.title:SetPoint("LEFT", c.iconFrame, "RIGHT", 10, 0)
    c.title:SetText(title)
    if get then
        c.switch = W.Switch(c, get, set)
        c.switch:SetPoint("TOPRIGHT", -ROW_PAD, -12)
    end
    function c:Add(w)
        self.rows[#self.rows + 1] = w
        return w
    end
    function c:Layout(width)
        self:SetWidth(width)
        local y = self.head
        for _, w in ipairs(self.rows) do
            w:ClearAllPoints()
            w:SetPoint("TOPLEFT", 0, -y)
            w:SetWidth(width)
            y = y + w:GetHeight()
        end
        self:SetHeight(y + 8)
        return y + 8
    end
    function c:Refresh()
        if self.switch then self.switch:Refresh() end
        for _, w in ipairs(self.rows) do if w.Refresh then w:Refresh() end end
    end
    return c
end
