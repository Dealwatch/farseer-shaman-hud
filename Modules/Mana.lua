--[[
    Farseer - mana bar
    A thin bar in the HUD column. Your own mana is not secret on Forever, but
    if it ever is, the values still go straight into the bar (StatusBar setters
    accept secrets); only the low-mana tint and the percentage need readable
    numbers.
]]

local _, NS = ...
local UI = NS.UI

local Mana = NS:NewModule("mana", {
    title = "Mana Bar",
    desc = "Thin mana bar, red when low, hides at full",
    icon = "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
})

local frame, bar
local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local COLOR = { 0.25, 0.55, 1.0 }

function Mana:Init()
    frame = CreateFrame("Frame", "FarseerHUDMana", UIParent)
    frame:Hide()
    self.frame = frame
    bar = UI:Bar(frame, NS.db.mana.width, NS.db.mana.height)
    bar:SetAllPoints()
    bar:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3])
    self.bar = bar
    bar.text = UI:Text(bar, 10, UI.palette.text, "OUTLINE")
    bar.text:SetPoint("CENTER")
    bar.text:SetJustifyH("CENTER")
    NS.Movers:Register(frame, "mana", "Mana", { "CENTER", "CENTER", 0, -158 })

    local function update() self:Update() end
    NS:OnUnit("UNIT_POWER_FREQUENT", "player", update)
    NS:OnUnit("UNIT_MAXPOWER", "player", update)
    NS:OnUnit("UNIT_DISPLAYPOWER", "player", update)
    NS:On("PLAYER_REGEN_DISABLED", function() self:Update(true) end)
    NS:On("PLAYER_REGEN_ENABLED", update)
    NS:On("PLAYER_ENTERING_WORLD", update)
end

-- Returns the readable fraction (0..1) or nil.
function Mana.Fraction()
    local cur, max = UnitPower("player", MANA), UnitPowerMax("player", MANA)
    cur, max = NS.Readable(cur), NS.Readable(max)
    if cur and max and max > 0 then return cur / max end
end

function Mana:Update(enteringCombat)
    if not frame then return end
    local db = NS.db.mana
    local cur, max = UnitPower("player", MANA), UnitPowerMax("player", MANA)
    pcall(bar.SetMinMaxValues, bar, 0, max)
    pcall(bar.SetValue, bar, cur)

    local frac = Mana.Fraction()
    if NS.editing then frac = frac or 0.7 end
    local inCombat = enteringCombat or NS.InCombat()
    local full = frac and frac >= 0.999
    local show = NS:IsEnabled("mana") and (NS.editing or inCombat or not db.hideFull or not full)
    frame:SetShown(show and true or false)
    if not show then return end

    if frac and frac * 100 < db.lowPct then
        bar:SetStatusBarColor(UI.palette.danger[1], UI.palette.danger[2], UI.palette.danger[3])
    else
        bar:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3])
    end
    bar.text:SetShown(db.showText and db.height >= 9)
    bar.text:SetText(frac and string.format("%d%%", math.floor(frac * 100 + 0.5)) or "")
end

function Mana:Apply()
    if not frame then return end
    local db = NS.db.mana
    frame:SetSize(db.width, db.height)
    bar.spark:SetHeight(db.height)
    self:Update()
end
