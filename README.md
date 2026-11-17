# FostercareRaid

One grid for party and raid in World of Warcraft 1.12.1, in place of the party
frames and the game's own group frames.

## Features

- **Click:** left-click targets (or casts the spell on your cursor), right-click
  opens the menu; hovering makes the member your mouseover.
- **Missing health** as text, out-of-range members dimmed, names in class colour.
- **Corners:** red on the member your enemy target attacks, and one for a heal
  over time or a shield.
- **Buffs and debuffs** inside each member: heals and your own first,
  dispellable debuffs first, `+N` for the rest.
- **Sizes:** width, height, scale and gaps, set on its page; a test grid of 40
  sample members to set them by.

Every feature has a switch on its page in AddOn Options; `/fraid` opens it.
Ctrl+Shift moves the grid.

## Requirements

WoW 1.12.1 (build 5875) with **ClassicAPI** loaded.

## Installation

Download `FostercareRaid.zip` from the
[latest release](https://github.com/Fostercare5988/FostercareRaid/releases/latest),
extract it into `Interface/AddOns` and enable it in the game's AddOns list. The
folder must contain `Interface/AddOns/FostercareRaid/FostercareRaid.toc`.
It replaces the party and raid frames of FostercareTweaks before 1.0.0.
