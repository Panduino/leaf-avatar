# Choose Your Avatar

Oak asks whether you are a boy or a girl during his intro, and the answer
dresses the player everywhere the engine draws them. This fork modifies the sprite with Leaf sprites from Spriters Resource, created by OmegaZeez

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
