# MPlate

A lightweight World of Warcraft addon that lets you customize nameplates beyond the default interface options.

## Features

- **Text Size** — Adjust font size for nameplate names and cast bar text
- **Level & Health Text Size** — Adjust level numbers and health text together (8–36), including numeric and percentage health displays, without resizing health bars
- **Minimum Overhead Name Size** — Adjust the minimum size of ordinary overhead names, including with friendly nameplates off and no player selected (0–64, step 2)
- **Health Bar Size** — Change health bar width and height
- **Selected Nameplate Scale** — Adjust the game's shared selected-plate scale (0.5–2.0, step 0.05)
- **Health Bar Border** — Toggle the health bar border on or off
- **Health Text Position** — Offset health text horizontally and vertically
- **Enemy Name Width** — Extend the display width of enemy names

All settings are accessible via the addon settings panel. Type `/mplate` to open it.

## Installation

1. Download and extract the `MPlate` folder into the appropriate client directory:
   - Retail: `World of Warcraft/_retail_/Interface/AddOns/`
   - WoW Forever (魔兽世界“无限”): `World of Warcraft/_forever_/Interface/AddOns/`
2. Restart the game or type `/reload` if already logged in.

## Usage

- Type `/mplate` in chat to open the settings panel.
- Each option has a reset button to restore the system default.
- Use "Reset All" at the bottom to restore all settings at once.

**Level & Health Text Size** applies one size to both level numbers (Forever's
level badge and Classic-style nameplates) and health text. The addon saves the
choice across reloads and keeps it fixed when the game's nameplate size changes.
Its reset button and **Reset All** restore each text's own current game default,
which may differ between level and health text. Existing saved level size choices
also apply to health text. Unit names and cast text use their separate controls.
Forever's level badge background and its target/focus outline are hidden, leaving
the level number or skull visible. Level colors and layout spacing are preserved.
Very large text may extend beyond its original area or health bar.

**Selected Nameplate Scale** controls `nameplateSelectedScale` for selected friendly
and enemy nameplates. A value of 1.0 removes the extra selected scaling; distance,
simplified-nameplate, and other game scaling can still affect the visible size.
The client stores this setting per character. MPlate reads the current value on
open and does not overwrite it at login or store a second copy. Unsupported clients
do not show this control. Both reset buttons use the client-provided default;
if that default is unavailable, this setting is skipped. Combat changes are refused
with a message and must be retried after combat; they are not queued. Reset All
continues resetting other options even if this setting cannot be changed.

**Minimum Overhead Name Size** appears below **All Nameplate Text** when the client
supports it. It affects world names globally, not just friendly players; it sets a
minimum size rather than a fixed font size at every distance. A value of 0 adds no
minimum size and does not hide names. This setting does not enable nameplates.

MPlate reads the current game value without changing it when installed or when the
panel opens. The client stores this setting; MPlate does not keep a second copy.
Changes made through game commands or other addons appear the next time the panel
opens. Both its reset button and **Reset All** restore the client-provided default.
If that default cannot be read, this setting is left unchanged and a reset attempt
through **Reset All** reports that it was skipped.

## Requirements

- World of Warcraft Retail 12.1.0 / 12.1.5 (Midnight), or WoW Forever 1.60.1
- The same addon files support both clients and preserve each client's default nameplate layout.

## Compatibility checks

After installing in either client, use `/mplate` to check text size, health bar size,
health text offsets, enemy name width, and border visibility. Check each available
nameplate style, then reset individual options and use **Reset All**. Change bar size
during combat and confirm it applies after combat ends; use `/reload` to confirm
saved settings are restored.

## Publish Command

cd /Users/maginawin/Documents/WOW/MAddOns/AddOns && zip -r ~/Desktop/MPlate.zip MPlate/ -x "*.DS_Store" "MPlate/README.md"
