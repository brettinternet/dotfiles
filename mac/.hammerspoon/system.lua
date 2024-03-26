-- Power states

local function systemSleep()
  hs.caffeinate.systemSleep()
end

hs.hotkey.bind(nil, "f15", systemSleep)

-- Menu bar icon caffeine toggle

local function allowCaffeine()
  local noBurnInPls = hs.screen.find("Dell AW3423DW")
  return not noBurnInPls
end

local shouldCaffeinate = false
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
  hs.caffeinate.set("displayIdle", keepAwake, true)
  setCaffeineDisplay(keepAwake)
end

local function toggleCaffeine()
  shouldCaffeinate = not shouldCaffeinate
  setCaffeine(shouldCaffeinate)
end

hs.hotkey.bind(nil, "f14", toggleCaffeine)

if caffeineMenu then
  caffeineMenu:setClickCallback(toggleCaffeine)
  setCaffeine(shouldCaffeinate)
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
    setCaffeine(shouldCaffeinate)
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
