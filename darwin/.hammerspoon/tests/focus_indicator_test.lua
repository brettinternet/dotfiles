local module_path = (arg[0]:match("(.*/)") or "") .. "../?.lua"
package.path = module_path .. ";" .. package.path

local function assert_equal(actual, expected, message)
  assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local now = 0
local inputCallback
local focusCallback
local followCallback
local eventtapCount = 0
local subscriptionCount = 0
local canvases = {}
local timers = {}
local periodicTimers = {}
local canvasAllocationFails = false
local currentFocusedWindow = nil
local frontmostApplication = nil

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

local types = {
  keyDown = 1,
  flagsChanged = 2,
  mouseMoved = 3,
  leftMouseDown = 4,
  rightMouseDown = 5,
  otherMouseDown = 6,
  scrollWheel = 7,
  gesture = 8,
}

_G.hs = {
  eventtap = {
    event = { types = types },
    new = function(eventTypes, callback)
      eventtapCount = eventtapCount + 1
      inputCallback = callback
      assert_equal(#eventTypes, 8, "all keyboard and pointer event kinds registered")
      return stoppable(callback)
    end,
  },
  timer = {
    absoluteTime = function()
      return now
    end,
    doAfter = function(delay, callback)
      local timer = stoppable(callback)
      timer.delay = delay
      table.insert(timers, timer)
      return timer
    end,
    doEvery = function(interval, callback)
      local timer = stoppable(callback)
      timer.interval = interval
      followCallback = callback
      table.insert(periodicTimers, timer)
      return timer
    end,
  },
  canvas = {
    new = function(frame)
      if canvasAllocationFails then
        return nil
      end
      local canvas = {
        sourceFrame = frame,
        deleted = false,
        shown = false,
      }
      function canvas:frame(value)
        if value then
          self.sourceFrame = value
          return self
        end
        return self.sourceFrame
      end
      function canvas:level(value)
        self.levelValue = value
        return self
      end
      function canvas:behavior(value)
        self.behaviorValue = value
        return self
      end
      function canvas:show()
        self.shown = true
        return self
      end
      function canvas:delete(fade)
        self.deleted = true
        self.deleteFade = fade
      end
      table.insert(canvases, canvas)
      return canvas
    end,
  },
  application = {
    frontmostApplication = function()
      return frontmostApplication
    end,
  },
  window = {
    filter = {
      windowFocused = "windowFocused",
      default = {
        subscribe = function(_self, event, callback)
          subscriptionCount = subscriptionCount + 1
          assert_equal(event, "windowFocused", "focused-window event subscribed")
          focusCallback = callback
        end,
      },
    },
    focusedWindow = function()
      return currentFocusedWindow
    end,
  },
  keycodes = {
    map = { w = 13, q = 12 },
  },
}

local focusIndicator = require("focus_indicator")
assert_equal(
  focusIndicator.start({ closeFocusBundleIDs = { "org.chromium.Chromium" } }),
  focusIndicator,
  "start returns module"
)
assert_equal(focusIndicator.start(), focusIndicator, "repeated start returns module")
assert_equal(eventtapCount, 1, "eventtap registered once")
assert_equal(subscriptionCount, 1, "window filter registered once")

local function event(eventType, flags, keyCode)
  return {
    getType = function()
      return eventType
    end,
    getFlags = function()
      return flags or {}
    end,
    getKeyCode = function()
      return keyCode
    end,
  }
end

local function application(bundleID, name)
  local mainWindow = nil
  local app = {
    activationCount = 0,
    bundleID = function()
      return bundleID
    end,
    name = function()
      return name
    end,
    mainWindow = function()
      return mainWindow
    end,
    activate = function(self)
      self.activationCount = self.activationCount + 1
      frontmostApplication = self
    end,
  }
  function app:setMainWindow(window)
    mainWindow = window
  end
  return app
end

local function window(frame, title, fallbackApplication)
  if type(fallbackApplication) == "string" then
    fallbackApplication = application(nil, fallbackApplication)
  end
  local currentFrame = frame
  local target = {
    focusCount = 0,
    frame = function()
      return currentFrame
    end,
    title = function()
      return title
    end,
    application = function()
      return fallbackApplication
    end,
  }
  function target:setFrame(newFrame)
    currentFrame = newFrame
  end
  function target:focus()
    self.focusCount = self.focusCount + 1
    currentFocusedWindow = self
    frontmostApplication = fallbackApplication
    return self
  end
  return target
end

local function keyboardFocus(target, applicationName)
  now = now + 100
  assert_equal(inputCallback(event(types.keyDown)), false, "keyboard input propagates")
  focusCallback(target, applicationName)
end

local firstWindow = window({ x = 10, y = 20, w = 800, h = 600 }, "README", "Ghostty")
keyboardFocus(firstWindow, "Ghostty")
local firstCanvas = canvases[#canvases]
local firstTimer = timers[#timers]
assert(firstCanvas.shown, "recent keyboard focus should show canvas")
assert_equal(firstCanvas[3].text, "Ghostty — README", "canvas label")
firstTimer.callback()
assert(firstCanvas.deleted, "dismissal deletes canvas")
assert(periodicTimers[1].stopped, "dismissal stops follow polling")

local beforeExplicitShow = #canvases
focusIndicator.show(firstWindow, "Ghostty")
assert_equal(#canvases, beforeExplicitShow + 1, "explicit show renders without a focus event")
assert_equal(canvases[#canvases][3].text, "Ghostty — README", "explicit show uses the supplied label")
local movingCanvas = canvases[#canvases]
local movingDismissalTimer = timers[#timers]
local movingFollowTimer = periodicTimers[#periodicTimers]
local canvasCountBeforeMove = #canvases
firstWindow:setFrame({ x = 30, y = 40, w = 800, h = 600 })
followCallback()
assert_equal(#canvases, canvasCountBeforeMove, "follow tick reuses active canvas")
assert_equal(movingCanvas.sourceFrame.x, 30, "canvas follows window position")
assert_equal(timers[#timers], movingDismissalTimer, "follow tick preserves dismissal timer")
assert(not movingFollowTimer.stopped, "follow tick preserves polling timer")

firstWindow:setFrame({ x = 30, y = 40, w = 400, h = 300 })
followCallback()
assert_equal(movingCanvas.sourceFrame.w, 400, "canvas follows window size")
assert_equal(movingCanvas[1].frame.w, 394, "resize updates border width")
assert_equal(movingCanvas[2].frame.w, 368, "resize updates label width")
assert_equal(movingCanvas[3].text, "Ghostty — README", "resize preserves label")

firstWindow:setFrame({ x = 30, y = 40, w = 150, h = 63 })
followCallback()
assert_equal(movingCanvas[2], nil, "small resize removes label background")
assert_equal(movingCanvas[3], nil, "small resize removes label")

firstWindow:setFrame({ x = 30, y = 40, w = 400, h = 300 })
followCallback()
assert_equal(movingCanvas[3].text, "Ghostty — README", "larger resize restores label")

for _, pointerType in ipairs({ types.mouseMoved, types.leftMouseDown, types.gesture }) do
  local before = #canvases
  now = now + 100
  assert_equal(inputCallback(event(pointerType)), false, "pointer input propagates")
  focusCallback(firstWindow, "Ghostty")
  assert_equal(#canvases, before, "pointer focus remains silent")
end

local beforeStale = #canvases
now = now + 100
inputCallback(event(types.flagsChanged))
now = now + 1000000001
focusCallback(firstWindow, "Ghostty")
assert_equal(#canvases, beforeStale, "stale keyboard focus remains silent")

local beforeDelayedClose = #canvases
now = now + 100
inputCallback(event(types.keyDown, { cmd = true }, hs.keycodes.map.w))
now = now + 2000000000
focusCallback(firstWindow, "Ghostty")
assert_equal(#canvases, beforeDelayedClose + 1, "delayed Cmd-W focus shows indicator")

local beforeConsumedClose = #canvases
focusCallback(firstWindow, "Ghostty")
assert_equal(#canvases, beforeConsumedClose, "close focus intent is consumed")

local beforeDelayedQuit = #canvases
now = now + 100
inputCallback(event(types.keyDown, { cmd = true }, hs.keycodes.map.q))
now = now + 2000000000
focusCallback(firstWindow, "Ghostty")
assert_equal(#canvases, beforeDelayedQuit + 1, "delayed Cmd-Q focus shows indicator")

local beforePointerCancelledClose = #canvases
now = now + 100
inputCallback(event(types.keyDown, { cmd = true }, hs.keycodes.map.w))
inputCallback(event(types.mouseMoved))
focusCallback(firstWindow, "Ghostty")
assert_equal(#canvases, beforePointerCancelledClose, "pointer input cancels close focus intent")

local beforeKeyboardCancelledClose = #canvases
now = now + 100
inputCallback(event(types.keyDown, { cmd = true }, hs.keycodes.map.w))
inputCallback(event(types.keyDown, {}, 0))
now = now + 2000000000
focusCallback(firstWindow, "Ghostty")
assert_equal(#canvases, beforeKeyboardCancelledClose, "other key cancels close focus intent")

keyboardFocus(firstWindow, "Ghostty")
local replacedCanvas = canvases[#canvases]
local replacedTimer = timers[#timers]
keyboardFocus(window({ x = 0, y = 0, w = 500, h = 400 }, "Docs", "Finder"), "Finder")
assert(replacedTimer.stopped, "replacement stops old timer")
assert(replacedCanvas.deleted, "replacement deletes old canvas")
assert_equal(replacedCanvas.deleteFade, nil, "replacement deletes without fade")
assert_equal(canvases[#canvases][3].text, "Finder — Docs", "replacement label")

keyboardFocus(window({ x = 0, y = 0, w = 300, h = 200 }, "", "Safari"), "Safari")
assert_equal(canvases[#canvases][3].text, "Safari", "empty title omitted")
keyboardFocus(window({ x = 0, y = 0, w = 300, h = 200 }, "Safari", "Safari"), "Safari")
assert_equal(canvases[#canvases][3].text, "Safari", "repeated title omitted")
keyboardFocus(window({ x = 0, y = 0, w = 300, h = 200 }, "Document", "Preview"), nil)
assert_equal(canvases[#canvases][3].text, "Preview — Document", "application fallback label")
keyboardFocus(window({ x = 0, y = 0, w = 300, h = 200 }, "", nil), nil)
assert_equal(canvases[#canvases][3].text, "Focused window", "empty label fallback")

keyboardFocus(window({ x = 0, y = 0, w = 159, h = 63 }, "Tiny", "App"), "App")
local smallCanvas = canvases[#canvases]
assert(smallCanvas[1], "small valid window has border")
assert_equal(smallCanvas[2], nil, "small valid window has no label background")
assert_equal(smallCanvas[3], nil, "small valid window has no label")

for _, invalidFrame in ipairs({ false, { x = 0, y = 0, w = 4, h = 100 }, { x = 0, y = 0, w = 100, h = 4 } }) do
  local before = #canvases
  keyboardFocus(window(invalidFrame or nil, "Invalid", "App"), "App")
  assert_equal(#canvases, before, "invalid geometry ignored")
end
local beforeNilWindow = #canvases
now = now + 100
inputCallback(event(types.keyDown))
focusCallback(nil, "App")
assert_equal(#canvases, beforeNilWindow, "nil window ignored")

local timersBeforeFailure = #timers
canvasAllocationFails = true
keyboardFocus(firstWindow, "Ghostty")
assert_equal(#timers, timersBeforeFailure, "allocation failure creates no timer")
canvasAllocationFails = false

local ghosttyApplication = application("com.mitchellh.ghostty", "Ghostty")
local chromiumApplication = application("org.chromium.Chromium", "Chromium")
local ghosttyWindow = window({ x = 0, y = 0, w = 700, h = 500 }, "Terminal", ghosttyApplication)
local chromiumWindow = window({ x = 20, y = 20, w = 900, h = 700 }, "Browser", chromiumApplication)

keyboardFocus(ghosttyWindow, "Ghostty")
keyboardFocus(chromiumWindow, "Chromium")
frontmostApplication = chromiumApplication
chromiumApplication:setMainWindow(nil)
local timersBeforeLastWindowClose = #timers
inputCallback(event(types.keyDown, { cmd = true }, hs.keycodes.map.w))
assert_equal(#timers, timersBeforeLastWindowClose + 1, "designated app schedules last-window check")
local closeCheckTimer = timers[#timers]
closeCheckTimer.callback()
assert_equal(ghosttyWindow.focusCount, 1, "last window close focuses previous window")
local canvasesBeforeFallbackIndicator = #canvases
local fallbackIndicatorTimer = timers[#timers]
fallbackIndicatorTimer.callback()
assert_equal(#canvases, canvasesBeforeFallbackIndicator + 1, "fallback focus explicitly shows indicator")

frontmostApplication = chromiumApplication
chromiumApplication:setMainWindow(chromiumWindow)
local previousWindowFocusCount = ghosttyWindow.focusCount
inputCallback(event(types.keyDown, { cmd = true }, hs.keycodes.map.w))
timers[#timers].callback()
assert_equal(ghosttyWindow.focusCount, previousWindowFocusCount, "remaining app window prevents fallback focus")

frontmostApplication = ghosttyApplication
local timersBeforeUnconfiguredClose = #timers
inputCallback(event(types.keyDown, { cmd = true }, hs.keycodes.map.w))
assert_equal(#timers, timersBeforeUnconfiguredClose, "unconfigured app does not schedule fallback focus")

print("focus indicator tests passed")
