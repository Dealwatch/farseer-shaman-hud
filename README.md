# Shammy Forever

Enhancement Shaman toolkit for **WoW Forever** (interface 16001, build 1.60.1). Working title, the name will change.

One clean HUD for everything an Enhancement Shaman watches: swing timer, mana, Maelstrom Weapon, Flame Shock,
cooldowns, totems, weapon imbues, Lightning Shield and reminders. Every element can be moved, resized or
switched off. The addon is in English.

> Status: **0.4.0, first in-game test pending.** Everything below is built against Blizzard's Forever UI code
> and an offline test client, not yet confirmed in the real game.

## Install

1. Download `ShammyForever-<version>.zip` (release or the zip you were sent).
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns\` so you get
   `...\AddOns\ShammyForever\ShammyForever.toc` (not `ShammyForever\ShammyForever\...`).
3. Restart the game completely (a `/reload` is not enough for a new addon).
4. Character select > **AddOns**: make sure *Shammy Forever* is ticked. If it shows as out of date,
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
| `/sham` (or `/shammy`) | Settings window |
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
```

Alerts stack at the top of the screen. All positions are saved per account.

## Modules

| Module | What it shows | Settings |
|---|---|---|
| **Swing Timer** | Main hand bar with time to the next swing, thin off hand line. Casts are projected onto the bar and turn red when they delay your swing. Grey when the target is out of melee range. | width, height, off hand, cast projection, range tint, text, hide when not fighting |
| **Mana Bar** | Thin mana bar, red when low, hidden at full mana out of combat. | width, height, red below %, percentage text, hide at full |
| **Totem Bar** | Earth, Fire, Water, Air with time left. Left-click recasts the last totem of that element, right-click destroys it. Alert when a totem dies or expires. | icon size, spacing, time left, empty slots, hide when no totem, expiry alert |
| **Weapon Imbues** | Shown when an imbue is missing or about to run out (or always, if you prefer), with time left. Click a button to apply your chosen imbue. Stays visible out of combat when needed. Not with a fishing pole. | imbue per hand, warn below minutes, when needed / always, warn in combat, icon size |
| **Procs** | One centred row that shows only active procs and burst buffs: Flurry, Clearcasting, Improved Stormstrike, Rage of the Farseer, Lightning Mastery, Nature's Swiftness, Shamanistic Rage, with time-left swipe and stacks. | icon size (after /reload) |
| **Maelstrom Weapon** | Five-segment bar that turns gold at five stacks, with glow, sound and "Instant Bolt!". | width, height, glow, sound, hide at zero |
| **Stormstrike & Shocks** | Cooldown icons (Stormstrike, Earth Shock, Fire Nova, Rage of the Farseer and other cooldowns you know, the global cooldown ignored). Right after Stormstrike the Earth Shock icon glows gold. Flame Shock bar with the real time left on your target. | shock prompt, optional big "Shock now!" card, prompt duration, Flame Shock bar and width, cooldown row and icon size |
| **Reminders** | Shield icon with Lightning/Water Shield charges and time left. Alerts: shield missing, Ghost Wolf in combat, low on Ankhs. Right-click an alert to snooze it. | each reminder on/off, shield icon size, Ankh threshold, snooze time |

**Appearance:** accent colour (Shaman, Air, Water, Fire, Earth), font, text size, bar texture, sounds,
out of combat opacity (0% = hidden), show the HUD when an enemy is targeted, HUD scale, edit mode grid,
reset positions.

**Low levels:** only what you have learned shows up. No Maelstrom bar before the talent, no totem slot
for an element you have no totem for, and the imbue buttons use the best imbue you know until your pick
(e.g. Windfury) is learned.

**Out of combat** the HUD is hidden. What stays: alerts (missing imbue or shield, a totem that died,
Ankhs) and the imbue buttons that need a click.

## Key bindings

Options > Key Bindings > AddOns > Shammy Forever:
recast the earth / fire / water / air totem, apply the main hand / off hand imbue.

## How it copes with Forever's addon limits

Forever runs the modern engine: there is no combat log, and in combat many values reach addons as
*secret values* that can be shown but not compared or calculated with. Shammy Forever therefore

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
| Stormstrike | 17364 |

Forever is not Classic: Fire Nova is a spell (level 12), Call of the Elements and Totemic Recall come at 20,
Call of the Ancestors at 30 and Call of the Spirits at 40, Elemental Mastery is now Lightning Mastery, and
Stormstrike, Maelstrom Weapon and Rage of the Farseer work differently. The addon never relies on a level
table: it shows what is in your spellbook.

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
6. `/reload`, then send `World of Warcraft\_forever_\WTF\Account\<account>\SavedVariables\ShammyForever.lua`
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
ShammyForever.toc   load order, interface 16001
Bindings.xml        key bindings
Core.lua            namespace, events, settings, modules, slash commands, secret-value helpers
Spells.lua          spell table, spellbook lookup, aura IDs
UI/                 Theme (look, rounded textures), Movers (edit mode), Alerts, Native (aura container),
                    Widgets and Options (settings window)
Modules/            Swing, Mana, Totems, Imbues, Maelstrom, Procs, Shocks, Reminders
Probe.lua           /sham probe and /sham spells
Media/              rounded-corner textures (TGA)
tests/run.lua       offline test client
```

## Development

`lua5.1 tests/run.lua` loads the addon into a fake client (including secret values in combat and the native
aura container) and drives login, every settings page, edit mode, the mana bar, the fade and a combat sequence.
Any Lua error fails the run.

Releases: write the notes in `CHANGELOG.md`, push a tag `vX.Y.Z`; the GitHub Action runs the test and builds
the release zip (`.pkgmeta` leaves out `tests` and `.github`).
