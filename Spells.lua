--[[
    ShammyForever - spells
    Forever's spell IDs are not published anywhere we can read, so nothing here
    depends on one exact ID. Every spell has a few candidate IDs (Classic Era,
    later expansions) and its English name. At login we read the player's
    spellbook and match by the localized name the client gives for those IDs,
    so any rank, any client language and any Forever-only ID resolves.
    `/sham spells` prints the real IDs if something does not resolve.
]]

local _, NS = ...

local Spells = {}
NS.Spells = Spells

-- key = { en = English name, ids = candidate IDs, [element = totem slot] }
-- Totem slots on the Classic layout: 1 Fire, 2 Earth, 3 Water, 4 Air.
local DEFS = {
    -- Rotation
    -- Forever-only IDs (408xxx, 425336, 437009) agree between the public
    -- ShamanForever addon and a second independent lookup; every rank is
    -- listed where an aura filter has to match IDs instead of names.
    stormstrike     = { en = "Stormstrike",          ids = { 17364 } },   -- its debuff has the same ID
    earthShock      = { en = "Earth Shock",          ids = { 8042, 8044, 8045, 8046, 10412, 10413, 10414 } },
    flameShock      = { en = "Flame Shock",          ids = { 8050, 8052, 8053, 10447, 10448, 29228 } },
    frostShock      = { en = "Frost Shock",          ids = { 8056, 8058, 10472, 10473 } },
    lightningBolt   = { en = "Lightning Bolt",       ids = { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208 } },
    chainLightning  = { en = "Chain Lightning",      ids = { 421, 930, 2860, 10605 } },
    fireNova        = { en = "Fire Nova",            ids = { 408341 } },  -- a spell on Forever, not a totem
    rageFarseer     = { en = "Rage of the Farseer",  ids = { 425336 } },
    elementalMastery = { en = "Lightning Mastery",   ids = { 16166 } },   -- Elemental Mastery, renamed on Forever
    purge           = { en = "Purge",                ids = { 370, 8012, 27626 } },
    -- Forever totem tools: Call of the Elements / Ancestors / Spirits (levels 20/30/40) drop
    -- several totems at once, Totemic Recall (20) takes them all back, Totemic Call (22) pulls
    -- them to you.
    totemicCall     = { en = "Totemic Call",         ids = { 437009 } },
    totemicRecall   = { en = "Totemic Recall",       ids = { 36936 } },
    callElements    = { en = "Call of the Elements", ids = { 66842 } },
    callAncestors   = { en = "Call of the Ancestors", ids = { 66843 } },
    callSpirits     = { en = "Call of the Spirits",  ids = { 66844 } },
    maelstrom       = { en = "Maelstrom Weapon",     ids = { 408498, 408505, 53817, 344179, 51530, 187880 },
                        aura = { 408505, 53817, 344179 } },               -- talent and buff IDs differ
    flurry          = { en = "Flurry",               ids = { 16256 }, aura = { 16257, 16277, 16278, 16279, 16280 } },
    clearcasting    = { en = "Clearcasting",         ids = { 16246 } },    -- Elemental Focus proc, buff has this ID
    impStormstrike  = { en = "Improved Stormstrike", ids = { 1223031 }, aura = { 1238931 } },
    naturesSwiftness = { en = "Nature's Swiftness",  ids = { 16188 } },    -- buff has the same ID

    -- Self buffs / forms
    lightningShield = { en = "Lightning Shield",     ids = { 324, 325, 905, 945, 8134, 10431, 10432 } },
    waterShield     = { en = "Water Shield",         ids = { 408510, 24398, 52127 }, aura = { 408510, 408511 } },
    ghostWolf       = { en = "Ghost Wolf",           ids = { 2645 } },
    reincarnation   = { en = "Reincarnation",        ids = { 20608 } },

    -- Weapon imbues
    windfury        = { en = "Windfury Weapon",      ids = { 8232 } },
    flametongue     = { en = "Flametongue Weapon",   ids = { 8024 } },
    rockbiter       = { en = "Rockbiter Weapon",     ids = { 8017 } },
    frostbrand      = { en = "Frostbrand Weapon",    ids = { 8033 } },

    -- Fire totems
    searingTotem    = { en = "Searing Totem",        ids = { 3599 },  element = 1 },
    magmaTotem      = { en = "Magma Totem",          ids = { 8190 },  element = 1 },
    flametongueTotem = { en = "Flametongue Totem",   ids = { 8227 },  element = 1 },
    frostResTotem   = { en = "Frost Resistance Totem", ids = { 8181 }, element = 1 },
    -- Earth totems
    strengthTotem   = { en = "Strength of Earth Totem", ids = { 8075 }, element = 2 },
    stoneskinTotem  = { en = "Stoneskin Totem",      ids = { 8071 },  element = 2 },
    earthbindTotem  = { en = "Earthbind Totem",      ids = { 2484 },  element = 2 },
    stoneclawTotem  = { en = "Stoneclaw Totem",      ids = { 5730 },  element = 2 },
    tremorTotem     = { en = "Tremor Totem",         ids = { 8143 },  element = 2 },
    -- Water totems
    healingStream   = { en = "Healing Stream Totem", ids = { 5394 },  element = 3 },
    manaSpring      = { en = "Mana Spring Totem",    ids = { 5675 },  element = 3 },
    poisonTotem     = { en = "Poison Cleansing Totem", ids = { 8166 }, element = 3 },
    diseaseTotem    = { en = "Disease Cleansing Totem", ids = { 8170 }, element = 3 },
    fireResTotem    = { en = "Fire Resistance Totem", ids = { 8184 }, element = 3 },
    manaTide        = { en = "Mana Tide Totem",      ids = { 16190 }, element = 3 },
    -- Air totems
    windfuryTotem   = { en = "Windfury Totem",       ids = { 8512 },  element = 4 },
    graceTotem      = { en = "Grace of Air Totem",   ids = { 8835 },  element = 4 },
    groundingTotem  = { en = "Grounding Totem",      ids = { 8177 },  element = 4 },
    natureResTotem  = { en = "Nature Resistance Totem", ids = { 10595 }, element = 4 },
    windwallTotem   = { en = "Windwall Totem",       ids = { 15107 }, element = 4 },
    sentryTotem     = { en = "Sentry Totem",         ids = { 6495 },  element = 4 },
}
Spells.DEFS = DEFS

Spells.ANKH_ITEM = 17030

-- Element slot metadata, in the order the totem bar draws them.
Spells.ELEMENTS = {
    { slot = 2, key = "earth", label = "Earth", color = { 0.65, 0.47, 0.27 }, icon = "Interface\\Icons\\Spell_Nature_EarthBindTotem" },
    { slot = 1, key = "fire",  label = "Fire",  color = { 0.98, 0.45, 0.16 }, icon = "Interface\\Icons\\Spell_Fire_SearingTotem" },
    { slot = 3, key = "water", label = "Water", color = { 0.25, 0.60, 1.00 }, icon = "Interface\\Icons\\INV_Spear_04" },
    { slot = 4, key = "air",   label = "Air",   color = { 0.80, 0.86, 0.92 }, icon = "Interface\\Icons\\Spell_Nature_InvisibilityTotem" },
}

-- Imbues the user can pick per hand.
Spells.IMBUES = { "windfury", "flametongue", "rockbiter", "frostbrand" }

local byName = {}       -- localized or English name -> key
local book = {}         -- spellbook: name -> spellID

local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and n and not NS.IsSecret(n) then return n end
    end
    if GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok and n then return n end
    end
end
Spells.NameOf = spellName

function Spells.TextureOf(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, id)
        if ok and t then return t end
    end
end

local function scanBook()
    wipe(book)
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return end
    local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info then
            local first = (info.itemIndexOffset or 0) + 1
            local last = (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)
            for i = first, last do
                local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
                if item and item.name and item.spellID then
                    book[item.name] = item.spellID
                end
            end
        end
    end
end

local function isKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and known then return true end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, id)
        if ok and known then return true end
    end
    return false
end

-- Fills each def with: name (localized when possible), id (the player's
-- castable ID, or the first candidate the client knows), known, icon.
function Spells:Resolve()
    wipe(byName)
    scanBook()
    for key, def in pairs(DEFS) do
        def.key = key
        def.known, def.id, def.name = false, nil, nil
        local names = {}
        for _, id in ipairs(def.ids) do
            local n = spellName(id)
            if n then names[#names + 1] = n end
            if not def.known and isKnown(id) then def.known, def.id = true, id end
        end
        names[#names + 1] = def.en
        for _, n in ipairs(names) do
            byName[n] = key
            if not def.known and book[n] then
                def.known, def.id, def.name = true, book[n], n
            end
        end
        -- learned by the probe (a readable aura told us the real ID)
        if key == "maelstrom" and NS.db and NS.db.learned.maelstromBuffID then
            local n = spellName(NS.db.learned.maelstromBuffID)
            if n then byName[n] = key; names[#names + 1] = n end
        end
        def.name = def.name or (def.id and spellName(def.id)) or names[1]
        def.id = def.id or def.ids[1]
        def.icon = Spells.TextureOf(def.id)
    end
end

function Spells:Get(key) return DEFS[key] end

-- Every ID an aura of this spell may carry (all ranks, buff IDs, the
-- resolved one), as an array for the native aura filters.
function Spells:AuraIDs(...)
    local out, seen = {}, {}
    local function add(id) if id and not seen[id] then seen[id] = true; out[#out + 1] = id end end
    for i = 1, select("#", ...) do
        local def = DEFS[select(i, ...)]
        if def then
            for _, id in ipairs(def.aura or def.ids) do add(id) end
            if not def.aura then add(def.id) end
        end
    end
    if NS.db and NS.db.learned.maelstromBuffID and select(1, ...) == "maelstrom" then add(NS.db.learned.maelstromBuffID) end
    return out
end
function Spells:Known(key) return DEFS[key] and DEFS[key].known or false end

-- Key for a spell ID or name we saw (own casts, readable auras), or nil.
function Spells:KeyFor(spellIDorName)
    if spellIDorName == nil or NS.IsSecret(spellIDorName) then return nil end
    local name = spellIDorName
    if type(spellIDorName) == "number" then name = spellName(spellIDorName) end
    return name and byName[name]
end

function Spells:BookSnapshot()
    scanBook()
    return book
end
