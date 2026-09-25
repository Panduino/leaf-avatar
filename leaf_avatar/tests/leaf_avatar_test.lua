-- Standalone: luajit mods/leaf_avatar/tests/leaf_avatar_test.lua
-- Asserts the mod's stated effect, not merely that it loads: the sheets
-- register at the shape SpriteRenderer indexes, the back pic is scaled off
-- the 2x player default, and the intro grows a gender step before naming.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

local MOD = "mods/leaf_avatar"
local run = T.sdk.loadMod(MOD, { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

-- ------- the sheets

for _, id in ipairs({ "SPRITE_LEAF", "SPRITE_LEAF_BIKE" }) do
  local sprite = Data.sprites[id]
  T.check(sprite ~= nil, id .. " registered")
  T.eq(sprite.frames, 6, id .. " carries the six frames the renderer indexes")
  T.eq(sprite.walker, true, id .. " is a walker, so walk frames are reachable")
  -- PaletteFX.spriteObp pulls a bracketed index out of paletteSource and
  -- looks it up in the gbc pack's spriteAssignment; a source it cannot
  -- parse leaves the sprite with no ADVANCED palette at all
  T.check(sprite.paletteSource ~= nil,
    id .. " declares an ADVANCED palette source")
  T.check(tostring(sprite.paletteSource):match("%[%d+%]") ~= nil,
    id .. " palette source carries a bracketed sprite index")
end

-- ------- the back pic

-- RedPicBack is 32x32 and the player pic draws at 2x; this pose is 32x52,
-- so without an image-level scale it grows off the top of the shelf.
local scaled
for _, entry in pairs(Data.battle_sprite_scales or {}) do
  if tostring(entry.path):find("leaf_back", 1, true) then scaled = entry.scale end
end
T.check(scaled ~= nil, "the back pic has an image-level scale entry")
T.check(scaled and scaled < 2.0,
  "the back pic is scaled below the 2x player default")

-- ------- the intro question

-- Driven through the loader's own hook chain rather than by requiring
-- OakSpeech: the anchors are what the wrapper keys off, so a stand-in step
-- list carrying the vanilla ids exercises the same path.
local vanillaSteps = {
  { id = "oak_welcome", kind = "say" },
  { id = "ask_player_name", kind = "say" },
  { id = "name_player", kind = "name", presetsFallback = { "RED", "ASH", "JACK" } },
}
local steps = run.loader.hooks:call("intro.oak_speech.build",
  function(s) return s end, vanillaSteps, {})

local pickAt, nameAt
for i, step in ipairs(steps) do
  if step.id == "leaf_avatar_pick" then pickAt = i end
  if step.id == "name_player" then nameAt = i end
end

T.check(pickAt ~= nil, "the gender step was inserted")
T.check(pickAt and nameAt and pickAt < nameAt,
  "the gender step runs before the player is named")
T.eq(steps[pickAt].kind, "choice", "it is a choice step")
T.eq(steps[pickAt].saveKey, "avatar", "it records its answer under 'avatar'")
T.eq(#steps[pickAt].choices, 2, "it offers exactly two answers")
T.eq(steps[pickAt].values[2], "girl", "the second answer is the girl avatar")
T.eq(steps[1].id, "oak_welcome", "the vanilla steps it did not target survived")

-- ------- the back pic footprint (regression, 1.0.2)

-- backPlacement pins the bottom row at y=96 and grows the pic upward, so a
-- taller source pic reaches further into the field.  Red is 32x32 at 2x =
-- 64x64, topping out at y=32; the player must never overshoot that.
local BS = require("src.battle.BattleState")
local BACK = "mods/leaf_avatar/assets/leaf_back.png"
local scale = BS.resolveBattleScale(Data, "back", BACK, nil)
T.check(scale ~= nil and scale <= 2.0, "the back pic never exceeds the 2x default")

local _, top = BS.backPlacement(32, 32, 0, 0, scale)
T.check(top >= 32,
  "the player tops out no higher than Red's back pic (y=" .. tostring(top) .. ")")
T.check(top < 96, "and is still actually on screen")

-- even if the scale override were missed, the 32x32 framing bounds it
local _, fallbackTop = BS.backPlacement(32, 32, 0, 0,
  BS.BATTLE_SCALE_DEFAULT.back)
T.eq(fallbackTop, 32,
  "at the bare 2x default it lands on Red's footprint, not off screen")

-- ------- the intro pictures (regression, 1.0.1)

-- OakSpeech caches playerPic and walkSheet in its constructor, before the
-- player can answer, and resolvePic prefers that cache over the
-- player.sprite hook.  Both the answered path and the forced-option path
-- have to repoint it or the intro shows Red.
local function fakeSpeech()
  return { playerPic = { _path = "vanilla_front" },
           walkSheet = { _path = "vanilla_walk" } }
end
local function vanillaSteps2()
  return { { id = "oak_welcome" }, { id = "ask_player_name" },
           { id = "name_player", presetsFallback = { "RED", "ASH", "JACK" } } }
end

if love and love.graphics and love.graphics.newImage then
  local sp = fakeSpeech()
  sp.steps = run.loader.hooks:call("intro.oak_speech.build",
    function(s) return s end, vanillaSteps2(), sp)
  sp.pic = sp.playerPic
  run.loader.events:emit("intro.oak_speech.answered",
    { saveKey = "avatar", value = "girl", speech = sp })
  T.neq(sp.playerPic._path, "vanilla_front",
    "answering GIRL repoints the cached intro pic")
  T.eq(sp.pic, sp.playerPic,
    "and swaps the pic already on screen, not just the cache")
  T.neq(sp.walkSheet._path, "vanilla_walk",
    "the shrink animation tweens into the female walking sheet")

  -- forced option: the question never runs, so the build hook must dress it
  local forced = fakeSpeech()
  run.loader.modOptions["leaf_avatar"] = { avatar = "girl", tint = "GREEN" }
  local fsteps = run.loader.hooks:call("intro.oak_speech.build",
    function(s) return s end, vanillaSteps2(), forced)
  for _, step in ipairs(fsteps) do
    T.neq(step.id, "leaf_avatar_pick", "a forced avatar skips the question")
  end
  T.neq(forced.playerPic._path, "vanilla_front",
    "a forced girl avatar still dresses the intro")
  run.loader.modOptions["leaf_avatar"] = nil
end

-- ------- the option toggles (regression, 1.1.0)

-- Nothing else re-runs apply(), so without a mod.options_changed subscriber
-- ADV. TINT and BACK SIZE only landed on the next load.  The manager writes
-- the value and then emits; drive it the same way round.
local function setOption(key, value)
  run.loader.modOptions["leaf_avatar"] =
    run.loader.modOptions["leaf_avatar"] or {}
  run.loader.modOptions["leaf_avatar"][key] = value
  run.loader.events:emit("mod.options_changed",
    { mod = "leaf_avatar", key = key, value = value })
end

Data.sprites.SPRITE_RED = Data.sprites.SPRITE_RED
  or { image = "red.png", frames = 6, walker = true }
Data.sprites.SPRITE_RED_BIKE = Data.sprites.SPRITE_RED_BIKE
  or { image = "red_bike.png", frames = 6, walker = true }
setOption("avatar", "girl")
run.loader.events:emit("game.ready", { game = { data = Data } })

local seen = {}
for _, tintName in ipairs({ "RED", "GREEN", "BROWN", "BLUE" }) do
  setOption("tint", tintName)
  local src = Data.sprites.SPRITE_RED.paletteSource
  T.check(src ~= nil, tintName .. " left a palette source on the player sheet")
  T.check(seen[src] == nil,
    tintName .. " resolves to its own sprite index, not a repeat")
  seen[src] = tintName
end

setOption("backsize", "SMALL")
local small = BS.resolveBattleScale(Data, "back", BACK, nil)
setOption("backsize", "LARGE")
local large = BS.resolveBattleScale(Data, "back", BACK, nil)
T.check(small < large, "BACK SIZE changes the scale without a reload")

-- ------- the inter-mod surface

local handle = run.loader.exports["leaf_avatar"]
T.check(type(handle.avatar) == "function", "exports avatar()")
T.check(type(handle.isGirl) == "function", "exports isGirl()")
T.eq(handle.avatar(), "boy", "defaults to the vanilla avatar before any answer")

run.release()

-- ------- interop: the Dramatic Shape voxel renderer
--
-- Its billboard pass textures from SpriteRenderer:resolveImage and meshes
-- per (def.image, frame), so the sheet swap and the tint both reach it with
-- no rebuild.  The two mods share no hook: this one takes
-- intro.oak_speech.build and player.sprite, that one pokemon.sprite,
-- ui.options.rows and world.tod.  Asserted by loading them together rather
-- than by reading its source, and skipped when it is not installed.
local VOXEL = "mods/DRAMATIC_SHAPE"
if love and love.filesystem and love.filesystem.getInfo
   and love.filesystem.getInfo(VOXEL .. "/manifest.json") then
  local both = T.sdk.loadMods({ MOD, VOXEL })
  T.eq(#both.errors, 0,
    "loads alongside the voxel renderer (" .. tostring(both.errors[1]) .. ")")
  local ids = {}
  for id in pairs(both.mods) do ids[id] = true end
  T.check(ids["leaf_avatar"] and ids["DRAMATIC_SHAPE"],
    "both mods survive the merge")
  T.check(both.data.sprites.SPRITE_LEAF ~= nil,
    "the avatar sheets still register with the voxel mod present")

  -- Its staged battle rounds the scale to a whole number
  -- (math.floor(base + 0.5)) so its camera solve holds and the pic is not
  -- resampled twice.  Rounding UP is what inflated MEDIUM's 1.5 into a 2x
  -- player.  With the voxel mod installed this mod must only ever ask for
  -- whole numbers, so what it asks for is what gets drawn.
  local vd = both.data
  vd.sprites.SPRITE_RED = vd.sprites.SPRITE_RED
    or { image = "red.png", frames = 6, walker = true }
  vd.sprites.SPRITE_RED_BIKE = vd.sprites.SPRITE_RED_BIKE
    or { image = "red_bike.png", frames = 6, walker = true }
  both.loader.modOptions["leaf_avatar"] = { avatar = "girl" }
  both.loader.events:emit("game.ready", { game = { data = vd } })

  for _, size in ipairs({ "SMALL", "MEDIUM", "LARGE" }) do
    both.loader.modOptions["leaf_avatar"].backsize = size
    both.loader.events:emit("mod.options_changed",
      { mod = "leaf_avatar", key = "backsize", value = size })
    local ask = BS.resolveBattleScale(vd, "back", BACK, nil)
    T.eq(ask, math.floor(ask),
      size .. " asks the voxel renderer for a whole-number scale")
    -- the renderer's own rule, applied to our ask: it must be a no-op
    T.eq(math.max(1, math.floor(ask + 0.5)), ask,
      size .. " survives the renderer's rounding unchanged")
  end
  both.release()
end

T.finish("leaf_avatar")
