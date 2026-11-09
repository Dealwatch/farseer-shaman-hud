--[[
    ShammyForever - edit mode
    Every HUD frame registers here. In edit mode each one gets an overlay you
    can drag (snaps to the grid, Shift = free), nudge with the arrow keys
    (Shift = 10px) or right-click to reset. Not available in combat, because
    several frames are secure buttons.
]]

local _, NS = ...
local UI = NS.UI

local Movers = { list = {}, byKey = {} }
NS.Movers = Movers

local function save(entry)
    local f = entry.frame
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and ux) then return end
    local x, y = cx - ux / s, cy - uy / s
    NS.db.positions[entry.key] = { x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
end

local function place(entry)
    local f = entry.frame
    local pos = NS.db and NS.db.positions[entry.key]
    f:ClearAllPoints()
    if pos then
        f:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
    else
        local d = entry.default
        f:SetPoint(d[1], UIParent, d[2] or d[1], d[3] or 0, d[4] or 0)
    end
end

local function snap(entry)
    local grid = NS.db.appearance.grid or 16
    local pos = NS.db.positions[entry.key]
    if not pos or grid < 2 or IsShiftKeyDown() then return end
    pos.x = math.floor(pos.x / grid + 0.5) * grid
    pos.y = math.floor(pos.y / grid + 0.5) * grid
end

---------------------------------------------------------------------------
-- Overlay per frame
---------------------------------------------------------------------------

local function makeOverlay(entry)
    local o = CreateFrame("Button", nil, entry.frame)
    o:SetAllPoints()
    o:SetFrameLevel(entry.frame:GetFrameLevel() + 30)
    UI:Skin(o, { 0, 0, 0, 0.35 }, { 1, 1, 1, 1 })
    o.label = UI:Text(o, 11, UI.palette.text, "OUTLINE")
    o.label:SetPoint("CENTER")
    o.label:SetText(entry.label)
    o:RegisterForClicks("AnyUp")
    o:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        Movers:Select(entry)
        entry.frame:SetMovable(true)
        entry.frame:StartMoving()
        o.moving = true
    end)
    o:SetScript("OnMouseUp", function(_, button)
        if o.moving then
            o.moving = false
            entry.frame:StopMovingOrSizing()
            save(entry)
            snap(entry)
            place(entry)
        elseif button == "RightButton" then
            NS.db.positions[entry.key] = nil
            place(entry)
        end
    end)
    o:Hide()
    entry.overlay = o
end

function Movers:Select(entry)
    self.selected = entry
    local r, g, b = UI:Accent()
    for _, e in ipairs(self.list) do
        if e.overlay then
            if e == entry then UI:SetBorderColor(e.overlay, r, g, b, 1)
            else UI:SetBorderColor(e.overlay, 1, 1, 1, 0.6) end
        end
    end
end

-- frame: the HUD frame; key: saved position key; label: overlay text;
-- default: { point, relativePoint, x, y } on UIParent.
function Movers:Register(frame, key, label, default)
    local entry = { frame = frame, key = key, label = label, default = default }
    self.list[#self.list + 1] = entry
    self.byKey[key] = entry
    frame:SetClampedToScreen(true)
    place(entry)
    UI:RegisterHUD(frame)
    return entry
end

function Movers:RestoreAll()
    for _, e in ipairs(self.list) do
        NS.AfterCombat("place" .. e.key, function() place(e) end)
    end
end

---------------------------------------------------------------------------
-- Grid and header
---------------------------------------------------------------------------

local grid, header

local function buildGrid()
    grid = CreateFrame("Frame", nil, UIParent)
    grid:SetAllPoints()
    grid:SetFrameStrata("BACKGROUND")
    grid.lines = {}
    grid:Hide()
end

function Movers:DrawGrid()
    for _, l in ipairs(grid.lines) do l:Hide() end
    local step = NS.db.appearance.grid or 16
    if step < 2 or not self.showGrid then return end
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local n = 0
    local function line(vertical, offset, center)
        n = n + 1
        local l = grid.lines[n]
        if not l then
            l = grid:CreateTexture(nil, "BACKGROUND")
            l:SetTexture(UI.WHITE)
            grid.lines[n] = l
        end
        l:ClearAllPoints()
        if vertical then
            l:SetPoint("TOP", grid, "TOP", offset, 0); l:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0); l:SetWidth(1)
        else
            l:SetPoint("LEFT", grid, "LEFT", 0, offset); l:SetPoint("RIGHT", grid, "RIGHT", 0, offset); l:SetHeight(1)
        end
        if center then
            local r, g, b = UI:Accent()
            l:SetVertexColor(r, g, b, 0.6)
        else
            l:SetVertexColor(1, 1, 1, 0.07)
        end
        l:Show()
    end
    for x = 0, w / 2, step do
        line(true, x, x == 0)
        if x > 0 then line(true, -x) end
    end
    for y = 0, h / 2, step do
        line(false, y, y == 0)
        if y > 0 then line(false, -y) end
    end
end

local function headerButton(parent, text, primary, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(96, 26)
    if primary then
        local r, g, bl = UI:Accent()
        UI:Skin(b, { r, g, bl, 1 }, { r, g, bl, 1 })
    else
        UI:Skin(b, UI.palette.surface3, UI.palette.border)
    end
    b.text = UI:Text(b, 12, primary and { 0.02, 0.05, 0.08, 1 } or UI.palette.text)
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function buildHeader()
    header = CreateFrame("Frame", nil, UIParent)
    header:SetSize(560, 52)
    header:SetPoint("TOP", 0, -40)
    header:SetFrameStrata("DIALOG")
    UI:Skin(header, UI.palette.surface, UI.palette.border)
    UI:Shadow(header)

    local title = UI:Text(header, 14)
    title:SetPoint("TOPLEFT", 16, -10)
    title:SetText("Edit Mode")
    local sub = UI:Text(header, 11, UI.palette.textDim)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    sub:SetText("Drag frames - arrows nudge - right-click resets - Shift = free")

    local done = headerButton(header, "Done", true, function() Movers:Toggle(false) end)
    done:SetPoint("RIGHT", -12, 0)
    local reset = headerButton(header, "Reset all", false, function()
        wipe(NS.db.positions)
        for _, e in ipairs(Movers.list) do place(e) end
    end)
    reset:SetPoint("RIGHT", done, "LEFT", -8, 0)
    local gridBtn
    gridBtn = headerButton(header, "Grid: on", false, function()
        Movers.showGrid = not Movers.showGrid
        gridBtn.text:SetText(Movers.showGrid and "Grid: on" or "Grid: off")
        Movers:DrawGrid()
    end)
    gridBtn:SetPoint("RIGHT", reset, "LEFT", -8, 0)

    -- arrow-key nudging of the selected frame
    header:EnableKeyboard(true)
    header:SetScript("OnKeyDown", function(self, key)
        local e = Movers.selected
        local d = IsShiftKeyDown() and 10 or 1
        local dx, dy = 0, 0
        if key == "LEFT" then dx = -d elseif key == "RIGHT" then dx = d
        elseif key == "UP" then dy = d elseif key == "DOWN" then dy = -d
        elseif key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            Movers:Toggle(false)
            return
        end
        if e and (dx ~= 0 or dy ~= 0) then
            self:SetPropagateKeyboardInput(false)
            save(e)
            local pos = NS.db.positions[e.key]
            pos.x, pos.y = pos.x + dx, pos.y + dy
            place(e)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    header:Hide()
end

function Movers:Toggle(on)
    if on == nil then on = not self.active end
    if on and InCombatLockdown() then
        NS.Print("edit mode is not available in combat.")
        return
    end
    if not grid then buildGrid(); buildHeader() end
    self.active = on
    NS.editing = on
    if on then self.showGrid = true end
    for _, e in ipairs(self.list) do
        if not e.overlay then makeOverlay(e) end
        e.overlay:SetShown(on)
        if on then UI:SetBorderColor(e.overlay, 1, 1, 1, 0.6) end
    end
    header:SetShown(on)
    grid:SetShown(on)
    if on then self:DrawGrid() end
    NS:ApplyAll()   -- modules show their frames (with preview data) while editing
end

NS:On("PLAYER_REGEN_DISABLED", function()
    if Movers.active then
        Movers:Toggle(false)
        NS.Print("left edit mode (combat).")
    end
end)
