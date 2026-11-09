--[[
    Farseer - totem bar
    One button per element (Earth, Fire, Water, Air) with the time left.
    Left-click recasts the last totem of that element, right-click destroys it
    (both are secure actions, so they work in combat).

    In combat GetTotemInfo is secret on Forever. The time left still works:
    GetTotemDuration hands back a duration object the cooldown swirl takes
    directly. Which totem is down we know from your own casts.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local Totems = NS:NewModule("totems", {
    title = "Totem Bar",
    desc = "Timers per element, click to recast, right-click to destroy",
    icon = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
})

local frame
local buttons = {}          -- slot -> button
local slotState = {}        -- slot -> { active, name, icon, destroyed }

-- Readable values, plus the raw icon: a secret icon can still go straight
-- into Texture:SetTexture (needed for totems dropped by a Call spell in combat).
local function totemInfo(slot)
    if not GetTotemInfo then return end
    local ok, have, name, start, dur, icon = pcall(GetTotemInfo, slot)
    if not ok then return end
    return NS.Readable(have), NS.Readable(name), NS.Readable(start), NS.Readable(dur), NS.Readable(icon), icon
end

local CALLS = { callElements = true, callAncestors = true, callSpirits = true }

local function setSecureSpell(btn)
    local db = NS.db.totems
    local key = db.last and db.last[btn.slot]
    local def = key and Spells:Get(key)
    local name = (def and def.name) or (NS.db.learned.lastTotemName and NS.db.learned.lastTotemName[btn.slot])
    NS.AfterCombat("totemspell" .. btn.slot, function()
        btn:SetAttribute("type1", name and "spell" or nil)
        btn:SetAttribute("spell1", name)
    end)
end

local function makeButton(el)
    local db = NS.db.totems
    local b = UI:Icon(frame, db.size, "SecureActionButtonTemplate", "FarseerHUDTotem" .. el.label)
    b.slot = el.slot
    b.el = el
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type2", "destroytotem")
    b:SetAttribute("totem-slot", el.slot)
    b:SetScript("PreClick", function(self, button)
        if button == "RightButton" then slotState[self.slot].destroyed = true end
    end)

    b.cd = UI:Cooldown(b)
    b.strip = b:CreateTexture(nil, "OVERLAY")
    b.strip:SetTexture(UI.WHITE)
    b.strip:SetPoint("BOTTOMLEFT", 1, 1)
    b.strip:SetPoint("BOTTOMRIGHT", -1, 1)
    b.strip:SetHeight(2)
    b.strip:SetVertexColor(el.color[1], el.color[2], el.color[3], 1)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if not (GameTooltip.SetTotem and pcall(GameTooltip.SetTotem, GameTooltip, self.slot)) then
            GameTooltip:SetText(el.label .. " totem")
        end
        GameTooltip:AddLine("Left-click: recast  |  Right-click: destroy", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    slotState[el.slot] = { active = false }
    buttons[el.slot] = b
    return b
end

function Totems:Init()
    NS.db.totems.last = NS.db.totems.last or {}
    NS.db.learned.totemSlots = NS.db.learned.totemSlots or {}
    frame = CreateFrame("Frame", "FarseerHUDTotems", UIParent)
    frame:Hide()
    self.frame = frame
    for _, el in ipairs(Spells.ELEMENTS) do makeButton(el) end
    NS.Movers:Register(frame, "totems", "Totems", { "CENTER", "CENTER", -148, -210 })

    NS:On("PLAYER_TOTEM_UPDATE", function(_, slot) self:UpdateSlot(slot) end)
    NS:On("PLAYER_ENTERING_WORLD", function() self:UpdateAll() end)
    NS:On("PLAYER_REGEN_ENABLED", function()
        self:UpdateAll()
        self:RecallReminder()
    end)
    NS:On("PLAYER_REGEN_DISABLED", function() self:Refresh(true) end)
    NS:On("SF_SPELLS", function() self:Apply() end)   -- new totem learned: re-layout (after combat)
    NS:OnUnit("UNIT_SPELLCAST_SUCCEEDED", "player", function(_, _, _, spellID)
        self:OnCast(spellID)
    end)
end

-- Own cast: remember which totem went into which slot.
function Totems:OnCast(spellID)
    spellID = NS.Readable(spellID)
    if not spellID then return end
    local name = Spells.NameOf(spellID)
    local key = Spells:KeyFor(spellID)
    if key == "totemicRecall" then
        NS.Alerts:Clear("recall")
        -- you took them back on purpose: no "totem is gone" alerts
        for s, st in pairs(slotState) do st.destroyed = true; NS.Alerts:Clear("totem" .. s) end
        return
    end
    if key and CALLS[key] then
        -- several totems at once: each slot reports itself via PLAYER_TOTEM_UPDATE
        for s, st in pairs(slotState) do st.calledAt = GetTime(); st.destroyed = false end
        return
    end
    local def = key and Spells:Get(key)
    local slot = (def and def.element) or (name and NS.db.learned.totemSlots[name])
    if not slot then return end
    local st = slotState[slot]
    st.active, st.name, st.icon, st.destroyed = true, name, Spells.TextureOf(spellID), false
    st.rawIcon, st.hasRaw = nil, false
    if key then
        NS.db.totems.last[slot] = key
    else
        NS.db.learned.lastTotemName = NS.db.learned.lastTotemName or {}
        NS.db.learned.lastTotemName[slot] = name
        NS.db.totems.last[slot] = nil
    end
    setSecureSpell(buttons[slot])
    NS.Alerts:Clear("totem" .. slot)
    self:Draw(slot)
end

function Totems:UpdateSlot(slot)
    local b, st = buttons[slot], slotState[slot]
    if not b then return end
    local have, name, start, dur, icon, rawIcon = totemInfo(slot)
    if have == nil and st.calledAt and GetTime() - st.calledAt < 2 then
        -- secret, right after a Call spell: show what the client put there
        -- kept apart and only ever handed to SetTexture: a secret must not be tested
        st.active, st.rawIcon, st.hasRaw = true, rawIcon, true
    end
    if have ~= nil then
        st.rawIcon, st.hasRaw = nil, false
        local wasActive = st.active
        st.active = have
        if have then
            st.name, st.icon = name or st.name, icon or st.icon
            if name and not Spells:KeyFor(name) then NS.db.learned.totemSlots[name] = slot end
            NS.Alerts:Clear("totem" .. slot)
        elseif wasActive and not st.destroyed and NS.db.totems.expireAlert and NS:IsEnabled("totems") then
            NS.Alerts:Set("totem" .. slot, {
                title = (st.name or b.el.label .. " totem") .. " is gone",
                text = b.el.label .. " slot is empty - click the totem bar to recast",
                icon = st.icon or b.el.icon, color = b.el.color, priority = 3, sound = "ALARM_CLOCK_WARNING_3",
            })
            C_Timer.After(6, function() NS.Alerts:Clear("totem" .. slot) end)
        end
        if not have then st.destroyed = false end
    end
    self:Draw(slot, start, dur)
end

-- Forever tip: Totemic Recall after every fight gives 25% of the totems' mana back.
-- A short reminder right after combat while totems are still down.
function Totems:RecallReminder()
    local any = false
    for _, st in pairs(slotState) do if st.active then any = true end end
    if not (any and NS.db.totems.recallReminder and NS:IsEnabled("totems") and Spells:Known("totemicRecall")) then return end
    local def = Spells:Get("totemicRecall")
    NS.Alerts:Set("recall", { title = def.name or "Totemic Recall", text = "Recall your totems: 25% of their mana back",
        icon = def.icon, color = { 0.25, 0.60, 1.00 }, priority = 1 })
    C_Timer.After(10, function() NS.Alerts:Clear("recall") end)
end

function Totems:UpdateAll()
    for slot in pairs(buttons) do self:UpdateSlot(slot) end
    self:Refresh()
end

-- Time left: duration object when the client offers one (works with secrets),
-- plain start/duration otherwise.
function Totems:Draw(slot, start, dur)
    local b, st = buttons[slot], slotState[slot]
    local db = NS.db.totems
    local preview = NS.editing and not st.active
    if st.hasRaw then b.icon:SetTexture(st.rawIcon) else b.icon:SetTexture(st.icon or b.el.icon) end
    b.icon:SetDesaturated(not st.active and not preview)
    b:SetAlpha((st.active or preview) and 1 or (db.showEmpty and 0.4 or 0))

    local durObj = GetTotemDuration and NS.Try(GetTotemDuration, slot)
    local shown = durObj and pcall(b.cd.SetCooldownFromDurationObject, b.cd, durObj, true)
    if not shown then
        if st.active and start and dur and dur > 0 then b.cd:SetCooldown(start, dur) else b.cd:Clear() end
    end
    b.cd:SetHideCountdownNumbers(not db.showTimers)
end

function Totems:Refresh(forceShow)
    if not frame then return end
    local db = NS.db.totems
    local any = false
    for _, st in pairs(slotState) do if st.active then any = true end end
    local show = NS:IsEnabled("totems") and (NS.editing or forceShow or not db.hideIdle or any or InCombatLockdown())
    NS.AfterCombat("totemframe", function() frame:SetShown(show and true or false) end)
end

-- Only elements you have a totem for get a button (no empty Water/Air at low level).
local function elementKnown(slot)
    for _, def in pairs(Spells.DEFS) do
        if def.element == slot and def.known then return true end
    end
    return slotState[slot] and slotState[slot].active or false
end

function Totems:Apply()
    if not frame then return end
    local db = NS.db.totems
    NS.AfterCombat("totemlayout", function()
        local x = 0
        for _, el in ipairs(Spells.ELEMENTS) do
            local b = buttons[el.slot]
            local shown = elementKnown(el.slot) or NS.editing
            b:SetShown(shown)
            if shown then
                b:SetSize(db.size, db.size)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
                x = x + db.size + db.spacing
            end
            setSecureSpell(b)
        end
        frame:SetSize(math.max(x - db.spacing, 1), db.size)
    end)
    for slot in pairs(buttons) do self:Draw(slot) end
    self:Refresh()
end
