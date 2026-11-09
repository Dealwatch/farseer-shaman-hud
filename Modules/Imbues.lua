--[[
    ShammyForever - weapon imbues
    Two buttons, main hand and off hand, with the imbue's time left. Clicking
    one casts your chosen imbue onto that weapon (secure macro, works in combat).
    Warns when an imbue is missing or about to run out.

    On Forever imbues sit next to sharpening stones and oils, so the client
    reports several enchants per weapon; we pick the "Imbue" one.
    C_Item.GetWeaponEnchantInfo is not secret, so this also works in combat.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local Imbues = NS:NewModule("imbues", {
    title = "Weapon Imbues",
    desc = "Imbue timers per hand, click to apply, missing warnings",
    icon = "Interface\\Icons\\Spell_Nature_Cyclone",
})

local HANDS = {
    { key = "mh", label = "Main Hand", inv = 16, slot = 0 },
    { key = "oh", label = "Off Hand",  inv = 17, slot = 1 },
}

local frame
local buttons = {}

local function dualWielding()
    if C_PaperDollInfo and C_PaperDollInfo.OffhandHasWeapon then
        local ok, has = pcall(C_PaperDollInfo.OffhandHasWeapon)
        if ok then return has and true or false end
    end
    return false
end

local function hasWeapon(hand)
    if hand.key == "oh" then return dualWielding() end
    return GetInventoryItemID("player", hand.inv) ~= nil
end

-- Returns hasImbue, secondsLeft (nil when unknown).
function Imbues.Read(hand)
    if C_Item and C_Item.GetWeaponEnchantInfo then
        local slotEnum = Enum.WeaponSlot and (hand.key == "mh" and Enum.WeaponSlot.MainHand or Enum.WeaponSlot.OffHand) or hand.slot
        local ok, res = pcall(C_Item.GetWeaponEnchantInfo, slotEnum)
        if ok and type(res) == "table" then
            local list = res.hasEnchant ~= nil and { res } or res
            local IMBUE = Enum.ItemEnchantType and Enum.ItemEnchantType.Imbue or 3
            local TEMP = Enum.ItemEnchantType and Enum.ItemEnchantType.Temporary or 2
            local best
            for _, e in ipairs(list) do
                local has, kind = NS.Readable(e.hasEnchant), NS.Readable(e.enchantType)
                if has and kind == IMBUE then best = e break end
                if has and kind == TEMP and not best then best = e end
            end
            if best then
                local ms = NS.Readable(best.timeLeft)
                return true, ms and ms / 1000, NS.Readable(best.enchantIconID)
            end
            if #list > 0 then return false end
        end
    end
    if GetWeaponEnchantInfo then
        local ok, hasMH, mhMS, _, _, hasOH, ohMS = pcall(GetWeaponEnchantInfo)
        if ok then
            if hand.key == "mh" then return NS.Readable(hasMH) and true or false, NS.Readable(mhMS) and mhMS / 1000 end
            return NS.Readable(hasOH) and true or false, NS.Readable(ohMS) and ohMS / 1000
        end
    end
    return nil
end

local function fmt(secs)
    if not secs then return "" end
    if secs >= 3600 then return string.format("%dh", math.floor(secs / 3600)) end
    if secs >= 60 then return string.format("%dm", math.floor(secs / 60)) end
    return string.format("%ds", math.floor(secs))
end

local function chosenSpell(hand)
    return Spells:Get(NS.db.imbues[hand.key])
end

local function setSecure(b)
    local def = chosenSpell(b.hand)
    NS.AfterCombat("imbue" .. b.hand.key, function()
        if def and def.known and def.name then
            b:SetAttribute("type", "macro")
            -- /use only matters when the imbue asks which weapon to enchant
            b:SetAttribute("macrotext", "/cast " .. def.name .. "\n/use " .. b.hand.inv)
        else
            b:SetAttribute("type", nil)
        end
    end)
end

local function makeButton(hand)
    local b = UI:Icon(frame, NS.db.imbues.size, "SecureActionButtonTemplate")
    b.hand = hand
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.time = UI:Text(b, 12, UI.palette.text, "OUTLINE")
    b.time:SetPoint("BOTTOM", 0, 2)
    b.time:SetJustifyH("CENTER")
    b.tag = UI:Text(b, 9, UI.palette.textDim, "OUTLINE")
    b.tag:SetPoint("TOPLEFT", 2, -2)
    b.tag:SetText(hand.key == "mh" and "MH" or "OH")
    b:SetScript("OnEnter", function(self)
        local def = chosenSpell(hand)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(hand.label .. ": " .. (def and def.name or "?"))
        GameTooltip:AddLine("Click to apply. Change the imbue in /sham.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    buttons[hand.key] = b
    return b
end

function Imbues:Init()
    frame = CreateFrame("Frame", "ShammyForeverImbues", UIParent)
    frame:Hide()
    self.frame = frame
    for _, hand in ipairs(HANDS) do makeButton(hand) end
    NS.Movers:Register(frame, "imbues", "Imbues", { "CENTER", "CENTER", 180, -230 })

    local function update() self:Update() end
    NS:On("WEAPON_ENCHANT_CHANGED", update)
    NS:On("PLAYER_EQUIPMENT_CHANGED", update)
    NS:On("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" then update() end end)
    NS:On("PLAYER_REGEN_ENABLED", update)
    NS:On("PLAYER_REGEN_DISABLED", update)
    NS:On("SF_SPELLS", function() for _, b in pairs(buttons) do setSecure(b) end update() end)
    C_Timer.NewTicker(1, update)
end

function Imbues:Update()
    if not frame then return end
    local db = NS.db.imbues
    local enabled = NS:IsEnabled("imbues")
    local inCombat = InCombatLockdown()
    for _, hand in ipairs(HANDS) do
        local b = buttons[hand.key]
        local def = chosenSpell(hand)
        local wanted = enabled and def and def.known and hasWeapon(hand)
        local has, left, iconID = Imbues.Read(hand)
        local low = has and left and left < db.warnMinutes * 60
        local bad = wanted and (has == false or low)

        b.icon:SetTexture((def and def.icon) or iconID or "Interface\\Icons\\INV_Misc_QuestionMark")
        b.icon:SetDesaturated(not has)
        b.time:SetText(has and fmt(left) or (wanted and "|cffff5555none|r" or ""))
        local visible = wanted and (db.show == "always" or bad) or (NS.editing and enabled)
        b:SetAlpha(visible and 1 or 0)
        if bad then UI:Glow(b, UI.palette.danger[1], UI.palette.danger[2], UI.palette.danger[3]) else UI:Glow(b) end

        local alertKey = "imbue" .. hand.key
        if bad and (db.inCombat or not inCombat) then
            NS.Alerts:Set(alertKey, {
                title = has and string.format("%s on %s runs out", def.name, hand.label:lower()) or string.format("No %s on %s", def.name, hand.label:lower()),
                text = has and ("Only " .. fmt(left) .. " left - click the imbue button") or "Click the imbue button to apply it",
                icon = def.icon, priority = 6, sound = "RAID_WARNING",
            })
        else
            NS.Alerts:Clear(alertKey)
        end
    end
    -- the container stays shown while enabled: a hidden secure frame cannot be
    -- shown again in combat, so per-button alpha does the hiding
    NS.AfterCombat("imbueframe", function() frame:SetShown(enabled and true or false) end)
end

function Imbues:Apply()
    if not frame then return end
    local db = NS.db.imbues
    NS.AfterCombat("imbuelayout", function()
        local x = 0
        for _, hand in ipairs(HANDS) do
            local b = buttons[hand.key]
            b:SetSize(db.size, db.size)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
            x = x + db.size + 4
            setSecure(b)
        end
        frame:SetSize(x - 4, db.size)
    end)
    self:Update()
end
