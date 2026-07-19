local caffeine = {}

local batteryThreshold = 20
local idleType = "displayIdle"
local subscribers = {}
local override = false
local overrideAlert = nil
local lastDisabledReason = nil
local menubar = nil
local watchers = {}

local function disabledReason()
  local reasons = {}

  if #hs.screen.allScreens() ~= 1 then
    table.insert(reasons, "multiple displays")
  end

  local batteryPercentage = hs.battery.percentage()
  if batteryPercentage and batteryPercentage < batteryThreshold then
    table.insert(reasons, "battery below " .. batteryThreshold .. "%")
  end

  if #reasons > 0 then
    return table.concat(reasons, " and ")
  end
end

function caffeine.isEnabled()
  return hs.caffeinate.get(idleType)
end

local function updateMenubar()
  if not menubar then
    return
  end

  if caffeine.isEnabled() then
    menubar:setTitle("Awake")
    menubar:setTooltip("Display sleep is disabled")
  else
    menubar:setTitle("Sleep")
    menubar:setTooltip("Display sleep is allowed")
  end
end

local function notify()
  updateMenubar()
  for _, subscriber in ipairs(subscribers) do
    local ok, message = pcall(subscriber, caffeine.isEnabled())
    if not ok then
      print("Caffeine subscriber failed: " .. tostring(message))
    end
  end
end

local function closeOverrideAlert()
  if overrideAlert then
    hs.alert.closeSpecific(overrideAlert)
    overrideAlert = nil
  end
end

local function clearOverride()
  override = false
  closeOverrideAlert()
end

local function showOverride(reason)
  closeOverrideAlert()
  overrideAlert = hs.alert.show("CAFFEINE OVERRIDE ACTIVE\n" .. reason, true)
end

function caffeine.isOverrideActive()
  return overrideAlert ~= nil
end

function caffeine.dismissOverride()
  if not overrideAlert then
    return false
  end
  closeOverrideAlert()
  notify()
  return true
end

local function applyState(enabled)
  if caffeine.isEnabled() ~= enabled then
    local result = hs.caffeinate.toggle(idleType)
    if result ~= enabled then
      error("failed to set display idle prevention")
    end
  end
end

function caffeine.setEnabled(enabled, allowOverride)
  if not enabled then
    applyState(false)
    clearOverride()
    notify()
    return false
  end

  local reason = disabledReason()
  if reason and not allowOverride then
    applyState(false)
    clearOverride()
    notify()
    hs.alert.show("Caffeine disabled: " .. reason)
    return false
  end

  applyState(true)
  if reason then
    override = true
    lastDisabledReason = reason
    showOverride(reason)
  else
    clearOverride()
  end
  notify()
  return true
end

function caffeine.toggle()
  return caffeine.setEnabled(not caffeine.isEnabled(), true)
end

function caffeine.subscribe(callback)
  table.insert(subscribers, callback)
  return caffeine
end

local function enforceAllowed()
  local reason = disabledReason()
  if reason and reason ~= lastDisabledReason then
    local wasEnabled = caffeine.isEnabled()
    caffeine.setEnabled(false)
    if wasEnabled then
      hs.alert.show("Caffeine disabled: " .. reason)
    end
  elseif not reason and override then
    clearOverride()
    notify()
  end
  lastDisabledReason = reason
end

function caffeine.start()
  if menubar then
    return caffeine
  end

  menubar = hs.menubar.new()
  menubar:setClickCallback(caffeine.toggle)

  watchers.screen = hs.screen.watcher.new(enforceAllowed):start()
  watchers.battery = hs.battery.watcher.new(enforceAllowed):start()
  watchers.sleep = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemWillSleep then
      caffeine.setEnabled(false)
    end
  end):start()

  enforceAllowed()
  updateMenubar()
  return caffeine
end

return caffeine
