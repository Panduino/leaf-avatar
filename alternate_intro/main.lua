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
    },
    CHARMANDER = {
      rival = "SQUIRTLE",
      flag = "EVENT_CHOSE_CHARMANDER",
    },
    SQUIRTLE = {
      rival = "BULBASAUR",
      flag = "EVENT_CHOSE_SQUIRTLE",
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

    -- These are the milestones the normal Oak's Lab/Pokédex sequence would
    -- establish before the player is allowed to leave the early game.
    flags.EVENT_GOT_POKEDEX = true
  end

  local function speciesName(game, species)
    local def = game.data.pokemon and game.data.pokemon[species]
    return (def and def.name) or species
  end

  local function receiveStarter(speech, done)
    local game = speech.game
    local species = mod.save:get("starter")

    if not STARTERS[species] then
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

    local img, flip, trueColor = require("src.ui.OakSpeech").resolvePic(
      game, { type = "pokemon", id = species }, speech
    )
    speech.pic = img
    speech.picFlip = flip or false
    speech.picTrueColor = trueColor or false

    local Sound = require("src.core.Sound")
    Sound.playCry(game.data, species)

    local TextBox = require("src.render.TextBox")
    local NamingScreen = require("src.ui.NamingScreen")
    local mon = game.save.party and game.save.party[1]

    -- This uses the same received-mon text as the normal Oak's Lab gift.
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

    -- The player already has a name by this point. Keeping the normal
    -- world explanation and player-name sequence makes this feel like the
    -- same intro, just with the Oak's Lab detour removed.
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

    -- Remove the demo transition only if the starter has already been
    -- selected in a resumed/custom intro. The normal first-time path keeps
    -- Oak's NIDORINO demonstration and world explanation intact.
    return steps
  end)

  mod.events:on("intro.oak_speech.answered", function(ev)
    if ev.saveKey ~= "starter" then return end

    local species = ev.value
    if not STARTERS[species] then return end

    mod.save:set("starter", species)

    -- The next step will use this preview through OakSpeech's normal
    -- Pokemon.Sprites resolver. This means sprite replacements from the game
    -- data or other compatible mods are automatically respected.
    for _, step in ipairs(ev.speech.steps or {}) do
      if step.id == "alternate_intro_starter_choice" then
        step.pic = "oak"
      elseif step.id == "alternate_intro_receive_starter" then
        step.pic = { type = "pokemon", id = species }
      end
    end
  end)

  -- The vanilla intro already asks for the rival's name. Put Oak's usual
  -- Pokédex explanation immediately after that name is confirmed, which
  -- replaces the later Parcel -> Lab -> Pokédex sequence.
  mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
    steps = next(steps, speech)

    -- This wrapper is intentionally a no-op when another wrapper has already
    -- inserted the Pokedex block. It exists separately so its ordering remains
    -- predictable when companion mods also reshape Oak's speech.
    local already = false
    for _, step in ipairs(steps) do
      if step.id == "alternate_intro_pokedex" then
        already = true
        break
      end
    end
    if already then return steps end

    local insertAt = nil
    for i, step in ipairs(steps) do
      if step.id == "confirm_rival_name" then
        insertAt = i + 1
        break
      end
    end

    if not insertAt then return steps end

    table.insert(steps, insertAt, {
      id = "alternate_intro_pokedex",
      kind = "say",
      pic = "oak",
      textKey = "_OaksLabOakMyInventionPokedexText",
      fadeOut = true,
    })

    table.insert(steps, insertAt + 1, {
      id = "alternate_intro_pokedex_to_player",
      kind = "say",
      pic = "oak",
      text = "{PLAYER} and {RIVAL}!\nTake these with you.\fYour rival has been given\na Pokédex as well.",
    })

    table.insert(steps, insertAt + 2, {
      id = "alternate_intro_pokedex_done",
      kind = "fn",
      run = function(stepSpeech, done)
        stepSpeech.game.save.flags.EVENT_GOT_POKEDEX = true
        stepSpeech.game.save.flags.EVENT_GOT_STARTER = true
        done()
      end,
    })

    return steps
  end)
end
