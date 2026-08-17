local idlesim = {}

local mark = 970417
local dashboardPath = hs.configdir .. "/idlesim-dashboard"
local windowTitle = "System Monitor"
local pulseInterval = 20
local maxDuration = 3 * 60 * 60

local launchedPid = nil
local windowId = nil
local pulseTimer = nil
local inputTap = nil
local screenTap = nil
local subscribers = {}
local startedAt = nil
local menubar = nil
local burstIndex = 0

local props = hs.eventtap.event.properties

function idlesim.isRunning()
  return pulseTimer ~= nil
end

local function updateMenubar()
  if idlesim.isRunning() then
    if not menubar then
      menubar = hs.menubar.new()
      menubar:setClickCallback(idlesim.toggle)
    end
    menubar:setTitle("Sim")
    menubar:setTooltip("Simulating activity; any input stops it")
  elseif menubar then
    menubar:delete()
    menubar = nil
  end
end

local function notify()
  updateMenubar()
  for _, subscriber in ipairs(subscribers) do
    local ok, message = pcall(subscriber, idlesim.isRunning(), burstIndex)
    if not ok then
      print("Idle sim subscriber failed: " .. tostring(message))
    end
  end
end

function idlesim.subscribe(callback)
  table.insert(subscribers, callback)
  return idlesim
end

local function pulse()
  local down = hs.eventtap.event.newKeyEvent({}, "shift", true)
  down:setProperty(props.eventSourceUserData, mark)
  down:post()

  local up = hs.eventtap.event.newKeyEvent({}, "shift", false)
  up:setProperty(props.eventSourceUserData, mark)
  up:post()
end

local function simWindow()
  if not launchedPid then
    return nil
  end
  local app = hs.application.applicationForPID(launchedPid)
  if not app then
    return nil
  end
  for _, window in ipairs(app:allWindows()) do
    if window:id() == windowId or window:title() == windowTitle then
      return window
    end
  end
  return nil
end

local function pulseTick()
  if os.time() - startedAt > maxDuration then
    return idlesim.stop("timeout")
  end

  local window = simWindow()
  if not window then
    return idlesim.stop("window gone")
  end

  local app = hs.application.applicationForPID(launchedPid)
  if not app then
    return idlesim.stop("window gone")
  end
  for _, candidate in ipairs(app:allWindows()) do
    if candidate:subrole() == "AXDialog" then
      return idlesim.stop("dialog")
    end
  end

  burstIndex = burstIndex + 1
  pulse()
  notify()
end

local function startInputWatcher()
  inputTap = hs.eventtap.new({
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.flagsChanged,
    hs.eventtap.event.types.mouseMoved,
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
    hs.eventtap.event.types.scrollWheel,
  }, function(event)
    if event:getProperty(props.eventSourceUserData) == mark then
      return false
    end
    idlesim.stop("user input")
    return false
  end)
  inputTap:start()
end

function idlesim.stop(reason)
  if pulseTimer then
    pulseTimer:stop()
    pulseTimer = nil
  end
  if inputTap then
    inputTap:stop()
    inputTap = nil
  end
  if screenTap then
    screenTap:stop()
    screenTap = nil
  end

  local app = launchedPid and hs.application.applicationForPID(launchedPid)
  if app and app:bundleID() == "com.mitchellh.ghostty" then
    app:kill()
  end

  launchedPid, windowId, startedAt, burstIndex = nil, nil, nil, 0
  notify()
  if type(reason) == "string" and reason ~= "toggle" then
    hs.alert.show("Idle sim stopped: " .. reason)
  end
  return false
end

function idlesim.start()
  if idlesim.isRunning() then
    return true
  end

  local launchComplete = false
  local matchedApp = nil
  local matchedWindow = nil
  local existingPids = {}
  for _, app in ipairs(hs.application.applicationsForBundleID("com.mitchellh.ghostty")) do
    existingPids[app:pid()] = true
  end

  local task = hs.task.new("/usr/bin/open", nil, {
    "-na",
    "Ghostty",
    "--args",
    "--command=direct:" .. dashboardPath,
    "--title=" .. windowTitle,
    "--window-save-state=never",
    "--fullscreen=false",
    "--window-width=69",
    "--window-height=19",
    "--confirm-close-surface=false",
  })
  if not task or not task:start() then
    hs.alert.show("Idle sim failed to launch")
    return false
  end

  local function finishStart()
    matchedWindow:setFullScreen(false)
    matchedWindow:setSize({ w = 720, h = 440 })
    matchedWindow:centerOnScreen()
    startedAt = os.time()
    burstIndex = 0
    startInputWatcher()
    screenTap = hs.caffeinate.watcher
      .new(function(event)
        if event == hs.caffeinate.watcher.systemWillSleep then
          idlesim.stop("sleep")
        end
      end)
      :start()
    pulseTimer = hs.timer.doEvery(pulseInterval, pulseTick)
    pulseTick()
  end

  hs.timer.waitUntil(function()
    for _, app in ipairs(hs.application.applicationsForBundleID("com.mitchellh.ghostty")) do
      if not existingPids[app:pid()] then
        for _, window in ipairs(app:allWindows()) do
          if window:title() == windowTitle then
            matchedApp = app
            matchedWindow = window
            return true
          end
        end
      end
    end
    return false
  end, function()
    launchComplete = true
    launchedPid = matchedApp:pid()
    windowId = matchedWindow:id()
    finishStart()
  end, 0.3)

  hs.timer.doAfter(8, function()
    if not launchComplete then
      idlesim.stop("launch failed")
      hs.alert.show("Idle sim failed to launch")
    end
  end)

  return true
end

function idlesim.toggle()
  if idlesim.isRunning() then
    return idlesim.stop("toggle")
  end
  return idlesim.start()
end

return idlesim
