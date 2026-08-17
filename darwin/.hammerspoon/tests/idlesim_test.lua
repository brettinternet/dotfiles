local module_path = (arg[0]:match("(.*/)") or "") .. "../?.lua"
package.path = module_path .. ";" .. package.path

local function assert_equal(actual, expected, message)
  assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local mark = 970417
local recordedEvents = {}
local inputCallback
local burstCallback
local focusedWindow
local modalWindow
local killCount = 0
local alerts = {}
local launchArguments
local requestedFullscreen
local requestedSize
local centered = false

local simWindow = {
  id = function()
    return 42
  end,
  title = function()
    return "hs-idlesim"
  end,
  subrole = function()
    return "AXStandardWindow"
  end,
  isFullScreen = function()
    return true
  end,
  setFullScreen = function(_self, value)
    requestedFullscreen = value
  end,
  setSize = function(_self, value)
    requestedSize = value
  end,
  centerOnScreen = function()
    centered = true
  end,
  focus = function(self)
    focusedWindow = self
  end,
}

local app = {
  pid = function()
    return 12345
  end,
  bundleID = function()
    return "com.mitchellh.ghostty"
  end,
  allWindows = function()
    if modalWindow then
      return { simWindow, modalWindow }
    end
    return { simWindow }
  end,
  kill = function()
    killCount = killCount + 1
  end,
}
local applicationQueries = 0

local function stoppable(callback)
  return {
    callback = callback,
    stopped = false,
    start = function(self)
      return self
    end,
    stop = function(self)
      self.stopped = true
    end,
  }
end

_G.hs = {
  eventtap = {
    event = {
      properties = { eventSourceUserData = "eventSourceUserData" },
      types = {
        keyDown = 1,
        flagsChanged = 2,
        mouseMoved = 3,
        leftMouseDown = 4,
        rightMouseDown = 5,
        scrollWheel = 6,
      },
      newKeyEvent = function(mods, key, isDown)
        local event = {
          mods = mods,
          key = key,
          isDown = isDown,
          properties = {},
        }
        function event:setProperty(property, value)
          self.properties[property] = value
        end
        function event:post(target)
          self.postTarget = target
          table.insert(recordedEvents, self)
        end
        return event
      end,
    },
    new = function(_types, callback)
      inputCallback = callback
      return stoppable(callback)
    end,
  },
  timer = {
    doEvery = function(_interval, callback)
      burstCallback = callback
      return stoppable(callback)
    end,
    doAfter = function(delay, callback)
      if delay == 2 then
        callback()
      end
      return stoppable(callback)
    end,
    waitUntil = function(predicate, callback, _interval)
      assert(predicate(), "sim window should be discoverable")
      callback()
      return stoppable(callback)
    end,
    usleep = function() end,
  },
  task = {
    new = function(_path, _callback, arguments)
      launchArguments = arguments
      return {
        start = function()
          return true
        end,
      }
    end,
  },
  application = {
    applicationForPID = function(pid)
      if pid == 12345 then
        return app
      end
      return nil
    end,
    applicationsForBundleID = function(bundleID)
      if bundleID ~= "com.mitchellh.ghostty" then
        return {}
      end
      applicationQueries = applicationQueries + 1
      if applicationQueries % 2 == 1 then
        return {}
      end
      return { app }
    end,
  },
  window = {
    focusedWindow = function()
      return focusedWindow
    end,
  },
  host = {
    idleTime = function()
      return 0
    end,
  },
  alert = {
    show = function(message)
      table.insert(alerts, message)
    end,
  },
  menubar = {
    new = function()
      return {
        setClickCallback = function() end,
        setTitle = function() end,
        setTooltip = function() end,
        delete = function() end,
      }
    end,
  },
  caffeinate = {
    watcher = {
      systemWillSleep = 1,
      new = function(callback)
        return stoppable(callback)
      end,
    },
  },
  fs = {
    attributes = function()
      return { mode = "file" }
    end,
    mkdir = function()
      return true
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

local idlesim = require("idlesim")
local action = require("idlesim_action")

assert_equal(action.appearance({}).title, "Sim\noff", "inactive action title")
assert(idlesim.start(), "sim should start")
assert_equal(
  launchArguments[4],
  "--command=/opt/homebrew/bin/nvim -u NONE -n " .. os.getenv("HOME") .. "/.local/state/hammerspoon/idlesim.md",
  "sim editor should avoid user config and swap prompts"
)
assert_equal(launchArguments[6], "--window-save-state=never", "sim should ignore saved window state")
assert_equal(launchArguments[7], "--fullscreen=false", "sim window should not be full-screen")
assert_equal(launchArguments[8], "--window-width=60", "sim window should be narrow")
assert_equal(launchArguments[9], "--window-height=16", "sim window should be short")
assert(#recordedEvents > 2, "startup should toggle full-screen and type an initial burst")
for i = 1, 2 do
  local event = recordedEvents[i]
  assert_equal(event.key, "f", "full-screen startup should use Ghostty's toggle binding")
  assert_equal(event.properties.eventSourceUserData, mark, "full-screen toggle should be marked")
  assert_equal(event.postTarget, nil, "full-screen toggle should post to the session")
end
assert_equal(requestedFullscreen, false, "sim window should exit full-screen mode")
assert_equal(requestedSize.w, 720, "sim window point width")
assert_equal(requestedSize.h, 440, "sim window point height")
assert_equal(centered, true, "sim window should be centered")
assert_equal(idlesim.isRunning(), true, "sim should be running")
assert_equal(action.appearance({}).title, "Sim\nactive", "active action title")

recordedEvents = {}
burstCallback()
assert(#recordedEvents > 0, "focused burst should post key events")
local sawTimestampColon = false
local sawSpace = false
for _, event in ipairs(recordedEvents) do
  assert_equal(event.properties.eventSourceUserData, mark, "every synthetic event should be marked")
  assert_equal(event.postTarget, nil, "every synthetic event should post to the session")
  assert(event.key ~= ":", "text typing should not pass an invalid colon key name")
  assert(event.key ~= " ", "text typing should not pass an invalid literal space key name")
  if event.key == ";" and event.mods[1] == "shift" then
    sawTimestampColon = true
  end
  if event.key == "space" then
    sawSpace = true
  end
end
assert_equal(sawTimestampColon, true, "timestamp colon should use shift-semicolon")
assert_equal(sawSpace, true, "text spaces should use the named space key")

inputCallback({
  getProperty = function()
    return mark
  end,
})
assert_equal(idlesim.isRunning(), true, "own events should be ignored")

focusedWindow = {
  id = function()
    return 99
  end,
}
recordedEvents = {}
burstCallback()
assert_equal(#recordedEvents, 0, "unfocused burst should not post events")
assert_equal(idlesim.isRunning(), true, "unfocused burst should keep the sim running")

inputCallback({
  getProperty = function()
    return 0
  end,
})
assert_equal(idlesim.isRunning(), false, "real input should stop the sim")
assert_equal(killCount, 1, "real input should kill the launched Ghostty instance")

modalWindow = {
  id = function()
    return 77
  end,
  title = function()
    return "Allow Ghostty to execute nvim?"
  end,
  subrole = function()
    return "AXDialog"
  end,
}
assert(idlesim.start(), "sim should restart for modal test")
assert_equal(idlesim.isRunning(), false, "a Ghostty modal should stop the sim")
modalWindow = nil

local realTime = os.time
local now = 1000
os.time = function()
  return now
end
assert(idlesim.start(), "sim should restart for timeout test")
now = now + 3 * 60 * 60 + 1
burstCallback()
os.time = realTime
assert_equal(idlesim.isRunning(), false, "the hard timeout should stop the sim")

print("idlesim tests passed")
