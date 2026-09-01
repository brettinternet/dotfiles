local focusIndicator = {}

local keyboardFreshnessNanoseconds = 1000000000
local inputTap = nil
local windowFilter = nil
local lastInputKind = nil
local lastInputTime = nil
local canvas = nil
local dismissalTimer = nil

local eventTypes = hs.eventtap.event.types
local keyboardEvents = {
  [eventTypes.keyDown] = true,
  [eventTypes.flagsChanged] = true,
}

local function dismissCurrent()
  if dismissalTimer then
    dismissalTimer:stop()
    dismissalTimer = nil
  end
  if canvas then
    canvas:delete()
    canvas = nil
  end
end

local function labelFor(window, applicationName)
  local appName = applicationName
  if not appName or appName == "" then
    local application = window:application()
    appName = application and application:name() or nil
  end

  local title = window:title()
  if title == "" or title == appName then
    title = nil
  end

  if appName and appName ~= "" then
    if title then
      return appName .. " — " .. title
    end
    return appName
  end
  return title or "Focused window"
end

local function render(window, applicationName)
  dismissCurrent()

  if not window then
    return
  end
  local frame = window:frame()
  if not frame or not frame.w or not frame.h or frame.w <= 6 or frame.h <= 6 then
    return
  end

  local newCanvas = hs.canvas.new(frame)
  if not newCanvas then
    return
  end
  canvas = newCanvas
  canvas:level("overlay")
  canvas:behavior({
    "canJoinAllSpaces",
    "fullScreenAuxiliary",
    "ignoresCycle",
  })
  canvas[1] = {
    type = "rectangle",
    action = "stroke",
    frame = { x = 3, y = 3, w = frame.w - 6, h = frame.h - 6 },
    strokeWidth = 6,
    roundedRectRadii = { xRadius = 10, yRadius = 10 },
    strokeColor = { red = 0.04, green = 0.52, blue = 1, alpha = 0.95 },
  }

  if frame.w >= 160 and frame.h >= 64 then
    local labelWidth = math.min(520, frame.w - 32)
    local labelX = (frame.w - labelWidth) / 2
    local labelY = frame.h - 46
    canvas[2] = {
      type = "rectangle",
      action = "fill",
      frame = { x = labelX, y = labelY, w = labelWidth, h = 34 },
      roundedRectRadii = { xRadius = 8, yRadius = 8 },
      fillColor = { white = 0.08, alpha = 0.88 },
    }
    canvas[3] = {
      type = "text",
      text = labelFor(window, applicationName),
      frame = { x = labelX + 12, y = labelY + 8, w = labelWidth - 24, h = 18 },
      textColor = { white = 1, alpha = 1 },
      textSize = 14,
      textAlignment = "center",
      textLineBreak = "truncateTail",
    }
  end

  canvas:show()
  dismissalTimer = hs.timer.doAfter(1.8, function()
    dismissalTimer = nil
    if canvas == newCanvas then
      canvas:delete(0.2)
      canvas = nil
    end
  end)
end

local function inputEvent(event)
  lastInputKind = keyboardEvents[event:getType()] and "keyboard" or "pointer"
  lastInputTime = hs.timer.absoluteTime()
  return false
end

local function windowFocused(window, applicationName)
  if
    lastInputKind ~= "keyboard"
    or not lastInputTime
    or hs.timer.absoluteTime() - lastInputTime > keyboardFreshnessNanoseconds
  then
    return
  end
  render(window, applicationName)
end

function focusIndicator.start()
  if inputTap then
    return focusIndicator
  end

  inputTap = hs.eventtap
    .new({
      eventTypes.keyDown,
      eventTypes.flagsChanged,
      eventTypes.mouseMoved,
      eventTypes.leftMouseDown,
      eventTypes.rightMouseDown,
      eventTypes.otherMouseDown,
      eventTypes.scrollWheel,
      eventTypes.gesture,
    }, inputEvent)
    :start()

  windowFilter = hs.window.filter.default
  windowFilter:subscribe(hs.window.filter.windowFocused, windowFocused)
  return focusIndicator
end

return focusIndicator
