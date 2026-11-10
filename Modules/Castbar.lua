--[[
    Farseer - cast bar
    Your casts and channels in the HUD style. The fill comes from the
    client's duration object (UnitCastingDuration / UnitChannelDuration ->
    StatusBar:SetTimerDuration), so it runs even when cast values are
    secret; spell name and icon go straight into the widgets. Only the
    time text needs readable numbers. Blizzard's own cast bar can be
    switched off so nothing shows twice.
]]

local _, NS = ...
local UI = NS.UI

local Cast = NS:NewModule("castbar", {
    title = "Cast Bar",
    desc = "Your casts and channels in the HUD style",
    icon = "Interface\\Icons\\Spell_Nature_Lightning",
})

local HOLD_DONE, HOLD_FAIL = 0.3, 1.0   -- how long a finished / interrupted cast stays up

local frame, bar, icon
-- guid: castGUID from the start event (own cast events are never secret)
local state = { active = false, channel = false, guid = nil, startT = nil, endT = nil, holdUntil = 0 }
Cast.state = state

local function colour(c) bar:SetStatusBarColor(c[1], c[2], c[3]) end

local function blizzardBar() return _G.PlayerCastingBarFrame or _G.CastingBarFrame end

local function layout()
    local db = NS.db.castbar
    local h = db.height
    frame:SetSize(db.width, h)
    icon:SetSize(h, h)
    icon:SetShown(db.showIcon)
    bar:ClearAllPoints()
    bar:SetPoint("TOPRIGHT")
    bar:SetPoint("BOTTOMRIGHT")
    bar:SetWidth(db.showIcon and db.width - h - 3 or db.width)
    bar.spark:SetHeight(h)
    bar.time:SetShown(db.showTime)
end

-- channel: true for UnitChannelInfo / UnitChannelDuration
local function begin(channel, guid)
    local info = channel and UnitChannelInfo or UnitCastingInfo
    local name, _, tex, startMS, endMS = info("player")
    -- name may be secret: only a readable nil means "nothing is being cast"
    if not NS.IsSecret(name) and name == nil then return end
    state.active, state.channel, state.guid, state.holdUntil, state.failed = true, channel, guid, 0, false
    startMS, endMS = NS.Readable(startMS), NS.Readable(endMS)
    state.startT = startMS and startMS / 1000
    state.endT = endMS and endMS / 1000

    bar.name:SetText(name)
    icon.icon:SetTexture(tex)
    colour({ UI:Accent() })

    local durFn = channel and UnitChannelDuration or UnitCastingDuration
    local native = durFn and bar.SetTimerDuration and pcall(function()
        bar:SetTimerDuration(durFn("player"), Enum.StatusBarInterpolation.Immediate,
            channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
    end)
    state.native = native and true or false
    if not state.native then
        if not (state.startT and state.endT) then state.active = false; return end
        bar:SetMinMaxValues(state.startT, state.endT)
    end
    Cast:Update()
end

local function finish(failed, guid)
    if not state.active and state.holdUntil == 0 then return end
    -- "failed" also fires for a spell pressed while on cooldown: only the running cast counts
    if failed and not state.channel and guid ~= state.guid then return end
    if state.failed then return end   -- interrupted and failed can both fire: the first one stays
    state.active = false
    if failed then
        state.failed = true
        colour(UI.palette.danger)
        bar.name:SetText(failed)
        state.holdUntil = GetTime() + HOLD_FAIL
    elseif state.holdUntil == 0 then
        state.holdUntil = GetTime() + HOLD_DONE
    end
    if not state.native or failed then
        -- full bar for the moment it stays up
        if bar.SetToTargetValue then pcall(bar.SetToTargetValue, bar) end
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
    end
    bar.time:SetText("")
    Cast:Update()
end

function Cast:Init()
    frame = CreateFrame("Frame", "FarseerHUDCastBar", UIParent)
    frame:Hide()
    self.frame = frame
    local db = NS.db.castbar
    icon = UI:Icon(frame, db.height)
    icon:SetPoint("LEFT")
    bar = UI:Bar(frame, db.width, db.height)
    self.bar = bar
    bar.time = UI:Text(bar, 10, UI.palette.text, "OUTLINE")
    bar.time:SetPoint("RIGHT", -4, 0)
    bar.time:SetJustifyH("RIGHT")
    bar.name = UI:Text(bar, 10, UI.palette.text, "OUTLINE")
    bar.name:SetPoint("LEFT", 4, 0)
    bar.name:SetPoint("RIGHT", bar.time, "LEFT", -4, 0)
    -- keepParent: casts out of combat (heals, Ghost Wolf) show while the HUD is hidden
    NS.Movers:Register(frame, "castbar", "Cast Bar", { "CENTER", "CENTER", 0, -246 }, true)

    local function onStart(_, _, guid) begin(false, guid) end
    NS:OnUnit("UNIT_SPELLCAST_START", "player", onStart)
    NS:OnUnit("UNIT_SPELLCAST_DELAYED", "player", function() if state.active and not state.channel then begin(false, state.guid) end end)
    NS:OnUnit("UNIT_SPELLCAST_CHANNEL_START", "player", function(_, _, guid) begin(true, guid) end)
    NS:OnUnit("UNIT_SPELLCAST_CHANNEL_UPDATE", "player", function() if state.active and state.channel then begin(true, state.guid) end end)
    NS:OnUnit("UNIT_SPELLCAST_STOP", "player", function(_, _, guid) if not state.channel then finish(nil, guid) end end)
    NS:OnUnit("UNIT_SPELLCAST_CHANNEL_STOP", "player", function() if state.channel then finish(nil) end end)
    NS:OnUnit("UNIT_SPELLCAST_INTERRUPTED", "player", function(_, _, guid) finish("Interrupted", guid) end)
    NS:OnUnit("UNIT_SPELLCAST_FAILED", "player", function(_, _, guid) finish("Failed", guid) end)
    NS:On("PLAYER_ENTERING_WORLD", function()
        begin(false)
        if not state.active then begin(true) end
    end)

    frame:SetScript("OnUpdate", function() self:OnUpdate() end)
end

function Cast:OnUpdate()
    local now = GetTime()
    if state.active then
        if not state.native and state.startT then
            bar:SetValue(state.channel and (state.endT - now + state.startT) or now)
        end
        local left = state.endT and state.endT - now
        bar.time:SetText(left and left > 0 and string.format("%.1f", left) or "")
    elseif state.holdUntil > 0 and now >= state.holdUntil then
        state.holdUntil = 0
        state.guid = nil
        self:Update()
    end
end

function Cast:Update()
    if not frame then return end
    local on = NS:IsEnabled("castbar")
    local preview = NS.editing and not state.active and state.holdUntil == 0
    if preview then
        bar.name:SetText("Lightning Bolt")
        bar.time:SetText("1.2")
        icon.icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
        colour({ UI:Accent() })
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0.6)
    end
    frame:SetShown(on and (state.active or state.holdUntil > 0 or preview) or false)
end

local warned
function Cast:Apply()
    if not frame then return end
    layout()
    local b = blizzardBar()
    if b then
        if NS:IsEnabled("castbar") and NS.db.castbar.hideBlizzard then
            -- only C-side calls: Blizzard's own Lua state stays untouched (no taint)
            b:UnregisterAllEvents()
            b:Hide()
            self.blizzardHidden = true
        elseif self.blizzardHidden and not warned then
            warned = true
            NS.Print("type /reload to bring Blizzard's cast bar back.")
        end
    end
    self:Update()
end
