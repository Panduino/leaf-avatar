-- Choose Your Avatar.  Oak asks whether you are a boy or a girl, and the
-- answer dresses the player everywhere the engine draws them: the walking
-- and cycling sheets, the battle back pic, and the front pic the intro,
-- the trainer card and the Hall of Fame share.
--
-- The art ships in the four DMG shades rather than in baked colour, which
-- is what lets every COLORS mode light it: the SGB zone shader, ADVANCED's
-- per-sprite OBJ palette, OG RED's boot-ROM object palette and the mono
-- novelties all colour a shaded sheet and would fight a pre-coloured one.

local WALK  = "assets/leaf_walk.png"
local BIKE  = "assets/leaf_bike.png"
local FRONT = "assets/leaf_front.png"
local BACK  = "assets/leaf_back.png"
local FISH  = {
  redFishFront = "assets/leaf_fish_front.png",
  redFishBack  = "assets/leaf_fish_back.png",
  redFishSide  = "assets/leaf_fish_side.png",
}

-- ADVANCED (the `redpp` COLORS mode) resolves an overworld sprite's OBJ
-- palette through PaletteFX.spriteObp, which reads the sprite's
-- `paletteSource`, pulls the bracketed index out of it and looks that index
-- up in the pokered-gbc pack's spriteAssignment table.  That lands on one of
-- eight SPR_PAL_* groups.  These four indices are the ones whose assignment
-- is a fixed group rather than the "random" sentinel, named here by the
-- colour the group actually carries.
--
-- The pack has no purple group, so the lilac and violet reference palettes
-- cannot be reproduced literally under ADVANCED; BLUE is the nearest, and is
-- the default so the avatar reads as distinct from SPRITE_RED's red.
local TINT = {
  BLUE  = "ROM:SpriteSheetPointerTable[1]",   -- group 1  { 82,  74, 255 }
  RED   = "ROM:SpriteSheetPointerTable[0]",   -- group 0  { 255, 58,   8 }
  GREEN = "ROM:SpriteSheetPointerTable[21]",  -- group 2  { 58, 189,  25 }
  BROWN = "ROM:SpriteSheetPointerTable[2]",   -- group 3  { 123, 82,  25 }
}

-- The back pic is 32x32 like RedPicBack, so the vanilla 2x default would
-- draw it at Red's exact 64x64 footprint.  backPlacement pins the bottom row
-- at y=96 and grows the pic upward, so the scale is the whole story for how
-- far into the field the player reaches.  LARGE is that vanilla footprint;
-- the default sits below it because the pose is a fuller figure than Red's
-- shoulders and reads bigger at the same height.
local BACK_SCALE = { SMALL = 1.25, MEDIUM = 1.5, LARGE = 2.0 }

local GIRL_PRESETS = { "LEAF", "GREEN", "DAISY" }

return function(mod)
  mod.options:define({
    { key = "avatar", label = "AVATAR", type = "choice", default = "ask",
      choices = { { "ASK AT START", "ask" }, { "BOY", "boy" }, { "GIRL", "girl" } } },
    { key = "backsize", label = "BACK SIZE", type = "choice", default = "MEDIUM",
      choices = { { "SMALL", "SMALL" }, { "MEDIUM", "MEDIUM" },
                  { "LARGE", "LARGE" } } },
    { key = "tint", label = "ADV. TINT", type = "choice", default = "BLUE",
      choices = { { "BLUE", "BLUE" }, { "RED", "RED" },
                  { "GREEN", "GREEN" }, { "BROWN", "BROWN" } } },
  })

  -- forward declarations: the intro handler below calls apply(), which is
  -- defined further down once the merged sprite records are in reach
  local game, vanilla, apply

  local function asset(relative) return mod.assets:path(relative) end
  local function tint() return TINT[mod.options:get("tint")] or TINT.BLUE end
  -- The Dramatic Shape voxel renderer replaces BattleState.resolveBattleScale
  -- with one that rounds the answer to a whole number, because its battle
  -- camera is solved so a pic at its own integer scale exactly fills one
  -- overworld square -- a fractional ask would be resampled twice on the way
  -- to the screen and a twice-resampled Gen 1 pic is mush.  It rounds rather
  -- than refuses, so MEDIUM's 1.5 was landing on 2 and the player stood at
  -- Red's full 64x64 in a staged battle: bigger than the option said, and not
  -- a size anybody chose.
  --
  -- So when it is installed the sizing is its call, and this only ever hands
  -- it whole numbers -- floored, never rounded, since rounding up is the bug.
  -- What the option asks for is then exactly what gets drawn.
  local function voxelInstalled()
    local ok, handle = pcall(mod.find, "DRAMATIC_SHAPE")
    return ok and handle ~= nil
  end

  local function backScale()
    local s = BACK_SCALE[mod.options:get("backsize")] or BACK_SCALE.MEDIUM
    if voxelInstalled() then return math.max(1, math.floor(s)) end
    return s
  end

  -- ------- content

  -- Registered under ids of their own so the sheets are addressable by other
  -- mods and by field.playerSprites, even though the live swap below works
  -- by repointing SPRITE_RED's image rather than by changing the id.
  mod.content.sprites:register("SPRITE_LEAF", {
    image = asset(WALK), frames = 6, walker = true, paletteSource = tint(),
  })
  mod.content.sprites:register("SPRITE_LEAF_BIKE", {
    image = asset(BIKE), frames = 6, walker = true, paletteSource = tint(),
  })

  -- An image-level entry is the only way to scale a pic that is not
  -- species-keyed, which the trainer back is.  apply() refreshes the scale
  -- from the option afterwards, so BACK SIZE takes effect without a reload.
  mod.content.battle_sprite_scales:register("leaf_back", {
    path = asset(BACK), scale = backScale(),
  })

  -- ------- which avatar is live

  -- "ask" defers to whatever the intro recorded; a forced option wins, so a
  -- player who never wants the question can skip it.
  local function chosen()
    local forced = mod.options:get("avatar")
    if forced == "boy" or forced == "girl" then return forced end
    return mod.save:get("avatar", "boy")
  end
  local function isGirl() return chosen() == "girl" end

  -- ------- dressing the intro

  -- OakSpeech resolves playerPic and walkSheet in its constructor, which runs
  -- before buildSteps and long before the player could answer, and
  -- resolvePic returns that cached image ahead of anything the player.sprite
  -- hook would say.  Repointing the cache is what makes "here is you" show
  -- the right trainer -- including the shrink animation, which tweens the pic
  -- into the walking sheet's first frame and would otherwise land on Red.
  local function dressSpeech(speech)
    if not speech then return end
    for _, step in ipairs(speech.steps or {}) do
      if step.id == "name_player" then
        step.presetsFallback = GIRL_PRESETS
        step.presetsWho = nil
      end
    end
    local ok, front = pcall(function() return mod.assets:image(FRONT) end)
    if ok and front then
      local stale = speech.playerPic
      speech.playerPic = front
      speech.playerTrueColor = false
      -- if that pic is on screen this instant, swap what is drawn too
      if speech.pic == stale then
        speech.pic = front
        speech.picTrueColor = false
      end
    else
      mod.log:warn("could not load the front pic for the intro; "
        .. "keeping the vanilla trainer picture")
    end
    local okWalk, walk = pcall(function() return mod.assets:image(WALK) end)
    if okWalk and walk then speech.walkSheet = walk end
  end

  -- ------- the intro question

  mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
    steps = next(steps, speech)
    if mod.options:get("avatar") ~= "ask" then
      -- the question is skipped, so nothing will fire the answered event:
      -- dress the speech now if the forced avatar is the girl
      if isGirl() then
        speech.steps = steps
        dressSpeech(speech)
      end
      return steps
    end
    mod.ui.insertStepBefore(steps, "ask_player_name", {
      id = "leaf_avatar_pick",
      kind = "choice",
      text = "Now tell me...\nAre you a boy?\nOr are you a girl?",
      saveKey = "avatar",
      choices = { "BOY", "GIRL" },
      values = { "boy", "girl" },
      tx = 6, ty = 4, tw = 7,
    })
    return steps
  end)

  -- Record the answer, then re-point the name presets in the same pass the
  -- next step reads them from.
  mod.events:on("intro.oak_speech.answered", function(ev)
    if ev.saveKey ~= "avatar" then return end
    mod.save:set("avatar", ev.value)
    if ev.value == "girl" then dressSpeech(ev.speech) end
    apply()
  end)

  -- ------- the pics
  -- player.sprite is the sanctioned per-save seam: content freezes after
  -- load, but this hook stays live for the whole process, so the pic can
  -- follow a choice the player makes mid-session.  The catch tutorial's old
  -- man still fights in the player's place, so `demo` is left alone.

  mod.hooks:wrap("player.sprite", function(next, path, ctx)
    path = next(path, ctx)
    if not isGirl() or ctx.demo then return path end
    if ctx.side == "back" then return asset(BACK) end
    return asset(FRONT)
  end)

  -- ------- the overworld sheets
  -- SpriteRenderer re-reads def.image every frame on the shaded path, so
  -- repointing the merged SPRITE_RED record swaps the walker live without
  -- rebuilding the Player -- which matters because the overworld state is
  -- pushed before both the intro and save.loaded, so its Player already
  -- exists by the time either one could tell us the answer.

  local function remember(def)
    if def and vanilla[def] == nil then
      vanilla[def] = { image = def.image, paletteSource = def.paletteSource }
    end
  end

  apply = function()
    if not game or not game.data or not game.data.sprites then return end
    vanilla = vanilla or {}
    -- BattleState.imageBattleScale reads this table at draw time and matches
    -- on the path, so refreshing the record here is enough for the option to
    -- land on the next battle without a reload
    local scales = game.data.battle_sprite_scales
    local record = scales and scales.leaf_back
    if record then record.scale = backScale() end
    local sprites = game.data.sprites
    local pairsOf = {
      { def = sprites.SPRITE_RED,      image = asset(WALK) },
      { def = sprites.SPRITE_RED_BIKE, image = asset(BIKE) },
    }
    for _, row in ipairs(pairsOf) do
      local def = row.def
      if not def then
        mod.log:warn("SPRITE_RED / SPRITE_RED_BIKE missing from the merged "
          .. "view -- import your ROM first; overworld swap skipped")
      else
        remember(def)
        if isGirl() then
          def.image = row.image
          def.paletteSource = tint()
        else
          def.image = vanilla[def].image
          def.paletteSource = vanilla[def].paletteSource
        end
      end
    end
  end

  mod.events:on("game.ready", function(ev)
    game = ev.game
    vanilla = vanilla or {}
    -- The fishing poses are the one piece the live swap cannot reach: the
    -- Player caches their paths when it is constructed, and reaching into
    -- OverworldState to refresh them is unsupported.  Patching the field
    -- data here means a forced AVATAR option is correct from boot, and a
    -- choice made at the intro catches up on the next load.
    local fx = game.data and game.data.field and game.data.field.overworldFx
    if fx and isGirl() then
      for key, relative in pairs(FISH) do
        if fx[key] then fx[key].path = asset(relative) end
      end
    end
    apply()
  end)

  mod.events:on("save.loaded", function() apply() end)
  mod.events:on("save.created", function() apply() end)

  -- The options manager writes the value and emits this; nothing else re-runs
  -- apply(), so without it ADV. TINT and BACK SIZE only took effect on the
  -- next load.  SpriteRenderer:resolveImage re-reads paletteSource off the
  -- def every frame and getObpImage caches per (path, group), so a new tint
  -- rebuilds the recoloured sheet on the spot -- including under a render
  -- pipeline that textures from resolveImage.
  mod.events:on("mod.options_changed", function(ev)
    if not (ev and ev.mod == mod.id) then return end
    apply()
  end)

  -- ------- inter-mod surface

  mod.exports.avatar = function() return chosen() end
  mod.exports.isGirl = isGirl
end
