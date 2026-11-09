--[[
    ShammyForever - native aura slots
    Forever ships Blizzard_AuraContainer: an aura frame addons may create and
    style themselves, while the client fills it from its protected side. It
    shows stacks, durations and icons of auras even while they are secret to
    our Lua, which is exactly what Maelstrom stacks, shield charges and the
    Flame Shock on your target need in combat.

    Rules from the client code (Blizzard_CustomAuraContainer.lua):
      * filtering by spell ID works for helpful auras on yourself and harmful
        auras on enemies; that is all we use it for
      * build the slot while auras are readable (out of combat)
      * we never read anything back from these frames, we only style them
]]

local _, NS = ...

local Native = { slots = {} }
NS.Native = Native

local function aurasSecretNow()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, res = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and not NS.IsSecret(res) then return res and true or false end
    end
    return InCombatLockdown()
end

local function idMap(list)
    local map, n = {}, 0
    for _, id in ipairs(list or {}) do
        if not map[id] then map[id] = true; n = n + 1 end
    end
    return map, n
end

-- spec = { key, parent, unit, filter, ids = function() -> array, init = function(button), level }
-- Returns a handle: :Build() :Refilter() :Refresh() :Active() .status .err
function Native:Slot(spec)
    local h = { spec = spec, status = "not built" }

    function h:Build()
        if self.container or self.failed then return end
        if aurasSecretNow() then
            self.status = "waiting for auras to be readable"
            NS.AfterCombat("native" .. spec.key, function() self:Build() end)
            return
        end
        local map, n = idMap(spec.ids())
        if n == 0 then self.status = "no spell IDs"; return end
        local ok, err = pcall(function()
            local c = CreateFrame("AuraContainer", nil, spec.parent, "CustomAuraContainerTemplate")
            self.container = c
            c:SetPoint("TOPLEFT", spec.parent, "TOPLEFT", 0, 0)
            c:SetFrameLevel(spec.parent:GetFrameLevel() + (spec.level or 2))
            c:SetUnit(spec.unit)
            pcall(c.EnableMouse, c, false)
            local b = c:AddAuraSlot(spec.key, spec.filter, {
                candidateFilters = { includeSpellIDs = map },
                initializeFrame = function(button)
                    self.button = button
                    button:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
                    pcall(button.EnableMouse, button, false)
                    spec.init(button)
                end,
            })
            self.button = self.button or b
        end)
        if ok and self.button then
            self.status = "native"
            self.filtered = map
        else
            self.failed = true
            self.err = tostring(err or "no slot frame")
            self.status = "unavailable"
            if self.container then pcall(self.container.Hide, self.container) end
            self.container = nil
        end
        if spec.onBuilt then spec.onBuilt(self) end
    end

    -- new spell IDs after a spellbook change (new rank learned)
    function h:Refilter()
        if not self.container then return self:Build() end
        if aurasSecretNow() then
            NS.AfterCombat("nativefilter" .. spec.key, function() self:Refilter() end)
            return
        end
        local map = idMap(spec.ids())
        pcall(self.container.SetAuraSlotCandidateFilters, self.container, spec.key, { includeSpellIDs = map })
    end

    function h:Refresh()
        if self.container then pcall(self.container.UpdateAllAuras, self.container) end
    end

    function h:Active() return self.container ~= nil end

    -- size / style changes on the slot button, deferred while auras are secret
    function h:Restyle(fn)
        if not self.button then return end
        if aurasSecretNow() then
            NS.AfterCombat("nativestyle" .. spec.key, function() self:Restyle(fn) end)
            return
        end
        local ok, err = pcall(fn, self.button)
        if not ok then geterrorhandler()(err) end
    end

    self.slots[spec.key] = h
    return h
end

NS:On("SF_SPELLS", function()
    for _, h in pairs(Native.slots) do h:Refilter() end
end)
