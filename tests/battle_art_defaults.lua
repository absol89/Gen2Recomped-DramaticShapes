local settings = {}
local V = {
  require = function(name)
    if name == "ModSetting" then
      return { new = function(key, label, values, labels)
        local setting = { key = key, label = label,
                          values = values, labels = labels }
        settings[key] = setting
        return setting
      end }
    end
    error(name)
  end,
  data = function() return {} end,
}

assert(loadfile("lib/BattleArt.lua"))(V)
assert(settings.battleArt.values[1] == "animated"
  and settings.battleArt.labels[1] == "ANIMATED",
  "fresh installs do not default Battle Art to animated")
assert(settings.battleArt.values[2] == "static"
  and settings.battleArt.values[3] == "rom",
  "Battle Art retained an unexpected mode ladder")
assert(settings.trainerArtSet.values[1] == "rom"
  and settings.trainerArtSet.labels[1] == "ROM",
  "fresh installs do not default opponent trainer art to ROM")

print("battle-art defaults regression: ok")
