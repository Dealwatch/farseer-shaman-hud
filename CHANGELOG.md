# Changelog

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
