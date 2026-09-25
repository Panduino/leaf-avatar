# Changelog

All notable changes to this mod are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this mod uses
semantic versioning.

## [1.2.0] - 2026-07-31

### Fixed

- The player's back pic stood too tall in a staged battle under the Dramatic
  Shape voxel renderer. That mod replaces `BattleState.resolveBattleScale`
  with one that rounds to a whole number -- its battle camera is solved so a
  pic at its own integer scale exactly fills an overworld square, and a
  fractional ask would be resampled twice. It rounds rather than refuses, so
  `MEDIUM`'s 1.5 was landing on 2 and drawing the player at Red's full
  64x64: bigger than the option said, and not a size anybody picked.

### Changed

- Sizing of the player's back pic is handed to the voxel renderer when it is
  installed. This mod now floors its own ask to a whole number in that case,
  so what the option asks for is exactly what gets drawn. `MEDIUM` goes from
  an effective 64x64 to 32x32 there; `LARGE` still gives Red's 64x64. With
  only whole numbers available `SMALL` and `MEDIUM` are the same rung under
  that mod, which is noted in `mod.card`. Nothing changes without it.

## [1.1.0] - 2026-07-31

### Fixed

- `ADV. TINT` did nothing. The tint is applied in `apply()`, which only ran
  on `game.ready`, `save.loaded`, `save.created` and the intro answer --
  nothing re-ran it when an option changed, so a new tint sat unread until
  the next load. The mod now subscribes to `mod.options_changed`. `BACK SIZE`
  was refreshed by the same call and had the same problem.

### Added

- Verified interoperation with the Dramatic Shape voxel renderer
  (`DRAMATIC_SHAPE` 1.3.0), covered by a test that loads both mods together
  and is skipped when it is not installed.

### Changed

- `priority` lowered from 100 to 90 so this loads before the voxel renderer
  deterministically, rather than relying on an alphabetical tie-break. That
  is the order it documents for sprite-replacing mods.

## [1.0.2] - 2026-07-31

### Changed

- The player stood far too tall in battle. The back pic shipped as the
  source sheet's full 32x52 figure, but `RedPicBack` is 32x32 cropped at the
  waist, and `backPlacement` pins the bottom row at y=96 and grows the pic
  upward -- so every extra source row reached further into the field. The pic
  is recropped to the vanilla 32x32 waist-up framing, which also bounds it
  correctly if the scale override is ever missed: at the 2x default it lands
  on Red's exact footprint instead of running off the top of the screen.

### Added

- A `BACK SIZE` option: `SMALL` (40x40), `MEDIUM` (48x48, the new default)
  and `LARGE` (64x64, Red's footprint). `apply()` refreshes the scale record
  that `BattleState.imageBattleScale` reads at draw time, so the option lands
  on the next battle without a reload.

## [1.0.1] - 2026-07-31

### Fixed

- The intro showed Red's picture instead of the chosen avatar. `OakSpeech`
  resolves `playerPic` and `walkSheet` in its constructor, which runs before
  `buildSteps` and long before the player can answer, and `resolvePic`
  returns that cached image ahead of anything the `player.sprite` hook says.
  Both the answered path and the forced-option path now repoint the cache,
  so the shrink animation tweens into the right walking sheet too.
- The battle back pic drew inside a white box. Every asset wrote colour 0 as
  opaque white; vanilla keys it to alpha instead — sprite sheets fully
  (`decode2bpp` with `transparent`), pics by border flood fill
  (`ImageWriter.matteColor0`). All seven assets are rebuilt preserving the
  source sheet's own transparency, which satisfies both conventions.

## [1.0.0] - 2026-07-31

### Added

- A `BOY` / `GIRL` step in Oak's speech, anchored before `ask_player_name`
  through the `intro.oak_speech.build` hook.
- `SPRITE_LEAF` and `SPRITE_LEAF_BIKE`: six-frame 16x96 walking and cycling
  sheets in the four DMG shades.
- A 56x56 front pic and a 32x52 battle back pic, resolved per save through
  the `player.sprite` hook, with a `battle_sprite_scales` entry keeping the
  back pic on the vanilla footprint.
- Three 16x8 fishing pose tiles.
- `AVATAR` and `ADV. TINT` options.
- `mod.exports.avatar()` and `mod.exports.isGirl()` for dependent mods.
