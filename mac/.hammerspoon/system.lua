-- Power states

function systemSleep()
  hs.caffeinate.systemSleep()
end

hs.hotkey.bind(nil, "f15", systemSleep)

-- Sleep displays and then wake, (so if another active input is available, monitor switches to that)
local userActivityId = nil
function bounceDisplays()
  hs.execute("pmset displaysleepnow")
  hs.timer.doAfter(10, function()
    userActivityId = hs.caffeinate.declareUserActivity(userActivityId)
  end)
end

hs.hotkey.bind(nil, "f16", bounceDisplays)

-- Menu bar icon caffeine toggle

local function allowCaffeine()
  local noBurnInPls = hs.screen.find("Dell AW3423DW")
  return not noBurnInPls
end

local sleepType = "displayIdle"
local isCaffeinate = hs.caffeinate.get(sleepType)
local caffeineMenu = hs.menubar.new()

local function setCaffeineDisplay(keepAwake)
  if keepAwake then
    caffeineMenu:setTitle("😳")
  else
    caffeineMenu:setTitle("😴")
  end
end

local function setCaffeine(keepAwake)
  keepAwake = allowCaffeine() and keepAwake
  hs.caffeinate.set(sleepType, keepAwake, true)
  setCaffeineDisplay(keepAwake)
end

local function toggleCaffeine()
  isCaffeinate = not isCaffeinate
  setCaffeine(isCaffeinate)
end

hs.hotkey.bind(nil, "f14", toggleCaffeine)

if caffeineMenu then
  caffeineMenu:setClickCallback(toggleCaffeine)
  setCaffeine(isCaffeinate)
end

-- Watch screen lock to disable caffeine

local powerWatcher = hs.caffeinate.watcher
local log = hs.logger.new("caffeineMenu", 'verbose')

-- https://github.com/Hammerspoon/hammerspoon/issues/2314#issuecomment-594277092
local function onPower(event)
  local name = nil
  for key,val in pairs(powerWatcher) do
    if event == val then name = key end
  end
  log.f("caffeinate event %d => %s", event, name)
  if event == powerWatcher.screensDidUnlock
    or event == powerWatcher.screensaverDidStop
  then
    log.i("Screen awakened!")
    -- Restore Caffeinated state:
    setCaffeine(isCaffeinate)
    return
  end
  if event == powerWatcher.screensDidLock
    or event == powerWatcher.screensaverDidStart
  then
    log.i("Screen locked.")
    setCaffeine(false)
    return
  end
end

powerWatcher.new(onPower):start()
log.i("Started.")
