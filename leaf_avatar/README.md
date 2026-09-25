# Choose Your Avatar

Oak asks whether you are a boy or a girl during his intro, and the answer
dresses the player everywhere the engine draws them.

```sh
cp -r leaf_avatar <your gen1recomp checkout>/mods/
python3 tools/modkit.py validate mods/leaf_avatar --base imported
love .
```

Start a new game and answer Oak. The walking and cycling sheets swap the
moment you answer; the battle back pic and the front pic on the trainer card
and in the Hall of Fame follow the same choice.

## Options

| Option | Default | What it does |
| --- | --- | --- |
| `AVATAR` | `ASK AT START` | Force `BOY` or `GIRL` to skip Oak's question entirely. A forced value also fixes the fishing poses from boot. |
| `BACK SIZE` | `MEDIUM` | How large the player stands in battle: `SMALL` 40x40, `MEDIUM` 48x48, `LARGE` 64x64 (Red's exact footprint). Takes effect on the next battle. With the voxel renderer installed, see below. |
| `ADV. TINT` | `BLUE` | Which pokered-gbc object palette the avatar wears under the ADVANCED colour mode: `BLUE`, `RED`, `GREEN` or `BROWN`. |

All three take effect immediately -- the mod re-applies them off
`mod.options_changed` rather than waiting for a reload.

## Colour

The art ships in the four DMG shades, not in baked colour. That is what lets
every `COLORS` mode light it: the SGB zone shader, ADVANCED's per-sprite OBJ
palette, OG RED's boot-ROM object palette and the mono novelties all colour a
shaded sheet and would fight a pre-coloured one.

Under **ADVANCED** an overworld sprite's palette comes from its
`paletteSource`, which resolves through the pokered-gbc pack's
`spriteAssignment` table to one of eight `SPR_PAL_*` groups. There is no
purple group and a mod cannot add one, so `ADV. TINT` picks the nearest —
blue by default, which also keeps the avatar visually distinct from
`SPRITE_RED`. Every other colour mode is unaffected.

## What it changes

Read `mod.card` for the full tri-ledger, including the rough edges. The short
version: the intro gains one step, the name presets change with the answer,
and the two player sprite records are repointed while the girl avatar is live.

## Art provenance

The pixel art is resliced from a fan reference sheet supplied by the player,
of unattributed authorship. It contains no ROM-derived bytes. If you know who
made the original sheet, credit them in `mod.card` before redistributing.
