# Farseer – Shaman HUD

Enhancement Shaman HUD / UI for **WoW Forever** (interface 16001, build 1.60.1).

One clean HUD for everything an Enhancement Shaman watches: swing timer, cast bar, mana, Maelstrom Weapon, Flame Shock,
cooldowns, totems, weapon imbues, Lightning Shield and reminders. Every element can be moved, resized or
switched off. The addon is in English.

> Status: **0.6.0, tested in game up to level 15.** Features from later levels (Stormstrike, Maelstrom Weapon,
> Rage of the Farseer, ...) are built against Blizzard's Forever UI code and an offline test client, not yet confirmed in game.

## Install

**WowUp:** *My Addons* > *Install from URL* > paste the GitHub address of this repository. Updates then show up
in WowUp by themselves (every tagged release).

**Manual:**

1. Download `FarseerShamanHUD-<version>.zip` (release or the zip you were sent).
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns\` so you get
   `...\AddOns\FarseerShamanHUD\FarseerShamanHUD.toc` (not `FarseerShamanHUD\FarseerShamanHUD\...`).
3. Restart the game completely (a `/reload` is not enough for a new addon).
4. Character select > **AddOns**: make sure *Farseer - Shaman HUD* is ticked. If it shows as out of date,
   tick *Load out of date AddOns*.

## Quick start

1. `/sham` opens the settings window. The overview shows your imbues, shield and Maelstrom detection,
   plus one switch per module.
2. `/sham edit` (or **Edit layout**) shows every frame with a label: drag them where you want them, click **Done**.
3. Fight something. The HUD shows in combat and while an enemy is targeted. Out of combat it is hidden;
   only alerts and imbue buttons that need you (missing or running out) stay on screen.

## Commands

| Command | |
|---|---|
| `/farseer` (or `/sham`) | Settings window |
| `/sham edit` | Edit mode: drag frames (snaps to the grid, Shift = free), arrow keys nudge (Shift = 10px), right-click resets a frame |
| `/sham test` | Preview the alerts for 8 seconds |
| `/sham probe` | What Forever lets the addon read right now. Run it once out of combat and once **in combat** |
| `/sham spells` | Copyable list of your spellbook with spell IDs |
| `/sham reset confirm` | Reset all settings and positions |

The addon also has an entry in the minimap's addon compartment.

## Default layout

One 240px column under your character and one row of 30px icons below it:

```
        [Fl][CC][RF]                  Procs: only what is up right now (centred)
                 Instant Bolt!        <- only at five stacks
[====|====|====|    |    ]            Maelstrom Weapon (5 segments)
[=========|           1.1]            Swing timer, main hand
[====                    ]            Off hand (thin line, dual wield only)
[==============          ]            Mana
[F][=============     8.3]            Flame Shock on your target

[E][F][W][A]   [SS][ES][FN][RF]   [MH][OH][LS]
   Totems          Cooldowns      Imbues + Shield
[i][Lightning Bolt          1.2]            Cast bar (only while casting)
```

Alerts stack at the top of the screen. All positions are saved per account.

## Modules

| Module | What it shows | Settings |
|---|---|---|
| **Swing Timer** | Main hand bar with time to the next swing, thin off hand line. Casts are projected onto the bar and turn red when they delay your swing. Grey when the target is out of melee range. | width, height, off hand, cast projection, range tint, text, hide when not fighting |
| **Cast Bar** | Your casts and channels with icon, spell name and time left; red "Interrupted" when a cast is cut off. Runs in combat too, also when the client hides the cast times from addons (then without the time text). Shows out of combat as well (heals, Ghost Wolf). | width, height, icon, time left, hide Blizzard's cast bar |
| **Mana Bar** | Thin mana bar, red when low, hidden at full mana out of combat. | width, height, red below %, percentage text, hide at full |
| **Totem Bar** | Earth, Fire, Water, Air with time left (only elements you have a totem for). Left-click recasts the last totem of that element, right-click destroys it. Totems from Call of the Elements/Ancestors/Spirits show up too. Alerts when a totem dies, and a Totemic Recall reminder after combat. | icon size, spacing, time left, empty slots, hide when no totem, expiry alert, recall reminder |
| **Weapon Imbues** | Shown when an imbue is missing or about to run out (or always, if you prefer), with time left. Click a button to apply your chosen imbue. Stays visible out of combat when needed. Not with a fishing pole. | imbue per hand, warn below minutes, when needed / always, warn in combat, icon size |
| **Procs** | One centred row that shows only active procs and burst buffs: Flurry, Clearcasting, Improved Stormstrike, Rage of the Farseer, Lightning Mastery, Nature's Swiftness, with time-left swipe and stacks. | icon size |
| **Maelstrom Weapon** | Five-segment bar that turns gold at five stacks, with glow, sound and "Instant Bolt!". | width, height, glow, sound, hide at zero |
| **Stormstrike & Shocks** | Cooldown icons (Stormstrike, Earth Shock, Fire Nova, Rage of the Farseer and other cooldowns you know, the global cooldown ignored). Right after Stormstrike the Earth Shock icon glows gold. Flame Shock bar with the real time left on your target. | shock prompt, optional big "Shock now!" card, prompt duration, Flame Shock bar and width, cooldown row and icon size |
| **Reminders** | Shield icon with Lightning/Water Shield charges and time left. Alerts: shield missing (in combat the shield icon turns red and pulses instead), Ghost Wolf in combat, low on Ankhs. Right-click an alert to snooze it. | each reminder on/off, shield icon size, Ankh threshold, snooze time |

**Appearance:** accent colour (Shaman, Air, Water, Fire, Earth), font, text size, bar texture, sounds,
out of combat opacity (0% = hidden), show the HUD when an enemy is targeted, HUD scale, edit mode grid,
reset positions.

**Low levels:** only what you have learned shows up. No Maelstrom bar before the talent, no totem slot
for an element you have no totem for, and the imbue buttons use the best imbue you know until your pick
(e.g. Windfury) is learned.

**Out of combat** the HUD is hidden. What stays: alerts (missing imbue or shield, a totem that died,
Ankhs) and the imbue buttons that need a click.

## Blizzard's own displays

Forever has a few built-in displays that overlap with this HUD. None of them is needed alongside it:

| Blizzard display | What to do |
|---|---|
| Swing timer | Swing & Cast Bar page: *Hide Blizzard's own swing timer* (same as `/console showSwingTimer 0`) |
| Cast bar | Hidden while the Cast Bar module is on (Swing & Cast Bar page: *Hide Blizzard's cast bar*; turning it back on needs a `/reload`) |
| Totem icons next to your portrait | Harmless; they stay (hiding Blizzard frames from an addon can break their buttons in combat) |
| Totem bar from Call of the Elements (level 20) | Keep it: that is where you set up and cast your totem sets |
| Cooldown Manager | Off unless you turned it on (Options > Gameplay Enhancements) |

## Key bindings

Options > Key Bindings > AddOns > Farseer - Shaman HUD:
recast the earth / fire / water / air totem, apply the main hand / off hand imbue.

## How it copes with Forever's addon limits

Forever runs the modern engine: there is no combat log, and in combat many values reach addons as
*secret values* that can be shown but not compared or calculated with. Farseer - Shaman HUD therefore

- uses events that are never secret: the native swing timer, your own casts, spell activation glows;
- hands secret values straight to widgets: duration objects for totem and cooldown timers;
- uses Blizzard's native aura container (`Blizzard_AuraContainer`) for Maelstrom stacks, shield charges,
  the proc row and the Flame Shock on your target, so the client draws them even while they are secret;
- never shows or hides those frames in combat (they fade instead) and re-reads exact state when combat ends;
- treats "unknown" as unknown: a value it cannot read never triggers a "missing" warning.

## Spells and IDs

Spells are found in your spellbook by name, so every rank and every client language works. Aura filters
need IDs, so the addon also carries the known IDs, including the Forever-only ones:

| Spell | ID |
|---|---|
| Maelstrom Weapon (talent / buff) | 408498 / 408505 |
| Water Shield | 408510, 408511 |
| Rage of the Farseer | 425336 |
| Fire Nova | 408341 |
| Totemic Call | 437009 |
| Totemic Recall | 36936 |
| Call of the Elements / Ancestors / Spirits | 66842 / 66843 / 66844 |
| Improved Stormstrike (buff) | 1238931 |
| Lightning Mastery | 16166 |

All of these except the Maelstrom buff are confirmed on the [Warcraft Wiki](https://warcraft.wiki.gg/wiki/Shaman_abilities_(Forever));
the buff ID 408505 comes from two independent addon sources, and the addon learns the real one in game anyway.
| Stormstrike | 17364 |

### What Forever changes (and what the addon does with it)

From the game client data of build 1.60.1.70862 (sources below). The addon never relies on these levels:
it shows what is in your spellbook, so this table is only what to expect while levelling.

| Level | New for an Enhancement Shaman | In the addon |
|---|---|---|
| 1 | Lightning Bolt, Rockbiter Weapon | imbue button (best imbue you know) |
| 4 / 6 / 8 | Earth Shock, Stoneskin / Earthbind / Lightning Shield, Stoneclaw | cooldown row, totem bar, shield icon |
| 10 | Flame Shock, Flametongue Weapon, Searing Totem, Strength of Earth | Flame Shock bar, fire totem slot |
| 12 | **Fire Nova** (a spell now: erupts at your fire totem; Fire Nova Totem is gone), Purge | cooldown row |
| 20 | **Call of the Elements** (drops a set of 4 totems, unlocks Blizzard's totem bar), **Totemic Recall** (returns all totems, refunds mana), Ghost Wolf, Frost Shock, Frostbrand | totems from a Call show up; no alerts after a Recall; Ghost Wolf warning |
| 22 | **Totemic Call** (teleports your totems to you, 30 s cooldown) | |
| 25 | **Stormstrike** (talent, row 4; was 40), Flurry | Earth Shock glow after Stormstrike, Flurry in the proc row |
| 26 / 28 | Magma, Mana Spring / Flametongue Totem | |
| 30 | Windfury Weapon, Reincarnation (needs an Ankh), Call of the Ancestors (second totem set) | imbue switches to Windfury, Ankh reminder |
| 32 | Chain Lightning, Windfury Totem | |
| 35 | **Maelstrom Weapon** (talent, row 6) | Maelstrom bar appears |
| 40 | **Rage of the Farseer** (talent, row 7: +30% attack speed for 25 s, 3 min cooldown), Call of the Spirits (third totem set) | cooldown row and proc row |
| 42 | Grace of Air Totem | |

Other Forever facts the addon is built on:
- Weapon imbues last **60 minutes** (Classic: 5); Lightning Shield 10 minutes with 3 charges; Flame Shock 12 s.
- Stormstrike: 150% weapon damage, **6 s cooldown**, and your next Earth Shock, Lightning Bolt or Chain Lightning
  within 12 s deals 20% more.
- Enhancement has **no dual wield** on Forever: a slow two-hander with Windfury Weapon. The off hand parts
  of the addon simply never show.
- Totemic Recall refunds 25% of the totems' mana: the addon reminds you for 10 s after a fight.
- Maelstrom Weapon: stacks up to 5, 20% faster and cheaper Lightning Bolt per stack, lasts 30 s.
- Improved Stormstrike: mana regeneration while casting, and Stormstrike's cooldown resets on dodge or parry.
- Totems: 1 s global cooldown; buff totems last 5 minutes.
- Elemental Mastery is now Lightning Mastery; Lava Burst, Fire Nova Totem, Tranquil Air Totem and
  Shamanistic Rage do not exist on Forever.

Sources: [The Forever Era: spells by level](https://theforeverera.com/en/spells/shaman/levels/),
[The Forever Era: Enhancement](https://theforeverera.com/en/classes/shaman/enhancement/),
[The Forever Era: Shaman changes](https://theforeverera.com/en/classes/shaman/),
[WoW Forever Talent Calculator: Shaman spells](https://wow-forever-talent-calculator.com/shaman/spells),
[WCLBox: Shaman spells by level](https://wowforever.wclbox.com/en/fashu/shaman/levels).

Plus every Classic rank of Lightning Shield, Flame/Earth/Frost Shock, Lightning Bolt, Chain Lightning and Purge
(see `Spells.lua`). `/sham spells` prints the IDs your client really uses.

## Testing in game

1. Optional but helpful: install **BugGrabber + BugSack**, or type `/console scriptErrors 1`.
2. Out of combat: `/sham` (screenshot the overview), `/sham spells`, `/sham probe`, `/sham edit`
   (screenshot), `/sham test`.
3. Check: cast Lightning Shield (shield icon shows charges), click each imbue button (does the off hand
   button really imbue the **off hand**?), drop a totem, left-click and right-click its icon.
4. Fight a few mobs for 2-3 minutes: proc row (Flurry after a crit), swing bars, Earth Shock glow after Stormstrike, Flame Shock bar,
   Maelstrom filling and turning gold at five, Lightning Bolt resetting it, mana bar, grey swing bar when
   you step out of range.
5. **In combat**, with a few Maelstrom stacks: `/sham probe`. Screenshot the HUD.
6. `/reload`, then send `World of Warcraft\_forever_\WTF\Account\<account>\SavedVariables\FarseerShamanHUD.lua`
   (it holds both probes and the spell list), the screenshots and any Lua errors.

### Troubleshooting

- `/sham` does nothing: the addon is not loaded. Check the folder path and the AddOns list at character select.
- An alert or module gets in the way: switch it off in `/sham`, then keep testing the rest.
- A frame is off screen: `/sham edit` > **Reset all**.

### Open points for the first test

- Whether the native aura container works in the real client (`/sham probe` shows `native` per slot).
- Unit of the imbue time left (assumed milliseconds; wrong if imbues warn all the time).
- Whether the off hand imbue button imbues the off hand.
- Whether Reincarnation needs an Ankh on Forever (turn the Ankh reminder off if not).

## Project layout

```
FarseerShamanHUD.toc   load order, interface 16001
Bindings.xml        key bindings
Core.lua            namespace, events, settings, modules, slash commands, secret-value helpers
Spells.lua          spell table, spellbook lookup, aura IDs
UI/                 Theme (look, rounded textures), Movers (edit mode), Alerts, Native (aura container),
                    Widgets and Options (settings window)
Modules/            Swing, Castbar, Mana, Totems, Imbues, Maelstrom, Procs, Shocks, Reminders
Probe.lua           /sham probe and /sham spells
Media/              rounded-corner textures (TGA)
tests/run.lua       offline test client
```

## Development

`lua5.1 tests/run.lua` loads the addon into a fake client (including secret values in combat and the native
aura container) and drives login, every settings page, edit mode, the mana bar, the fade and a combat sequence.
Any Lua error fails the run.

When Blizzard patches Forever, bump `## Interface` in the TOC to the new number and release, so the addon
never shows as out of date.

Releases: write the notes in `CHANGELOG.md` and bump `## Version` in the TOC, then on GitHub go to
*Releases* > *Draft a new release*, create the tag `vX.Y.Z` on `main` and publish. The GitHub Action runs the test
and attaches the addon zip and `release.json` (flavor `forever`, used by WowUp) to that release
(`.pkgmeta` leaves out `tests` and `.github`).

## License

MIT, see [LICENSE](LICENSE).
