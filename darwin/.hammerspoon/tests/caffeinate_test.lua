local module_path = (arg[0]:match("(.*/)") or "") .. "../?.lua"
package.path = module_path .. ";" .. package.path

local function assert_equal(actual, expected, message)
  assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local idle = {
  displayIdle = false,
  systemIdle = false,
}

local batteryPercentage
local failDisplayToggle = false

_G.hs = {
  configdir = (arg[0]:match("(.*/)") or "") .. "..",
  image = {
    imageFromPath = function(path)
      return {
        path = path,
        size = function(self)
          return self
        end,
      }
    end,
  },
  battery = {
    percentage = function()
      return batteryPercentage
    end,
  },
  caffeinate = {
    get = function(kind)
      return idle[kind]
    end,
    toggle = function(kind)
      if kind == "displayIdle" and failDisplayToggle then
        return idle[kind]
      end
      idle[kind] = not idle[kind]
      return idle[kind]
    end,
  },
  screen = {
    allScreens = function()
      return { {} }
    end,
  },
  alert = {
    closeSpecific = function() end,
    show = function()
      return {}
    end,
  },
}

package.preload["streamdeck.helpers"] = function()
  return {
    svg = function(value)
      return value
    end,
  }
end

local caffeine = require("caffeine")
local action = require("caffeinate")

local notification_count = 0
caffeine.subscribe(function()
  notification_count = notification_count + 1
end)

caffeine.toggleSystemIdle()
assert_equal(notification_count, 1, "system idle changes should notify Stream Deck subscribers")
assert_equal(idle.systemIdle, true, "system idle prevention should be enabled")
idle.systemIdle = false

local sleep_appearance = action.appearance({})
assert_equal(sleep_appearance.title, "", "sleep state should use only its icon")
assert_equal(sleep_appearance.state, "inactive", "sleep state")
assert_equal(sleep_appearance.presentationState, 0, "sleep presentation state")

action.press({})
assert_equal(idle.displayIdle, false, "first press should allow displays to sleep")
assert_equal(idle.systemIdle, true, "first press should prevent system idle sleep")

local system_appearance = action.appearance({})
assert_equal(system_appearance.title, "", "system-awake state should use only its icon")
assert_equal(system_appearance.state, "active", "system-awake state")
assert_equal(system_appearance.presentationState, 1, "system-awake presentation state")
assert(system_appearance.icon ~= sleep_appearance.icon, "system-awake and sleep states should use distinct icons")
action.press({})
assert_equal(idle.displayIdle, true, "second press should prevent display idle sleep")
assert_equal(idle.systemIdle, true, "second press should retain system idle prevention")

local awake_appearance = action.appearance({})
assert_equal(awake_appearance.title, "", "display-awake state should use only its icon")
assert_equal(awake_appearance.state, "active", "awake state")
assert_equal(awake_appearance.presentationState, 2, "display-awake presentation state")
assert(awake_appearance.icon ~= system_appearance.icon, "display- and system-awake states should use distinct icons")

action.press({})
assert_equal(idle.displayIdle, false, "third press should allow displays to sleep")
assert_equal(idle.systemIdle, false, "third press should allow system idle sleep")
assert_equal(notification_count, 4, "each lifecycle press should refresh the Stream Deck once")

batteryPercentage = 10
idle.systemIdle = true
action.press({})
assert_equal(idle.displayIdle, true, "system-awake press should override battery limits")
assert_equal(idle.systemIdle, true, "system-awake press should retain system idle prevention")

idle.systemIdle = false
local display_only_appearance = action.appearance({})
assert_equal(display_only_appearance.title, "", "display-only state should use only its icon")
assert_equal(display_only_appearance.presentationState, 2, "display-only presentation state")

action.press({})
assert_equal(idle.displayIdle, false, "display-only press should allow displays to sleep")
assert_equal(idle.systemIdle, false, "display-only press should allow system idle sleep")

local notificationsBeforeFailure = notification_count
failDisplayToggle = true
local succeeded = pcall(caffeine.setLifecycleState, true, true, true)
assert_equal(succeeded, false, "failed lifecycle transition should raise an error")
assert_equal(
  notification_count,
  notificationsBeforeFailure + 1,
  "failed lifecycle transition should refresh the Stream Deck"
)

print("caffeinate lifecycle tests passed")
