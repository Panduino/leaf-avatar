-- Alternate Oak intro:
-- choose Bulbasaur, Charmander or Squirtle during Oak's opening speech,
-- immediately receive it (with the normal gift/Pokédex bookkeeping),
-- choose a nickname, name the rival, then receive the Pokédex explanation.
--
-- No starter artwork is bundled here. The preview uses OakSpeech's normal
-- Pokémon sprite resolver, which follows the imported game data and the same
-- sprite override path used by compatible mods.

return function(mod)
  if mod.generation ~= 1 then
    mod.log:warn("Alternate Oak Intro is intended for the Gen 1 three-starter flow")
    return
  end

  local GameVersion = require("src.core.GameVersion")
  if GameVersion.isYellow() then
    mod.log:warn("Alternate Oak Intro is disabled for Pokémon Yellow")
    return
  end

  local STARTERS = {
    BULBASAUR = {
      rival = "CHARMANDER",
      flag = "EVENT_CHOSE_BULBASAUR",
      index = 1,
    },
    CHARMANDER = {
      rival = "SQUIRTLE",
      flag = "EVENT_CHOSE_CHARMANDER",
      index = 2,
    },
    SQUIRTLE = {
      rival = "BULBASAUR",
      flag = "EVENT_CHOSE_SQUIRTLE",
      index = 3,
    },
  }

  local function setStarterFlags(game, species)
    local info = STARTERS[species]
    if not info then return end

    local flags = game.save.flags
    flags.EVENT_GOT_STARTER = true
    flags.EVENT_CHOSE_BULBASAUR = nil
    flags.EVENT_CHOSE_CHARMANDER = nil
    flags.EVENT_CHOSE_SQUIRTLE = nil
    flags[info.flag] = true

    -- These milestones normally happen during the Parcel -> Lab sequence.
    -- Marking both parcel flags complete prevents the vanilla story gate from
    -- sending the player back to Viridian for a delivery we have skipped.
    flags.EVENT_GOT_POKEDEX = true
    flags.EVENT_OAK_GOT_PARCEL = true
    flags.EVENT_GOT_OAKS_PARCEL = true

    -- The original Gen 1 save stores the starter pair as 1/2/3 as well.
    -- The live Red/Blue party scripts use the chose-* flags, but keeping these
    -- fields synchronized helps save/interop code that reads the starter byte.
    game.save.playerStarter = info.index
    game.save.rivalStarter = STARTERS[info.rival].index
  end

  local function speciesName(game, species)
    local def = game.data.pokemon and game.data.pokemon[species]
    return (def and def.name) or species
  end

  local function receiveStarter(speech, done)
    local game = speech.game
    local species = mod.save:get("starter")
    local info = STARTERS[species]

    if not info then
      done()
      return
    end

    -- Use the engine's ordinary gift path. This stamps the OT, adds the
    -- Pokémon to the party, marks it seen/owned in the Pokédex, and emits
    -- pokemon.before_give so other mods can participate in the gift.
    local Commands = require("src.script.Commands")
    local ctx = {
      game = game,
      save = game.save,
      overworld = game.overworld,
    }
    Commands.give_pokemon(ctx, species, 5, true)
    setStarterFlags(game, species)

    -- This is the normal front/battle/Pokédex sprite resolver. It is
    -- deliberately not an asset shipped by this mod, so imported sprites and
    -- compatible sprite-replacement mods remain authoritative.
    local OakSpeech = require("src.ui.OakSpeech")
    local img, flip, trueColor = OakSpeech.resolvePic(
      game, { type = "pokemon", id = species }, speech
    )
    speech.pic = img
    speech.picFlip = flip or false
    speech.picTrueColor = trueColor or false

    require("src.core.Sound").playCry(game.data, species)

    local TextBox = require("src.render.TextBox")
    local NamingScreen = require("src.ui.NamingScreen")
    local mon = game.save.party and game.save.party[1]

    -- Use the same received-mon text as the normal Oak's Lab starter gift.
    game.stack:push(TextBox.new(
      game,
      game.data.text and game.data.text._OaksLabReceivedMonText
        or ("You received " .. speciesName(game, species) .. "!"),
      function()
        local prompt = ("Would you like to give\nyour %s a nickname?")
          :format(speciesName(game, species))

        game.stack:push(TextBox.new(game, prompt, nil, {
          choice = function(yes)
            if not yes then
              done()
              return
            end

            game.stack:push(NamingScreen.new(game, {
              title = require("src.core.Strings")("NICKNAME?"),
              maxLen = 10,
              mon = mon,
              onDone = function(name)
                if name and #name > 0 and mon then
                  mon.nickname = name
                end
                done()
              end,
            }))
          end,
        }))
      end
    ))
  end

  mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
    steps = next(steps, speech)

    -- The player already has a name by this point. Keeping the normal world
    -- explanation and player-name sequence makes this feel like the same
    -- intro, just with the Oak's Lab detour removed.
    mod.ui.insertStepAfter(steps, "confirm_player_name", {
      id = "alternate_intro_starter_choice",
      kind = "choice",
      pic = "oak",
      saveKey = "starter",
      text = "Before you leave,\nyou should have a\nPOKéMON of your own!\fChoose one.",
      choices = { "BULBASAUR", "CHARMANDER", "SQUIRTLE" },
      values = { "BULBASAUR", "CHARMANDER", "SQUIRTLE" },
      tx = 4,
      ty = 4,
      tw = 12,
    })

    mod.ui.insertStepAfter(steps, "alternate_intro_starter_choice", {
      id = "alternate_intro_receive_starter",
      kind = "fn",
      run = receiveStarter,
    })

    return steps
  end)

  mod.events:on("intro.oak_speech.answered", function(ev)
    if ev.saveKey ~= "starter" then return end

    local species = ev.value
    if not STARTERS[species] then return end

    mod.save:set("starter", species)

    -- Keep the step's descriptor tied to the selected species. The actual
    -- image is still resolved by OakSpeech at draw time from game data.
    for _, step in ipairs(ev.speech.steps or {}) do
      if step.id == "alternate_intro_receive_starter" then
        step.pic = { type = "pokemon", id = species }
      end
    end
  end)

  -- The alternate intro supplies the Poké Balls at home instead of Oak's Lab.
  -- Vanilla Red/Blue puts Mom at (5,4) on REDS_HOUSE_1F. When the player walks
  -- down to (5,6), Mom walks down one tile, speaks, gives ten POKE BALLs, and
  -- walks back to her seat. The scene is one-shot and only runs after the
  -- alternate intro has actually given the starter.
  mod.content.map_scripts:register("REDS_HOUSE_1F", {
    onStep = function(game, ow, x, y)
      local flags = game.save.flags or {}
      if flags.MOD_ALTERNATE_INTRO_MOM_GIFT then return false end
      if not mod.save:get("starter") or not flags.EVENT_GOT_STARTER then
        return false
      end
      if x ~= 5 or y ~= 6 then return false end

      local rows = {
        { "move_npc", 1, "down", 1 },
        { "face_player" },
        { "show_text",
          "Right. All kids leave home\nsomeday. It said so on TV." },
        { "show_text",
          "I've packed some fresh\nunderwear for you, too.\fYou'll need to be prepared\nfor your journey!" },
        { "give_item", "POKE_BALL", 10, false },
        { "show_text",
          "{PLAYER} got 10 POKé BALLs!\fUse them to catch\nWILD POKéMON!" },
        { "move_npc", 1, "up", 1 },
        { "set_flag", "MOD_ALTERNATE_INTRO_MOM_GIFT" },
      }

      ow.runner:run(rows, { npc = mod.world:npc("REDS_HOUSE_1F", 1) })
      return true
    end,
  })

  -- Put Oak's usual Pokédex explanation immediately after the rival's name is
  -- confirmed. This is the point at which the alternate intro replaces the
  -- later Parcel -> Lab -> Pokédex sequence.
  mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
    steps = next(steps, speech)

    for _, step in ipairs(steps) do
      if step.id == "alternate_intro_pokedex" then
        return steps
      end
    end

    local insertAt
    for i, step in ipairs(steps) do
      if step.id == "confirm_rival_name" then
        insertAt = i + 1
        break
      end
    end
    if not insertAt then return steps end

    table.insert(steps, insertAt, {
      id = "alternate_intro_pokedex_request",
      kind = "say",
      pic = "oak",
      textKey = "_OaksLabOakIHaveARequestText",
    })

    table.insert(steps, insertAt + 1, {
      id = "alternate_intro_pokedex",
      kind = "say",
      pic = "oak",
      textKey = "_OaksLabOakMyInventionPokedexText",
    })

    table.insert(steps, insertAt + 2, {
      id = "alternate_intro_pokedex_given",
      kind = "say",
      pic = "oak",
      textKey = "_OaksLabOakGotPokedexText",
    })

    table.insert(steps, insertAt + 3, {
      id = "alternate_intro_pokedex_dream",
      kind = "say",
      pic = "oak",
      textKey = "_OaksLabOakThatWasMyDreamText",
    })

    table.insert(steps, insertAt + 4, {
      id = "alternate_intro_pokedex_rival",
      kind = "say",
      pic = "oak",
      text = "{PLAYER} and {RIVAL}!\nTake these with you.\fYour rival has been given\na Pokédex as well.",
    })

    table.insert(steps, insertAt + 5, {
      id = "alternate_intro_pokedex_done",
      kind = "fn",
      run = function(stepSpeech, done)
        stepSpeech.game.save.flags.EVENT_GOT_POKEDEX = true
        stepSpeech.game.save.flags.EVENT_OAK_GOT_PARCEL = true
        stepSpeech.game.save.flags.EVENT_GOT_OAKS_PARCEL = true
        done()
      end,
    })

    return steps
  end)
end
