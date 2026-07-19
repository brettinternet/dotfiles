local caffeine = require("caffeine")

return {
  id = "com.brettinternet.hammerspoon.caffeine-alert",
  name = "Caffeine alert",

  appearance = function(_context)
    if caffeine.isOverrideActive() then
      return {
        title = "Dismiss\nalert",
        state = "active",
        appearanceVersion = 1,
        foregroundColor = "#FEF3C7",
        backgroundColor = "#92400E",
        badge = "ON",
      }
    end

    return {
      title = "No\nalert",
      state = "inactive",
      appearanceVersion = 1,
      foregroundColor = "#CBD5E1",
      backgroundColor = "#1E293B",
      badge = "OFF",
    }
  end,

  press = function(_context)
    caffeine.dismissOverride()
  end,
}
