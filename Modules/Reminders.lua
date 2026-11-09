--[[
    ShammyForever - reminders
      * Lightning Shield (or Water Shield) missing.
      * Ghost Wolf still on in combat.
      * Low on Ankhs for Reincarnation.
    Buffs are secret in combat, so the shield state is the last readable
    answer, updated by your own casts; it is re-read the moment combat ends.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local R = NS:NewModule("reminders", {
    title = "Reminders",
    desc = "Lightning Shield, Ghost Wolf in combat, Ankhs",
    icon = "Interface\\Icons\\Spell_Nature_LightningShield",
})

local shieldUp = nil      -- true / false / nil (unknown)

local function readShield()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return nil end
    local sawSecret = false
    for _, key in ipairs({ "lightningShield", "waterShield" }) do
        local def = Spells:Get(key)
        if def and def.known then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", def.name, "HELPFUL")
            if not ok then return nil end
            if aura then return true end
        end
    end
    -- "nothing" is only trustworthy when auras are not restricted right now
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, restricted = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and restricted then sawSecret = true end
    elseif InCombatLockdown() then
        sawSecret = true
    end
    if sawSecret then return nil end
    return false
end

local function ghostWolfOn()
    local form = NS.Readable(GetShapeshiftForm and GetShapeshiftForm())
    return form and form > 0 or false
end

function R:Update()
    local db = NS.db.reminders
    local on = NS:IsEnabled("reminders")
    local inCombat = InCombatLockdown()
    local A = NS.Alerts

    -- shield
    local read = readShield()
    if read ~= nil then shieldUp = read end
    local hasShield = Spells:Known("lightningShield") or Spells:Known("waterShield")
    if on and db.shield and hasShield and shieldUp == false and (db.shieldInCombat or not inCombat)
        and not UnitIsDeadOrGhost("player") and not IsMounted() then
        local def = Spells:Get("lightningShield")
        A:Set("shield", { title = "No " .. (def.name or "Lightning Shield"), text = "Refresh your shield", icon = def.icon, priority = 4 })
    else
        A:Clear("shield")
    end

    -- Ghost Wolf in combat
    if on and db.ghostWolf and inCombat and ghostWolfOn() then
        local def = Spells:Get("ghostWolf")
        A:Set("ghostwolf", { title = (def.name or "Ghost Wolf") .. " in combat", text = "You can't attack in wolf form", icon = def.icon, color = UI.palette.danger, priority = 8, sound = "RAID_WARNING" })
    else
        A:Clear("ghostwolf")
    end

    -- Ankhs
    local ankhs = C_Item and C_Item.GetItemCount and NS.Try(C_Item.GetItemCount, Spells.ANKH_ITEM) or 0
    R.ankhs = ankhs
    if on and db.ankh and Spells:Known("reincarnation") and not inCombat and ankhs < db.ankhMin then
        A:Set("ankh", { title = "Low on Ankhs (" .. ankhs .. ")", text = "Reincarnation needs an Ankh", icon = "Interface\\Icons\\INV_Jewelry_Talisman_06", priority = 2 })
    else
        A:Clear("ankh")
    end
end

function R:Init()
    local function update() self:Update() end
    NS:OnUnit("UNIT_AURA", "player", update)
    NS:On("UPDATE_SHAPESHIFT_FORM", update)
    NS:On("PLAYER_REGEN_DISABLED", update)
    NS:On("PLAYER_REGEN_ENABLED", update)
    NS:On("BAG_UPDATE_DELAYED", update)
    NS:On("PLAYER_ENTERING_WORLD", update)
    NS:On("PLAYER_MOUNT_DISPLAY_CHANGED", update)
    NS:On("PLAYER_DEAD", update)
    NS:On("PLAYER_ALIVE", update)
    NS:On("PLAYER_UNGHOST", update)
    NS:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, _, spellID)
        local key = Spells:KeyFor(spellID)
        if key == "lightningShield" or key == "waterShield" then shieldUp = true; update() end
    end)
end

function R:Apply() self:Update() end

function R.ShieldState() return shieldUp end
