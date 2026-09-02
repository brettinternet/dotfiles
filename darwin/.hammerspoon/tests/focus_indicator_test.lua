local module_path = (arg[0]:match("(.*/)") or "") .. "../?.lua"
package.path = module_path .. ";" .. package.path

local function assert_equal(actual, expected, message)
  assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local now = 0
local inputCallback
local focusCallback
local eventtapCount = 0
local subscriptionCount = 0
local canvases = {}
local timers = {}
local canvasAllocationFails = false

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
  },
  keycodes = {
    map = { w = 13, q = 12 },
  },
}

local focusIndicator = require("focus_indicator")
assert_equal(focusIndicator.start(), focusIndicator, "start returns module")
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

local function window(frame, title, fallbackName)
  return {
    frame = function()
      return frame
    end,
    title = function()
      return title
    end,
    application = function()
      if not fallbackName then
        return nil
      end
      return {
        name = function()
          return fallbackName
        end,
      }
    end,
  }
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
assert_equal(firstCanvas.levelValue, "overlay", "canvas level")
assert_equal(#firstCanvas.behaviorValue, 3, "canvas Space behaviors")
assert_equal(firstCanvas[1].action, "stroke", "border action")
assert_equal(firstCanvas[1].frame.w, 794, "border width")
assert_equal(firstCanvas[1].strokeWidth, 6, "border stroke width")
assert_equal(firstCanvas[3].text, "Ghostty — README", "canvas label")
assert_equal(firstCanvas[3].textLineBreak, "truncateTail", "label truncation")
assert_equal(firstTimer.delay, 1.8, "dismissal delay")
firstTimer.callback()
assert(firstCanvas.deleted, "dismissal deletes canvas")
assert_equal(firstCanvas.deleteFade, 0.2, "dismissal fade")

local beforeExplicitShow = #canvases
focusIndicator.show(firstWindow, "Ghostty")
assert_equal(#canvases, beforeExplicitShow + 1, "explicit show renders without a focus event")
assert_equal(canvases[#canvases][3].text, "Ghostty — README", "explicit show uses the supplied label")

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

print("focus indicator tests passed")
