local module_path = (arg[0]:match("(.*/)") or "") .. "../?.lua"
package.path = module_path .. ";" .. package.path

local function assert_equal(actual, expected, message)
  assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local mark = 970417
local recordedEvents = {}
local inputCallback
local pulseCallback
local lastPulseDelay
local sleepCallback
local focusedWindow
local modalWindow
local killCount = 0
local foreignKillCount = 0
local alerts = {}
local launchArguments
local requestedFullscreen
local requestedSize
local centered = false
local applicationForPIDOverride

local simWindow = {
  id = function()
    return 42
  end,
  title = function()
    return "System Monitor"
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

local foreignWindow = {
  title = function()
    return "System Monitor"
  end,
}

local foreignApp = {
  pid = function()
    return 54321
  end,
  allWindows = function()
    return { foreignWindow }
  end,
  kill = function()
    foreignKillCount = foreignKillCount + 1
  end,
}

local recycledApp = {
  bundleID = function()
    return "com.example.recycled"
  end,
  allWindows = function()
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
  configdir = "/tmp/hs-test",
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
    doAfter = function(delay, callback)
      lastPulseDelay = delay
      if not pulseCallback then
        pulseCallback = callback
      end
      return stoppable(callback)
    end,
    waitUntil = function(predicate, callback, _interval)
      assert(predicate(), "sim window should be discoverable")
      callback()
      return stoppable(callback)
    end,
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
      if applicationForPIDOverride then
        return applicationForPIDOverride
      end
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
        return { foreignApp }
      end
      return { foreignApp, app }
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
      screensDidLock = 2,
      new = function(callback)
        sleepCallback = callback
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

local function assert_pulse(message)
  assert_equal(#recordedEvents, 2, message .. " should post exactly one event pair")
  assert_equal(recordedEvents[1].isDown, true, message .. " should press Shift")
  assert_equal(recordedEvents[2].isDown, false, message .. " should release Shift")
  for i = 1, 2 do
    assert_equal(recordedEvents[i].key, "shift", message .. " event key")
    assert_equal(recordedEvents[i].properties.eventSourceUserData, mark, message .. " event marker")
    assert_equal(recordedEvents[i].postTarget, nil, message .. " should post at session level")
  end
  assert_equal(#recordedEvents[1].mods, 0, message .. " should not smuggle modifiers")
end

recordedEvents = {}
assert(idlesim.start(), "sim should start")
assert(launchArguments, "sim should launch its dashboard")
for _, argument in ipairs(launchArguments) do
  assert(not tostring(argument):match("nvim"), "launch arguments should not reference Neovim")
end
assert_equal(requestedFullscreen, false, "sim window should exit full-screen mode")
assert(requestedSize, "sim window should be sized")
assert_equal(centered, true, "sim window should be centered")
assert_pulse("startup pulse")
assert_equal(idlesim.isRunning(), true, "sim should be running")

recordedEvents = {}
pulseCallback()
assert_pulse("interval pulse")
assert(lastPulseDelay >= 15 and lastPulseDelay <= 45, "pulse should reschedule within 15-45s")

focusedWindow = {
  id = function()
    return 99
  end,
}
recordedEvents = {}
pulseCallback()
assert_pulse("unfocused pulse")
assert_equal(idlesim.isRunning(), true, "unfocused pulse should keep the sim running")

inputCallback({
  getProperty = function()
    return mark
  end,
})
assert_equal(idlesim.isRunning(), true, "marked pulses should be ignored")

inputCallback({
  getProperty = function()
    return 0
  end,
})
assert_equal(idlesim.isRunning(), false, "unmarked input should stop the sim")
assert_equal(killCount, 1, "unmarked input should kill the launched Ghostty instance")
assert_equal(foreignKillCount, 0, "unmarked input should preserve existing Ghostty instances")

modalWindow = {
  id = function()
    return 77
  end,
  title = function()
    return "Allow Ghostty to execute idlesim-dashboard?"
  end,
  subrole = function()
    return "AXDialog"
  end,
}
assert(idlesim.start(), "sim should restart for modal test")
assert_equal(idlesim.isRunning(), false, "a Ghostty modal should stop the sim")
assert_equal(foreignKillCount, 0, "modal stop should preserve existing Ghostty instances")
modalWindow = nil

local realTime = os.time
local now = 1000
os.time = function()
  return now
end
assert(idlesim.start(), "sim should restart for timeout test")
now = now + 60 * 60 + 1
pulseCallback()
os.time = realTime
assert_equal(idlesim.isRunning(), false, "the hard timeout should stop the sim")

assert(idlesim.start(), "sim should restart for sleep test")
local killsBeforeSleep = killCount
sleepCallback(hs.caffeinate.watcher.systemWillSleep)
assert_equal(idlesim.isRunning(), false, "system sleep should stop the sim")
assert_equal(killCount, killsBeforeSleep + 1, "system sleep should kill the launched Ghostty instance")
assert_equal(foreignKillCount, 0, "sleep stop should preserve existing Ghostty instances")

assert(idlesim.start(), "sim should restart for lock test")
local killsBeforeLock = killCount
sleepCallback(hs.caffeinate.watcher.screensDidLock)
assert_equal(idlesim.isRunning(), false, "screen lock should stop the sim")
assert_equal(killCount, killsBeforeLock + 1, "screen lock should kill the launched Ghostty instance")
assert_equal(foreignKillCount, 0, "lock stop should preserve existing Ghostty instances")

assert(idlesim.start(), "sim should restart for reload cleanup test")
local killsBeforeReload = killCount
local alertsBeforeReload = #alerts
idlesim.stop()
assert_equal(idlesim.isRunning(), false, "reload cleanup should stop the sim")
assert_equal(killCount, killsBeforeReload + 1, "reload cleanup should kill the launched Ghostty instance")
assert_equal(foreignKillCount, 0, "reload cleanup should preserve existing Ghostty instances")
assert_equal(#alerts, alertsBeforeReload, "reload cleanup should stay silent")

assert(idlesim.start(), "sim should restart for stale PID test")
local killsBeforeStalePid = killCount
applicationForPIDOverride = recycledApp
idlesim.stop()
applicationForPIDOverride = nil
assert_equal(killCount, killsBeforeStalePid, "a recycled PID should not be killed")
assert_equal(foreignKillCount, 0, "stale PID cleanup should preserve existing Ghostty instances")

print("idlesim tests passed")
