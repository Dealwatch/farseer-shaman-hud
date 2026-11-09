# Shammy Forever

Enhancement Shaman toolkit for **WoW Forever** (interface 16001). Working title, the name will change.

## Install (manual)

1. Download `ShammyForever-<version>.zip` from the releases (or the zip you were sent).
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns\` so you get
   `...\AddOns\ShammyForever\ShammyForever.toc`.
3. Restart the game (a `/reload` is not enough for a new addon).

## Commands

| Command | |
|---|---|
| `/sham` | Settings window |
| `/sham edit` | Edit mode: drag frames, arrows nudge, right-click resets |
| `/sham test` | Preview alerts |
| `/sham probe` | What Forever lets the addon read right now. Run it once out of combat and once **in combat** |
| `/sham spells` | Copyable list of your spells and their IDs |
| `/sham reset confirm` | Reset all settings |

## Modules

- **Swing timer** – main and off hand from Forever's native swing events, casts projected onto the bar (red = the cast delays your swing), grey when out of melee range.
- **Totem bar** – Earth, Fire, Water, Air with time left. Left-click recasts the last totem of that element, right-click destroys it.
- **Weapon imbues** – time left per hand, click to apply your chosen imbue, warnings when missing or running out.
- **Maelstrom Weapon** – five pips; glow and sound at five stacks (instant Lightning Bolt).
- **Stormstrike & shocks** – "Shock now!" right after Stormstrike, Flame Shock timer, cooldown icons.
- **Reminders** – Lightning Shield missing, Ghost Wolf in combat, low on Ankhs.

## Key bindings

Options > Key Bindings > AddOns > Shammy Forever: recast the earth/fire/water/air totem, apply the main/off hand imbue.

## How it copes with Forever's addon limits

Forever runs the modern engine: no combat log, and in combat many values reach addons as *secret values*
that can be shown but not compared. Shammy Forever therefore

- uses native events that are never secret (swing timer, your own casts, spell glows),
- feeds secret values straight into widgets (duration objects for totem and cooldown timers),
- uses Blizzard's native aura container for Maelstrom stacks, shield charges and the Flame Shock on your target, so the client fills them in even while the values are secret,
- re-reads exact state the moment combat ends,
- finds spells by your spellbook, not by hard-coded IDs, so Forever-only spell IDs and any client language work.

## Feedback for the first test

Please send:
1. `/sham probe` out of combat **and** in combat (while hitting a mob, with a few Maelstrom stacks).
2. `/sham spells`.
3. Screenshots of anything that looks wrong and any Lua errors (BugSack/BugGrabber help).

Both diagnostics are also saved in `WTF\Account\<account>\SavedVariables\ShammyForever.lua`.

## Development

`lua5.1 tests/run.lua` loads the addon into a fake client (including secret values in combat) and drives
login, every settings page, edit mode and a combat sequence.

Releases: push a tag `vX.Y.Z`; the GitHub Action runs the test and builds the release zip.
