# Farseer – Shaman HUD

Enhancement Shaman HUD / UI for **WoW Forever** (interface 16001, build 1.60.1).

One clean HUD for everything an Enhancement Shaman watches: swing timer, cast bar, mana, Maelstrom Weapon, Flame Shock,
cooldowns, totems, weapon imbues, Lightning Shield and reminders. Every element can be moved, resized or
switched off. The addon is in English.

> Status: **0.7.1.** Last tested in game with 0.5.2 at level 15. Everything since (the layout review, the cast
> bar, the next-spell glow and the new default layout) and the features from later levels (Stormstrike, Maelstrom
> Weapon, Rage of the Farseer, ...) are built against Blizzard's Forever UI code and an offline test client,
> not yet confirmed in game. What to check is under [Testing in game](#testing-in-game).

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
3. Fight something. The HUD shows in combat and while an enemy is targeted; the icon with the gold glow is
   your next press (`/sham rotation` explains the order). Out of combat it is hidden; only alerts, the cast
   bar while you cast, and imbue buttons that need you (missing or running out) stay on screen.

## Commands

| Command | |
|---|---|
| `/farseer` (or `/sham`) | Settings window |
| `/sham rotation` | What to press, in order (the list behind the gold glow) |
| `/sham edit` | Edit mode: drag frames (snaps to the grid, Shift = free), arrow keys nudge (Shift = 10px), right-click resets a frame |
| `/sham test` | Preview the alerts for 8 seconds |
| `/sham probe` | What Forever lets the addon read right now. Run it once out of combat and once **in combat** |
| `/sham spells` | Copyable list of your spellbook with spell IDs |
| `/sham reset confirm` | Reset all settings and positions |
| `/sham help` | List of these commands in chat |

The addon also has an entry in the minimap's addon compartment.

## Default layout

One 240px column under your character. The icons you press stand alone on their own line; upkeep
(totems on the left, shield and imbue buttons on the right) sits beside the bars:

```
                    [Fl][CC][RF]                       Procs: only what is up right now
                             Instant Bolt!             <- only at five stacks
                [====|====|====|    |    ]             Maelstrom Weapon (5 segments)
[E][F][W][A]    [=========|           1.1]    [LS][MH] Swing timer | totems left, shield + imbue right
                [==============          ]             Mana
                [F][=============     8.3]             Flame Shock on your target

                  [SS][Shock][Bolt][FN][RF]            What you press: Stormstrike, shock, Bolt, Fire Nova, burst
                       ====  ====                      Gold underline: boosted by Stormstrike right now
                [i][Lightning Bolt     1.2]            Cast bar (only while casting)
```

Every icon in that row reads the same way: **gold glow** (ring and shimmer) = press now, **bright** = ready,
**dark with a number** = on cooldown, **blue** = not enough mana, **red** = target out of melee range,
**dimmed** = not possible right now (fewer than five Maelstrom stacks, no fire totem for Fire Nova).

If you widen the bars beyond about 270px, drag the totem and shield frames outwards in edit mode.

Alerts stack at the top of the screen (the four most important at a time). All positions are saved per account.

## Modules

| Module | What it shows | Settings |
|---|---|---|
| **Swing Timer** | Main hand bar with time to the next swing, thin off hand line. Casts are projected onto the bar and turn red when they delay your swing. Grey when the target is out of melee range. | width, height, off hand, cast projection, range tint, text, hide when not fighting |
| **Cast Bar** | Your casts and channels with icon, spell name and time left; red "Interrupted" when a cast is cut off. Runs in combat too, also when the client hides the cast times from addons (then without the time text). Shows out of combat as well (heals, Ghost Wolf). | width, height, icon, time left, hide Blizzard's cast bar |
| **Mana Bar** | Thin mana bar, red when low, hidden at full mana out of combat. | width, height, red below %, percentage text, hide at full |
| **Totem Bar** | Earth, Fire, Water, Air with time left (only elements you have a totem for). Left-click recasts the last totem of that element, right-click destroys it. Totems from Call of the Elements/Ancestors/Spirits show up too. A slot pulses in its totem's last seconds (in combat too). Alerts when a totem dies, and a Totemic Recall reminder after combat. | icon size, spacing, time left, empty slots, hide when no totem, pulse before it runs out, expiry alert, recall reminder |
| **Weapon Imbues** | Shown when an imbue is missing or about to run out (or always, if you prefer), with time left. Click a button to apply your chosen imbue. Stays visible out of combat when needed. Not with a fishing pole. | imbue per hand, warn below minutes, when needed / always, warn in combat, icon size |
| **Procs** | One centred row that shows only active procs and burst buffs: Flurry, Clearcasting, Improved Stormstrike, Rage of the Farseer, Lightning Mastery, Nature's Swiftness, with time-left swipe and stacks. | icon size |
| **Maelstrom Weapon** | Five-segment bar that turns gold at five stacks, with glow, sound and "Instant Bolt!". | width, height, glow, sound, hide at zero |
| **Stormstrike & Shocks** | One row of icons for what you press: Stormstrike, your shock, the Bolt (with Maelstrom Weapon), Fire Nova, Rage of the Farseer, Lightning Mastery, each with its cooldown (the global cooldown ignored). **Next-spell glow:** one icon glows gold, your next press (see *Rotation* below). The shock icon shows the shock to use, the Bolt icon lights up at five Maelstrom stacks, and a gold underline marks what Stormstrike's 20% bonus would boost right now. Blue icons lack mana, a red Stormstrike is out of range, dimmed icons cannot be pressed right now. Flame Shock bar with the real time left on your target. | next-spell glow, optional big "Shock now!" card, Flame Shock bar, its fallback duration and width, cooldown row and icon size, ready flash |
| **Reminders** | Shield icon with Lightning/Water Shield charges and time left. Alerts: shield missing (in combat the shield icon turns red and pulses instead), Ghost Wolf in combat, low on Ankhs. Right-click an alert to snooze it. | each reminder on/off, shield icon size, Ankh threshold, snooze time |

**Appearance:** accent colour (Shaman, Air, Water, Fire, Earth), font, HUD text size, bar texture, sounds,
out of combat opacity (0% = hidden), show the HUD when an enemy is targeted, HUD scale, edit mode grid,
reset positions.

**Low levels:** only what you have learned shows up. No Maelstrom bar before the talent, no totem slot
for an element you have no totem for, and the imbue buttons use the best imbue you know until your pick
(e.g. Windfury) is learned.

**Out of combat** the HUD is hidden. What stays: alerts (missing imbue or shield, a totem that died,
Ankhs), the imbue buttons that need a click, and the cast bar while you cast.

## Rotation

In combat with an enemy targeted exactly one thing glows gold: the next press. The order is the one the
Forever guides agree on ([Method](https://www.method.gg/wow-forever/class-guides/enhancement-shaman/rotation-and-playstyle),
[Warcraft Tavern](https://www.warcrafttavern.com/forever/guides/enhancement-shaman/),
[wowforever.be](https://wowforever.be/guides/enhancement-shaman/)); `/sham rotation` shows it in game.

1. **Fire Nova**, only while your Magma Totem is down (that means a group): first, every time it is ready.
2. **Flame Shock** when it is missing on your target or has under 3 s left (its bar turns red).
3. **Stormstrike** on cooldown.
4. **Lightning Bolt** at five Maelstrom Weapon: the Bolt icon and the Maelstrom bar glow.
5. **Earth Shock** as filler.

What is not ready, not learned, not affordable or out of melee range (Stormstrike) is skipped. Switch it off under Stormstrike & Shocks >
*Glow on the next spell*. Limits: in combat the client can hide cooldowns from addons, then "ready" goes by
your own casts, so a Stormstrike reset by a dodge or parry can glow late; a missed or resisted Flame Shock
still counts as applied until the client shows otherwise.

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
| Stormstrike | 17364 |

All of these except the Maelstrom buff are confirmed on the [Warcraft Wiki](https://warcraft.wiki.gg/wiki/Shaman_abilities_(Forever));
the buff ID 408505 comes from two independent addon sources, and the addon learns the real one in game anyway.

### What Forever changes (and what the addon does with it)

From the game client data of build 1.60.1.70862 (sources below). The addon never relies on these levels:
it shows what is in your spellbook, so this table is only what to expect while levelling.

| Level | New for an Enhancement Shaman | In the addon |
|---|---|---|
| 1 | Lightning Bolt, Rockbiter Weapon | imbue button (best imbue you know) |
| 4 / 6 / 8 | Earth Shock, Stoneskin / Earthbind / Lightning Shield, Stoneclaw | cooldown row, totem bar, shield icon |
| 10 | Flame Shock, Flametongue Weapon, Searing Totem, Strength of Earth | Flame Shock bar, fire totem slot |
| 12 | **Fire Nova** (a spell now: erupts at your fire totem; Fire Nova Totem is gone), Purge | Fire Nova icon, dimmed while no fire totem stands |
| 20 | **Call of the Elements** (drops a set of 4 totems, unlocks Blizzard's totem bar), **Totemic Recall** (returns all totems, refunds mana), Ghost Wolf, Frost Shock, Frostbrand | totems from a Call show up; no alerts after a Recall; Ghost Wolf warning |
| 22 | **Totemic Call** (teleports your totems to you, 30 s cooldown) | |
| 25 | **Stormstrike** (talent, row 4; was 40), Flurry | Stormstrike icon and its place in the glow order, gold underline for its bonus, Flurry in the proc row |
| 26 / 28 | Magma, Mana Spring / Flametongue Totem | Magma Totem down switches the glow to the group order (Fire Nova first) |
| 30 | Windfury Weapon, Reincarnation (needs an Ankh), Call of the Ancestors (second totem set) | imbue switches to Windfury, Ankh reminder |
| 32 | Chain Lightning, Windfury Totem | |
| 35 | **Maelstrom Weapon** (talent, row 6) | Maelstrom bar and Bolt icon appear |
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
- Totems: 1 s global cooldown; buff totems last 5 minutes, Magma Totem 20 s, Stoneclaw 15 s, Earthbind and
  Grounding 45 s, Searing Totem 30 to 55 s by rank.
- Shocks: 6 s cooldown. Fire Nova: 10 s cooldown, hits within 10 yd of your fire totem.
- Elemental Mastery is now Lightning Mastery; Lava Burst, Fire Nova Totem, Tranquil Air Totem and
  Shamanistic Rage do not exist on Forever.

Sources: [The Forever Era: spells by level](https://theforeverera.com/en/spells/shaman/levels/),
[The Forever Era: Enhancement](https://theforeverera.com/en/classes/shaman/enhancement/),
[The Forever Era: Shaman changes](https://theforeverera.com/en/classes/shaman/),
[WoW Forever Talent Calculator: Shaman spells](https://wow-forever-talent-calculator.com/shaman/spells),
[WCLBox: Shaman spells by level](https://wowforever.wclbox.com/en/fashu/shaman/levels),
Warcraft Wiki, Forever sections of [Fire Nova](https://warcraft.wiki.gg/wiki/Fire_Nova#Forever),
[Earth Shock](https://warcraft.wiki.gg/wiki/Earth_Shock#Forever), [Flame Shock](https://warcraft.wiki.gg/wiki/Flame_Shock#Forever)
and [Magma Totem](https://warcraft.wiki.gg/wiki/Magma_Totem#Forever).

Plus every Classic rank of Lightning Shield, Flame/Earth/Frost Shock, Lightning Bolt, Chain Lightning and Purge
(see `Spells.lua`). `/sham spells` prints the IDs your client really uses.

## Testing in game

1. Optional but helpful: install **BugGrabber + BugSack**, or type `/console scriptErrors 1`.
2. Out of combat: `/sham` (screenshot the overview), `/sham rotation`, `/sham spells`, `/sham probe`,
   `/sham edit` (screenshot; **Reset all** there gives you the 0.7.0 default layout), `/sham test`.
3. Check: cast Lightning Shield (shield icon shows charges), click the imbue button, drop a totem,
   left-click and right-click its icon. Cast something with a cast time (cast bar, Blizzard's own one gone).
4. Fight a few mobs for 2-3 minutes and watch the icon row:
   - exactly one icon with the gold glow (ring and shimmer) at a time, in the order of the Rotation page;
     nothing glows while everything is on cooldown;
   - run out of mana: the icons you cannot afford turn blue and lose the glow;
   - the shock icon shows Flame Shock on a fresh target and Earth Shock while Flame Shock runs;
   - step out of melee range: Stormstrike turns red (the swing bar turns grey) and loses the ring;
   - Fire Nova is dimmed without a fire totem; with Magma Totem down it gets the ring first;
   - a totem slot pulses in its last seconds (easiest with Magma or Stoneclaw);
   - from level 25: gold underline under Earth Shock after Stormstrike; from level 35: the Bolt icon is
     dimmed below five Maelstrom stacks and gets the ring at five, together with the Maelstrom bar;
   - as before: proc row (Flurry after a crit), swing bar, Flame Shock bar, mana bar.
5. **In combat**: `/sham probe`. Screenshot the HUD.
6. `/reload`, then send `World of Warcraft\_forever_\WTF\Account\<account>\SavedVariables\FarseerShamanHUD.lua`
   (it holds both probes and the spell list), the screenshots and any Lua errors.

### Troubleshooting

- `/sham` does nothing: the addon is not loaded. Check the folder path and the AddOns list at character select.
- An alert or module gets in the way: switch it off in `/sham`, then keep testing the rest.
- A frame is off screen, or you want the default layout back: `/sham edit` > **Reset all**.
- The gold glow is distracting or wrong: Stormstrike & Shocks > *Glow on the next spell* off; the icons
  still show cooldown, blue, red and dimmed.

### Open points for the next test

- Whether the gold glow comes on time in combat. If the client hides cooldowns there, the addon goes by
  your own casts (the in-combat `/sham probe` shows `<secret>` in the Cooldowns section in that case).
- Whether Stormstrike turning red matches the swing bar turning grey; if that range signal were wrong,
  Stormstrike would never get the ring.
- Whether the Bolt icon follows five Maelstrom stacks when the stacks themselves are hidden from addons
  (it then relies on the Lightning Bolt glow of the client).
- Whether a totem slot pulses and dims at the right time (durations are learned out of combat).
- Unit of the imbue time left (assumed milliseconds; wrong if imbues warn all the time).
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
aura container) and drives login, every settings page, edit mode, the cast bar, the mana bar, the fade, a combat
sequence and the next-spell glow step by step.
Any Lua error fails the run.

When Blizzard patches Forever, bump `## Interface` in the TOC to the new number and release, so the addon
never shows as out of date.

Releases: write the notes in `CHANGELOG.md` and bump `## Version` in the TOC, then on GitHub go to
*Releases* > *Draft a new release*, create the tag `vX.Y.Z` on `main` and publish. The GitHub Action runs the test
and attaches the addon zip and `release.json` (flavor `forever`, used by WowUp) to that release
(`.pkgmeta` leaves out `tests` and `.github`). The release text is replaced by the `CHANGELOG.md` section of the
TOC version (the job fails if that section is missing; the zip is attached by then).

## License

MIT, see [LICENSE](LICENSE).
