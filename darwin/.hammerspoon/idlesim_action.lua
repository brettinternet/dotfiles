local idlesim = require("idlesim")
local helpers = require("streamdeck.helpers")

local activeIcon = helpers.svg(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 72"><rect x="7" y="14" width="58" height="44" rx="7" fill="#92400E"/><path d="M17 25h7m6 0h7m6 0h7m6 0h1M17 35h5m6 0h7m6 0h7m6 0h3M17 45h9m6 0h23" stroke="#FEF3C7" stroke-width="5" stroke-linecap="round"/></svg>'
)

local idleIcon = helpers.svg(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 72"><rect x="7" y="14" width="58" height="44" rx="7" fill="#1E293B"/><path d="M17 25h7m6 0h7m6 0h7m6 0h1M17 35h5m6 0h7m6 0h7m6 0h3M17 45h9m6 0h23" stroke="#64748B" stroke-width="5" stroke-linecap="round"/></svg>'
)

return {
  id = "com.brettinternet.hammerspoon.idlesim",
  name = "Simulate activity",

  appearance = function(_context)
    if idlesim.isRunning() then
      return {
        title = "Sim\nactive",
        state = "active",
        appearanceVersion = 1,
        presentationState = 1,
        foregroundColor = "#FEF3C7",
        backgroundColor = "#92400E",
        badge = "SIM",
        icon = activeIcon,
      }
    end

    return {
      title = "Sim\noff",
      state = "inactive",
      appearanceVersion = 1,
      presentationState = 0,
      foregroundColor = "#E2E8F0",
      backgroundColor = "#1E293B",
      badge = "OFF",
      icon = idleIcon,
    }
  end,

  press = function(_context)
    require("idlesim").toggle()
  end,
}
