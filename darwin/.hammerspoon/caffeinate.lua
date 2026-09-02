local caffeine = require("caffeine")
local helpers = require("streamdeck.helpers")

local function loadIcon(name, color)
  local file = assert(io.open(hs.configdir .. "/icons/lucide/" .. name .. ".svg", "r"))
  local svg = file:read("*a")
  file:close()
  return helpers.svg((svg:gsub("currentColor", color)))
end

local displayAwakeIcon = loadIcon("monitor-up", "#D1FAE5")
local displayOnlyAwakeIcon = loadIcon("monitor-up", "#FEF3C7")
local allowSleepIcon = loadIcon("moon", "#E2E8F0")
local systemAwakeIcon = loadIcon("coffee", "#DBEAFE")

return {
  id = "com.brettinternet.hammerspoon.caffeinate",
  name = "Keep awake",

  appearance = function(_context)
    local displayIdleEnabled = caffeine.isEnabled()
    local systemIdleEnabled = caffeine.isSystemIdleEnabled()

    if displayIdleEnabled and not systemIdleEnabled then
      return {
        title = "",
        state = "active",
        appearanceVersion = 1,
        presentationState = 2,
        foregroundColor = "#FEF3C7",
        backgroundColor = "#92400E",
        icon = displayOnlyAwakeIcon,
      }
    end

    if displayIdleEnabled then
      return {
        title = "",
        state = "active",
        appearanceVersion = 1,
        presentationState = 2,
        foregroundColor = "#D1FAE5",
        backgroundColor = "#064E3B",
        icon = displayAwakeIcon,
      }
    end

    if systemIdleEnabled then
      return {
        title = "",
        state = "active",
        appearanceVersion = 1,
        presentationState = 1,
        foregroundColor = "#DBEAFE",
        backgroundColor = "#1E3A8A",
        icon = systemAwakeIcon,
      }
    end

    return {
      title = "",
      state = "inactive",
      appearanceVersion = 1,
      presentationState = 0,
      foregroundColor = "#E2E8F0",
      backgroundColor = "#1E293B",
      icon = allowSleepIcon,
    }
  end,

  press = function(_context)
    if caffeine.isEnabled() then
      caffeine.setLifecycleState(false, false)
    elseif caffeine.isSystemIdleEnabled() then
      caffeine.setLifecycleState(true, true, true)
    else
      caffeine.setLifecycleState(false, true)
    end
  end,
}
