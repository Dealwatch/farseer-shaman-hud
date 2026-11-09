--[[
    Farseer - procs
    One centred row above the Maelstrom bar that shows only what is up right
    now: Flurry, Clearcasting, Improved Stormstrike, Rage of the Farseer,
    Lightning Mastery, Nature's Swiftness. Each icon has its
    time-left swipe and stacks.

    The client fills the row itself (native aura group), so it works while
    the buffs are secret in combat. Without a native container the row stays
    empty.
]]

local _, NS = ...
local UI, Spells = NS.UI, NS.Spells

local Procs = NS:NewModule("procs", {
    title = "Procs",
    desc = "Active procs and burst buffs, only while they are up",
    icon = "Interface\\Icons\\Ability_GhoulFrenzy",
})

local PROCS = { "flurry", "clearcasting", "impStormstrike", "rageFarseer", "elementalMastery",
                "naturesSwiftness" }

local frame
local preview = {}

function Procs:Init()
    local size = NS.db.procs.size
    frame = CreateFrame("Frame", "FarseerHUDProcs", UIParent)
    frame:SetSize(4 * size + 12, size)
    frame:Hide()
    UI:NativeHost(frame)
    self.frame = frame

    -- edit-mode preview only
    for i = 1, 3 do
        local f = UI:Icon(frame, size)
        f:SetPoint("CENTER", frame, "CENTER", (i - 2) * (size + 4), 0)
        f.icon:SetTexture(({ "Interface\\Icons\\Ability_GhoulFrenzy", "Interface\\Icons\\Spell_Shadow_ManaBurn",
            "Interface\\Icons\\Spell_Nature_Bloodlust" })[i])
        f:Hide()
        preview[i] = f
    end

    NS.Movers:Register(frame, "procs", "Procs", { "CENTER", "CENTER", 0, -88 })

    self.native = NS.Native:Slot({
        key = "procs", parent = frame, unit = "player", filter = "HELPFUL", level = 3,
        group = { size = size, spacing = 4 },
        ids = function() return Spells:AuraIDs(unpack(PROCS)) end,
        init = function(b)
            b:SetSize(size, size)
            UI:Skin(b, UI.palette.track, UI.palette.border)
            local tex = b:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT", 1, -1)
            tex:SetPoint("BOTTOMRIGHT", -1, 1)
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b:SetIcon(tex)
            local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
            cd:SetAllPoints(tex)
            cd:SetDrawEdge(false)
            cd:SetReverse(true)
            cd:SetHideCountdownNumbers(true)
            b:SetDurationCooldown(cd)
            local count = UI:Text(b, 13, UI.palette.text, "OUTLINE")
            count:SetPoint("BOTTOMRIGHT", -2, 2)
            b:SetApplicationCount(count)
        end,
        onBuilt = function() Procs:Apply() end,
    })
    self.native:Build()
end

function Procs:Apply()
    if not frame then return end
    local on = NS:IsEnabled("procs")
    UI:SafeShow(frame, on)
    for _, f in ipairs(preview) do f:SetShown(on and NS.editing or false) end
end
