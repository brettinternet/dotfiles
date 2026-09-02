local focusIndicator = {}

local keyboardFreshnessNanoseconds = 1000000000
local closeFocusFreshnessNanoseconds = 10000000000
local closeWindowCheckDelaySeconds = 0.15
local followIntervalSeconds = 0.03
local inputTap = nil
local windowFilter = nil
local lastInputKind = nil
local lastInputTime = nil
local closeFocusPendingAt = nil
local canvas = nil
local highlightedWindow = nil
local followTimer = nil
local highlightedFrame = nil
local highlightedLabel = nil
local dismissalTimer = nil
local closeFocusBundleIDs = {}
local focusedApplication = nil
local focusedWindow = nil
local previousFocusedApplication = nil
local previousFocusedWindow = nil
local renderVersion = 0
local followHighlightedWindow

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
  if followTimer then
    followTimer:stop()
    followTimer = nil
  end
  if canvas then
    canvas:delete()
    canvas = nil
  end
  highlightedWindow = nil
  highlightedFrame = nil
  highlightedLabel = nil
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
  highlightedWindow = window
  highlightedFrame = frame
  highlightedLabel = labelFor(window, applicationName)
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
      text = highlightedLabel,
      frame = { x = labelX + 12, y = labelY + 8, w = labelWidth - 24, h = 18 },
      textColor = { white = 1, alpha = 1 },
      textSize = 14,
      textAlignment = "center",
      textLineBreak = "truncateTail",
    }
  end

  canvas:show()
  followTimer = hs.timer.doEvery(followIntervalSeconds, followHighlightedWindow)
  dismissalTimer = hs.timer.doAfter(1.8, function()
    dismissalTimer = nil
    if canvas == newCanvas then
      if followTimer then
        followTimer:stop()
        followTimer = nil
      end
      canvas:delete(0.2)
      canvas = nil
      highlightedWindow = nil
      highlightedFrame = nil
      highlightedLabel = nil
    end
  end)
  renderVersion = renderVersion + 1
end

followHighlightedWindow = function()
  if not canvas or not highlightedWindow then
    return
  end

  local frame = highlightedWindow:frame()
  if not frame or not frame.w or not frame.h or frame.w <= 6 or frame.h <= 6 then
    dismissCurrent()
    return
  end

  if
    frame.x == highlightedFrame.x
    and frame.y == highlightedFrame.y
    and frame.w == highlightedFrame.w
    and frame.h == highlightedFrame.h
  then
    return
  end

  canvas:frame(frame)
  if frame.w == highlightedFrame.w and frame.h == highlightedFrame.h then
    highlightedFrame = frame
    return
  end
  canvas[1].frame = { x = 3, y = 3, w = frame.w - 6, h = frame.h - 6 }
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
      text = highlightedLabel,
      frame = { x = labelX + 12, y = labelY + 8, w = labelWidth - 24, h = 18 },
      textColor = { white = 1, alpha = 1 },
      textSize = 14,
      textAlignment = "center",
      textLineBreak = "truncateTail",
    }
  else
    canvas[3] = nil
    canvas[2] = nil
  end
  highlightedFrame = frame
end

local function applicationFor(window)
  return window and window:application() or nil
end

local function rememberFocus(window)
  local application = applicationFor(window)
  if application and application ~= focusedApplication then
    previousFocusedApplication = focusedApplication
    previousFocusedWindow = focusedWindow
  end
  if application then
    focusedApplication = application
    focusedWindow = window
  end
end

local function configuredForCloseFocus(application)
  if not application then
    return false
  end
  local bundleID = application:bundleID()
  return bundleID and closeFocusBundleIDs[bundleID] == true
end

local function focusPreviousApplicationAfterClose()
  local closingApplication = hs.application.frontmostApplication()
  if not configuredForCloseFocus(closingApplication) then
    return
  end

  local targetApplication = previousFocusedApplication
  local targetWindow = previousFocusedWindow
  if not targetApplication or targetApplication == closingApplication then
    return
  end

  hs.timer.doAfter(closeWindowCheckDelaySeconds, function()
    if hs.application.frontmostApplication() ~= closingApplication or closingApplication:mainWindow() then
      return
    end

    local versionBeforeFocus = renderVersion
    local focused = targetWindow and pcall(function()
      targetWindow:focus()
    end)
    if not focused then
      targetApplication:activate(true)
    end

    hs.timer.doAfter(0, function()
      if renderVersion == versionBeforeFocus then
        render(hs.window.focusedWindow())
      end
    end)
  end)
end

local function inputEvent(event)
  local eventType = event:getType()
  local isKeyboard = keyboardEvents[eventType]
  lastInputKind = isKeyboard and "keyboard" or "pointer"
  lastInputTime = hs.timer.absoluteTime()

  if not isKeyboard then
    closeFocusPendingAt = nil
  elseif eventType == eventTypes.keyDown then
    local flags = event:getFlags()
    local keyCode = event:getKeyCode()
    if flags.cmd and (keyCode == hs.keycodes.map.w or keyCode == hs.keycodes.map.q) then
      closeFocusPendingAt = lastInputTime
      if keyCode == hs.keycodes.map.w then
        focusPreviousApplicationAfterClose()
      end
    else
      closeFocusPendingAt = nil
    end
  end
  return false
end

local function windowFocused(window, applicationName)
  rememberFocus(window)
  local now = hs.timer.absoluteTime()
  local recentKeyboard = lastInputKind == "keyboard"
    and lastInputTime
    and now - lastInputTime <= keyboardFreshnessNanoseconds
  local recentClose = closeFocusPendingAt and now - closeFocusPendingAt <= closeFocusFreshnessNanoseconds
  closeFocusPendingAt = nil

  if not recentKeyboard and not recentClose then
    return
  end
  render(window, applicationName)
end

function focusIndicator.show(window, applicationName)
  render(window or hs.window.focusedWindow(), applicationName)
end

function focusIndicator.start(options)
  if inputTap then
    return focusIndicator
  end

  options = options or {}
  for _, bundleID in ipairs(options.closeFocusBundleIDs or {}) do
    closeFocusBundleIDs[bundleID] = true
  end

  rememberFocus(hs.window.focusedWindow())
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
