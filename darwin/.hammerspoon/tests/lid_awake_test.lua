package.path = (arg[0]:match("(.*/)") or "") .. "../?.lua;" .. package.path

local control = "/Library/Application Support/local.lid-awake"
local request = control .. "/enabled"
local installed = false
local requested = false
local writable = true
local disabledSleep = false
local readSuccess = true
local created = 0
local menu, poll
local settles = {}
local function settle()
  for _, callback in ipairs(settles) do
    callback()
  end
  settles = {}
end
local title, alert
local bar = {}
function bar:setTitle(value)
  title = value
end
function bar:setTooltip() end
function bar:setMenu(value)
  menu = value
end

io.open = function(path, mode)
  assert(path == request and mode == "w")
  if not writable then
    return nil, "Permission denied"
  end
  requested = true
  return {
    close = function()
      return true
    end,
  }
end
os.remove = function(path)
  assert(path == request)
  if not requested then
    return nil, "No such file or directory"
  end
  requested = false
  return true
end

_G.hs = {
  fs = {
    attributes = function(path)
      if path == control then
        return installed and {} or nil
      end
      return requested and {} or nil
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
    doAfter = function(_, callback)
      table.insert(settles, callback)
      return {}
    end,
  },
  alert = {
    show = function(value)
      alert = value
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
assert(requested, "Enabling writes a request without sudo")
assert(title == "Lid: sleep", "Show applied state, not the request")
disabledSleep = true
settle()
assert(menu()[1].checked and title == "Lid: awake")
menu()[1].fn()
assert(not requested, "Disabling removes the request")
disabledSleep = false
settle()
assert(title == "Lid: sleep")
-- The daemon can reset while Hammerspoon is idle or disconnected.
disabledSleep = true
poll()
assert(title == "Lid: awake")
menu()[1].fn()
assert(alert == nil, "Removing an already-consumed request is not an error")
disabledSleep = false
poll()
assert(title == "Lid: sleep" and not menu()[1].checked)
writable = false
menu()[1].fn()
assert(alert:match("Permission denied") and title == "Lid: sleep")
readSuccess = false
assert(menu()[1].disabled and title == "Lid: ?", "Failed status reads must not claim success")
print("lid_awake tests passed")
