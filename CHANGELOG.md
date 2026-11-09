# Changelog

## 0.5.0
- New name: **Farseer – Shaman HUD** (addon folder `FarseerShamanHUD`, `/farseer`; `/sham` still works).
  Settings and positions start fresh once (new saved-variables name).
- Swing Timer page: switch off Blizzard's own swing timer (CVar showSwingTimer)
- MIT license

## 0.4.0
- New: proc row above the Maelstrom bar, showing only what is up (Flurry, Clearcasting,
  Improved Stormstrike, Rage of the Farseer, Lightning Mastery, Nature's Swiftness)
  with time-left swipe and stacks; filled by the client (native aura group), also in combat
- Out of combat the HUD is now hidden (was 50%). What stays: alerts, and the imbue buttons when an
  imbue is missing or running out. Targeting an enemy shows the HUD before the pull.
  Appearance: "Out of combat" opacity (0% = hidden) and "Show the HUD when an enemy is targeted"
- Imbue buttons default to "When needed"; invisible buttons no longer catch clicks
- Low levels: if your chosen imbue is not learned yet, the best imbue you know is used (e.g. Rockbiter)
- Off hand weapon detection falls back to the item in the off hand slot
- Totemic Recall reminder after combat while totems are down (Forever tip: refunds 25% of their mana)
- Stormstrike texts: on Forever it boosts the next Earth Shock, Lightning Bolt or Chain Lightning
- Spell IDs verified on the Warcraft Wiki (Forever pages); Call of the Ancestors is 66843
- Researched against Forever client data (build 1.60.1.70862): removed spells that do not exist on
  Forever (Shamanistic Rage, Fire Nova Totem, Tranquil Air Totem); README has a Forever level table
- Forever totem tools: totems dropped by Call of the Elements / Ancestors / Spirits show up (icon
  from the client, also in combat); Totemic Recall no longer raises "totem is gone" alerts
- Low levels: the Maelstrom bar stays hidden until you have the talent; the totem bar only shows
  elements you have a totem for (no empty Water/Air slots), and re-lays itself out as you learn more
- Overview: the Maelstrom tile shows "native stack bar" when the client draws it

## 0.3.0
- New: mana bar (thin, red when low, hides at full mana out of combat)
- Cleaner HUD: one 240px column under the character (Maelstrom, swing, mana, Flame Shock) and one
  icon row (totems | cooldowns | imbues + shield), all icons 30px
- HUD fades to 50% out of combat without an enemy target (Appearance > Fade out of combat)
- Shock prompt: the Earth Shock icon in the cooldown row glows; the big card is optional
- Maelstrom: one five-segment bar (width/height settings), no extra labels
- Less text: no hand labels on the swing bars, no range text (grey tint instead),
  no MH/OH tags, no name on the Flame Shock bar, no mini bars under totems
- Cooldown icons ignore the global cooldown
- README rewritten: layout, every module and its settings, spell IDs, in-game test steps, troubleshooting

## 0.2.0
- Native aura slots (Blizzard_AuraContainer): the client itself fills
  - the Maelstrom Weapon stack bar (also in combat, even when the buff is secret)
  - a new shield icon with Lightning/Water Shield charges and time left
  - the Flame Shock bar with the real time left of your Flame Shock on the target
  Falls back to the previous behaviour if the container is not available.
- Forever spell IDs: Maelstrom Weapon talent 408498 / buff 408505, Water Shield 408510/408511,
  Rage of the Farseer 425336, Fire Nova 408341, Totemic Call 437009, all ranks of shocks,
  Lightning Bolt, Chain Lightning, Lightning Shield and Purge
- Fire Nova joins the cooldown row
- Key bindings: recast each element's totem, apply main/off hand imbue
- No imbue warning while a fishing pole is equipped
- Fix: an empty enchant list now counts as "no imbue"; unreadable entries never warn
- /sham probe lists the native slots and per-spell aura secrecy

## 0.1.1
- Rounded corners everywhere (windows, cards, buttons, alerts, icons, bars), round switch knobs and slider thumbs

## 0.1.0
First test build for WoW Forever.
- Swing timer (main and off hand), cast projection, melee range tint
- Totem bar: time left per element, click to recast, right-click to destroy, expiry alerts
- Weapon imbues: timers per hand, click to apply, missing/expiring warnings
- Maelstrom Weapon pips (exact stacks or five-stack glow)
- "Shock now!" after Stormstrike, Flame Shock timer, cooldown icons
- Reminders: Lightning Shield, Ghost Wolf in combat, Ankhs
- Settings window, edit mode, appearance, /sham probe and /sham spells diagnostics
