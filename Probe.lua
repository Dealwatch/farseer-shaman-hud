--[[
    ShammyForever - diagnostics
    /sham probe   what the client lets addons read right now (run it once out
                  of combat and once in combat while hitting something)
    /sham spells  every spell in your spellbook with its ID
    Both open a copy box and are also saved in the SavedVariables file
    (WTF\Account\<account>\SavedVariables\ShammyForever.lua).
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local box

local function copyBox(title, text)
    if not box then
        box = CreateFrame("Frame", "ShammyForeverCopy", UIParent)
        box:SetSize(640, 460)
        box:SetPoint("CENTER")
        box:SetFrameStrata("DIALOG")
        box:EnableMouse(true)
        box:SetMovable(true)
        box:RegisterForDrag("LeftButton")
        box:SetScript("OnDragStart", box.StartMoving)
        box:SetScript("OnDragStop", box.StopMovingOrSizing)
        UI:Skin(box, UI.palette.surface, UI.palette.border, "lg")
        UI:Shadow(box)
        box.title = UI:Text(box, 15)
        box.title:SetPoint("TOPLEFT", 16, -14)
        box.hint = UI:Text(box, 11, UI.palette.textDim)
        box.hint:SetPoint("TOPLEFT", box.title, "BOTTOMLEFT", 0, -4)
        box.hint:SetText("Ctrl+A, Ctrl+C to copy. Also saved in SavedVariables\\ShammyForever.lua")
        local close = CreateFrame("Button", nil, box)
        close:SetSize(24, 24)
        close:SetPoint("TOPRIGHT", -10, -10)
        close.t = UI:Text(close, 16, UI.palette.textDim)
        close.t:SetPoint("CENTER")
        close.t:SetText("x")
        close:SetScript("OnClick", function() box:Hide() end)
        local sf = CreateFrame("ScrollFrame", nil, box)
        sf:SetPoint("TOPLEFT", 16, -56)
        sf:SetPoint("BOTTOMRIGHT", -16, 16)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetWidth(600)
        eb:SetFontObject(ChatFontNormal)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); box:Hide() end)
        sf:SetScrollChild(eb)
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, d)
            local max = math.max(0, eb:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 40)))
        end)
        box.eb = eb
        tinsert(UISpecialFrames, "ShammyForeverCopy")
    end
    box.title:SetText(title)
    box.eb:SetText(text)
    box:Show()
    box.eb:SetFocus()
    box.eb:HighlightText()
end

local function v(x)
    if NS.IsSecret(x) then return "<secret>" end
    if x == nil then return "nil" end
    return tostring(x)
end

local function try(fn, ...)
    if not fn then return "<missing>" end
    local res = { pcall(fn, ...) }
    if not res[1] then return "<error: " .. tostring(res[2]) .. ">" end
    local out = {}
    for i = 2, math.max(#res, 2) do out[#out + 1] = v(res[i]) end
    return table.concat(out, ", ")
end

local function probe()
    local L = {}
    local function add(...) L[#L + 1] = table.concat({ ... }, " ") end
    local build, _, _, iface = GetBuildInfo()
    local inCombat = InCombatLockdown()
    add("Shammy Forever", NS.VERSION, "| build", v(build), "| interface", v(iface), "| locale", GetLocale())
    add("level", v(UnitLevel("player")), "| in combat:", tostring(inCombat), "| time", date("%Y-%m-%d %H:%M:%S"))
    add("issecretvalue:", tostring(_G.issecretvalue ~= nil))
    if C_Secrets then
        add("ShouldAurasBeSecret:", try(C_Secrets.ShouldAurasBeSecret), "| ShouldCooldownsBeSecret:", try(C_Secrets.ShouldCooldownsBeSecret))
    end

    add("")
    add("== Swing")
    add("C_SwingTimer:", tostring(C_SwingTimer ~= nil), "| PlayerSwingType enum:", tostring(Enum.PlayerSwingType ~= nil))
    local sw = NS.modules.swing and NS.modules.swing.state
    if sw then
        local mh, oh = sw[0] or {}, sw[1] or {}
        add("last MH swing dur", v(mh.dur), "| last OH swing dur", v(oh.dur), "| out of range", tostring(sw.outOfRange))
    end
    add("IsTargetWithinSwingRange(MH):", C_SwingTimer and try(C_SwingTimer.IsTargetWithinSwingRange, 0) or "-")

    add("")
    add("== Totems (have, name, start, duration, icon)")
    for slot = 1, 4 do
        add("slot", slot, ":", try(GetTotemInfo, slot), "| GetTotemDuration:", GetTotemDuration and type(select(2, pcall(GetTotemDuration, slot))) or "<missing>")
    end

    add("")
    add("== Weapon enchants")
    for i, label in ipairs({ "MH", "OH" }) do
        if C_Item and C_Item.GetWeaponEnchantInfo then
            local ok, res = pcall(C_Item.GetWeaponEnchantInfo, i - 1)
            if ok and type(res) == "table" then
                local list = res.hasEnchant ~= nil and { res } or res
                add(label, "entries:", #list)
                for _, e in ipairs(list) do
                    add("  has", v(e.hasEnchant), "type", v(e.enchantType), "timeLeft", v(e.timeLeft), "charges", v(e.charges), "id", v(e.enchantID))
                end
            else
                add(label, "C_Item.GetWeaponEnchantInfo:", ok and type(res) or ("error " .. tostring(res)))
            end
        end
    end
    add("GetWeaponEnchantInfo():", try(GetWeaponEnchantInfo))
    local imb = NS.modules.imbues
    if imb and imb.Read then
        add("addon reads: MH", try(imb.Read, { key = "mh", inv = 16, slot = 0 }), "| OH", try(imb.Read, { key = "oh", inv = 17, slot = 1 }))
    end

    add("")
    add("== Player buffs")
    local total, secret = 0, 0
    for i = 1, 40 do
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok then add("aura scan error:", tostring(a)) break end
        if not a then break end
        total = total + 1
        if NS.IsSecret(a.spellId) then
            secret = secret + 1
        else
            add("  ", v(a.name), "id", v(a.spellId), "stacks", v(a.applications), "dur", v(a.duration))
        end
    end
    add("buffs:", total, "| secret:", secret)
    local mw = NS.modules.maelstrom and NS.modules.maelstrom.state
    local mdef = Spells:Get("maelstrom")
    add("Maelstrom: source", v(mw and mw.source), "| stacks", v(mw and mw.stacks), "| readable in combat", v(mw and mw.readableInCombat),
        "| learned buff id", v(NS.db.learned.maelstromBuffID), "| name", v(mdef.name), "| known", tostring(mdef.known))
    local lb = Spells:Get("lightningBolt")
    if C_SpellActivationOverlay then
        add("Lightning Bolt overlayed:", try(C_SpellActivationOverlay.IsSpellOverlayed, lb.id))
    end
    add("Lightning Bolt display count:", C_Spell.GetSpellDisplayCount and try(C_Spell.GetSpellDisplayCount, lb.id) or "-",
        "| cast count:", C_Spell.GetSpellCastCount and try(C_Spell.GetSpellCastCount, lb.id) or "-")

    add("")
    add("== Cooldowns")
    for _, key in ipairs({ "stormstrike", "earthShock", "rageFarseer", "shamanisticRage" }) do
        local d = Spells:Get(key)
        if d.known then
            local ok, info = pcall(C_Spell.GetSpellCooldown, d.id)
            local cd = ok and info and (v(info.startTime) .. " / " .. v(info.duration)) or "-"
            add(d.name, "id", d.id, "| cooldown", cd, "| duration object:", type(select(2, pcall(C_Spell.GetSpellCooldownDuration or error, d.id))),
                "| usable:", try(C_Spell.IsSpellUsable, d.id))
        end
    end
    add("GCD 61304:", try(function() local i = C_Spell.GetSpellCooldown(61304); return i and i.duration end),
        "| GCD 29515:", try(function() local i = C_Spell.GetSpellCooldown(29515); return i and i.duration end))

    add("")
    add("== Other")
    add("shapeshift form:", try(GetShapeshiftForm), "| Ankhs:", try(C_Item.GetItemCount, Spells.ANKH_ITEM))
    local fsDef = Spells:Get("flameShock")
    add("target Flame Shock aura:", try(function()
        local a = C_UnitAuras.GetAuraDataBySpellName("target", fsDef.name, "HARMFUL|PLAYER")
        return a and (v(a.duration) .. "s") or "none"
    end), "| target name:", try(UnitName, "target"))

    add("")
    add("== Resolved spells (key: name / id / known)")
    local keys = {}
    for k in pairs(Spells.DEFS) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local d = Spells.DEFS[k]
        if d.known or not d.element then add("  " .. k .. ":", v(d.name), "/", v(d.id), "/", tostring(d.known)) end
    end

    local text = table.concat(L, "\n")
    NS.db.probe = NS.db.probe or {}
    NS.db.probe[inCombat and "combat" or "outOfCombat"] = text
    return text, inCombat
end

local function spells()
    local L = {}
    local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    for line = 1, (C_SpellBook.GetNumSpellBookSkillLines() or 0) do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info then
            L[#L + 1] = "== " .. tostring(info.name)
            for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local it = C_SpellBook.GetSpellBookItemInfo(i, bank)
                if it then
                    L[#L + 1] = string.format("%s | %s | id %s%s", tostring(it.name), tostring(it.subName or ""), tostring(it.spellID or it.actionID), it.isPassive and " | passive" or "")
                end
            end
        end
    end
    local text = table.concat(L, "\n")
    NS.db.probe = NS.db.probe or {}
    NS.db.probe.spells = text
    return text
end

NS.commands.probe = function()
    local text, inCombat = probe()
    copyBox("Client probe (" .. (inCombat and "in combat" or "out of combat") .. ")", text)
end

NS.commands.spells = function()
    copyBox("Spellbook", spells())
end
