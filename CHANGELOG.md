# Changelog

## 0.7.1
- The icon to press stands out more: a second, soft gold ring around it and a gold shimmer over the icon
  itself, and the pulse no longer fades to almost nothing.
- Not enough mana: the icon turns blue, as on the game's action bars (was: dimmed like everything else
  that is not possible). Red stays "out of melee range", dimmed is now only "not possible right now"
  (fewer than five Maelstrom stacks, no fire totem for Fire Nova).

## 0.7.0
See at a glance what you can press and what you should press. Order as the Forever guides give it
(Method, Warcraft Tavern, wowforever.be).
- New: next-spell glow. In combat exactly one icon glows gold, your next press: Fire Nova while your
  Magma Totem is down (a group), Flame Shock when it is missing or about to run out, Stormstrike,
  Lightning Bolt at five Maelstrom Weapon, Earth Shock as filler.
  Replaces the "Shock prompt after Stormstrike"; same switch, now "Glow on the next spell".
- Every icon in the row reads the same way: gold ring = press now, bright = ready, dark with a number =
  on cooldown, dimmed = not possible right now (no mana, fewer than five Maelstrom stacks, no fire totem
  for Fire Nova), red = target out of melee range (Stormstrike; the glow then moves on to your shock).
- New: Lightning Bolt icon in the row (with Maelstrom Weapon): dimmed until five stacks, so the next
  press is always in the same place. The Maelstrom bar glows along with it.
- The shock icon shows the shock to use: Flame Shock when it is due, Earth Shock otherwise.
- New: gold underline under the spells Stormstrike's 20% bonus would boost right now (Earth Shock, the
  Bolt at five stacks); it drains over the 12 s the bonus lasts.
- New default layout: the icons you press stand alone on their line under the bars. Totems moved to the
  left of the bars, shield and imbue buttons to the right. Frames you already moved stay where they are;
  `/sham edit` > Reset all gives you the new layout.
- Magma Totem down switches to the group order (Fire Nova first); Searing Totem or none: single target.
- New: a totem slot pulses in its last seconds, in combat too, and dims when the time is up
  (Totems > "Pulse before a totem runs out"). Durations are learned from the client, with Forever's
  values as a start (Magma 20 s, Stoneclaw 15 s, Earthbind and Grounding 45 s, buff totems 5 min).
- New: Rotation page in the settings (`/sham rotation`): the order behind the glow, how to read the
  icons, and what you have not learned yet greyed out.
- Flame Shock timer is per target now: a new target starts without one instead of showing the old timer.
- No ready-flash on the icon that starts to glow gold anyway: one signal at a time.
- The big "Shock now!" card shows while Stormstrike's bonus waits for an Earth Shock; the setting
  "Prompt stays for" is gone (the bonus lasts 12 s).
- Text fit: the swing time and the imbue time ("50m", "none") now stay inside their bar or icon at every
  HUD text size and icon size; the Maelstrom tile on the overview reads "native bar".
- Procs page: the leftover "Reload UI" button is gone (the icon size applies right away since 0.5.4).
- README: status, test steps and open points for this version.
- In combat cooldowns can be hidden from addons: "ready" then goes by your own casts (Stormstrike 6 s,
  shocks 6 s, Fire Nova 10 s, corrected whenever the client shows the real numbers). A Stormstrike
  reset by a dodge or parry can therefore glow late.

## 0.6.0
- New: cast bar in the HUD style with spell icon, name and time left. Casts and channels; a cut-off cast
  turns red ("Interrupted") for a moment. The fill comes from the client's duration object, so it also runs
  when cast times are secret in combat. Shows out of combat too (heals, Ghost Wolf).
- Blizzard's own player cast bar is switched off while ours is on (setting "Hide Blizzard's cast bar").
- The Swing Timer page is now "Swing & Cast Bar".

## 0.5.5
Layout review: the HUD and every settings page were rebuilt offline with real anchor maths and text
measuring, at text sizes 0.7x to 1.5x.
- Fix: the big "Shock now!" card sat on the proc row, and "Instant Bolt!" touched the proc icons.
  New default positions: procs and the card sit higher. Frames you already moved stay where they are.
- Fix: with five cooldown icons the cooldown row touched the totem bar and the imbue buttons.
  Totems, imbues and the shield icon start a little further out.
- Fix: long alert texts were cut off ("Flametongue Weapon on main hand runs out", totem and recall
  texts). Cards are wider and the texts shorter.
- Fix: a long stack of alerts reached down into the HUD. At most four alerts show at once, the most
  important first; the rest follow as you clear them.
- Fix: "Text size" above 1.0 broke the settings window, edit mode and the alert cards (text over text,
  text outside its box). The setting is now "HUD text size": it scales the HUD texts and the alert
  cards as a whole; the settings window and edit mode keep their own size.
- Fix: "Edit layout" left the settings window open on top of the frames you want to drag, with the
  edit-mode bar over its title. The window now closes when edit mode starts.
- Fix: settings texts that were cut off: the Reminders description on the overview, imbue names with
  "(not learned)" in the dropdown, and the "10m 00s" snooze value ran into its slider.
- README: procs icon size no longer needs a /reload; Stormstrike row back inside the spell table.

## 0.5.4
- Fix: settings sliders (icon sizes, widths, heights, timers, text size, scale, ...) still did not save or
  apply. Root cause: every slider got its format function where the save function belonged, so 0.5.3
  fixed the wrong thing. All 23 sliders are now covered by a test that drives the real settings pages.
- Procs icon size now applies right away (out of combat), no /reload; the edit-mode preview and the
  mover box follow the size too.
- Edit mode grid redraws when you change its size while edit mode is open.
- New test: every one of the 61 settings is changed out of combat, in combat and in edit mode and must
  visibly change the HUD; the few that only act on a later event (sounds, alerts, timers) are listed
  and were checked by hand.

## 0.5.3
- Fix: no shield warning in combat. Buffs are secret to addons in combat, so the text alert can't see
  the shield drop. The shield icon now turns red and pulses as soon as the shield is gone; the client
  covers it while the shield is up.
- Attempted fix for settings sliders not saving; the real cause was fixed in 0.5.4.

## 0.5.2
First in-game test (level 15): 29 of 31 checks passed, native aura slots confirmed in the real client.
- New: cooldown icons flash once when the cooldown your cast started is over (Stormstrike, shocks,
  Fire Nova, Rage of the Farseer). Setting: Stormstrike & Shocks > "Flash when a spell is ready again".
- Fix: mana bar now turns red in combat too. The mana value is secret there, so the client colours
  the bar through a colour curve.
- Fix: overview imbue tile showed "MH on" instead of the time left, and an off hand entry with a two-hander.
- Cleaner settings window: hero text no longer runs under the buttons, module descriptions use two
  lines instead of being cut off; edit-mode header text no longer runs under its buttons.
- /sham probe also reports mana values.

## 0.5.1
- Fix: pulling with 0 Maelstrom stacks hid the Maelstrom bar for the whole fight. PLAYER_REGEN_DISABLED
  fires before the combat lockdown starts, so visibility now uses a combat flag set first thing at the pull.
- Fix: with edit mode open at the pull (and no enemy targeted) the whole HUD stayed hidden in combat.
- Fix: stack overflow when auras are secret out of combat (battlegrounds, encounters): native aura slots
  now retry on a timer instead of recursing.
- Regression tests for all three.

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
