package.path = (arg[0]:match("(.*/)") or "") .. "../?.lua;" .. package.path

local installed = false
local disabledSleep = false
local readSuccess = true
local created = 0
local menu, poll, pending
local title, alert
local bar = {}
function bar:setTitle(value)
  title = value
end
function bar:setTooltip() end
function bar:setMenu(value)
  menu = value
end

_G.hs = {
  fs = {
    attributes = function()
      return installed and {} or nil
    end,
  },
  execute = function()
    return disabledSleep and " SleepDisabled 1\n" or "System-wide power settings:\n", readSuccess
  end,
  menubar = {
    new = function()
      created = created + 1
      return bar
    end,
  },
  timer = {
    doEvery = function(_, callback)
      poll = callback
      return {}
    end,
  },
  alert = {
    show = function(value)
      alert = value
    end,
  },
  task = {
    new = function(executable, callback, arguments)
      assert(executable == "/usr/bin/sudo")
      assert(arguments[1] == "-n", "Never prompt for a password from the menu")
      pending = { callback = callback, action = arguments[3] }
      return {
        start = function()
          return true
        end,
      }
    end,
  },
}

local helper = require("lid_awake")
helper.start()
assert(created == 0, "Unconfigured workstations must not show a menu")
installed = true
helper.start()
helper.start()
assert(created == 1, "Repeated starts must not duplicate the menu")
assert(title == "Lid: sleep")
menu()[1].fn()
assert(pending.action == "enable")
assert(menu()[1].disabled, "Block overlapping requests")
disabledSleep = true
pending.callback(0, "", "")
assert(menu()[1].checked and title == "Lid: awake")
menu()[1].fn()
assert(pending.action == "disable")
disabledSleep = false
pending.callback(0, "", "")
assert(title == "Lid: sleep")
-- The daemon can reset while Hammerspoon is idle or disconnected.
disabledSleep = true
poll()
assert(title == "Lid: awake")
disabledSleep = false
poll()
assert(title == "Lid: sleep" and not menu()[1].checked)
menu()[1].fn()
pending.callback(1, "", "watcher unavailable")
assert(alert:match("watcher unavailable") and title == "Lid: sleep")
readSuccess = false
assert(menu()[1].disabled and title == "Lid: ?", "Failed status reads must not claim success")
print("lid_awake tests passed")
