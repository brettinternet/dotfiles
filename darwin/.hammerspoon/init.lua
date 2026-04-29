-- Todo: modify https://github.com/dbalatero/SkyRocket.spoon

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function ensureSpoonInstall()
  local spoonDir = hs.configdir .. "/Spoons"
  local spoonPath = spoonDir .. "/SpoonInstall.spoon"

  if hs.fs.attributes(spoonPath, "mode") == "directory" then
    return true
  end

  hs.alert.show("Installing SpoonInstall")
  hs.fs.mkdir(spoonDir)

  local zipPath = spoonDir .. "/SpoonInstall.spoon.zip"
  local spoonInstallUrl = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpoonInstall.spoon.zip"
  local command = table.concat({
    "/usr/bin/curl -fsSL -o", shellQuote(zipPath), shellQuote(spoonInstallUrl),
    "&& /usr/bin/unzip -oq", shellQuote(zipPath), "-d", shellQuote(spoonDir),
    "&& /bin/rm -f", shellQuote(zipPath),
  }, " ")

  local _, ok = hs.execute(command, true)
  if not ok or hs.fs.attributes(spoonPath, "mode") ~= "directory" then
    hs.alert.show("SpoonInstall install failed")
    return false
  end

  return true
end

local hasSpoonInstall = ensureSpoonInstall()
if hasSpoonInstall then
  local ok = pcall(hs.loadSpoon, "SpoonInstall")
  if ok and spoon.SpoonInstall then
    spoon.SpoonInstall.use_syncinstall = true
    pcall(function()
      spoon.SpoonInstall:andUse("Caffeine", { start = true })
    end)
  else
    hs.alert.show("SpoonInstall unavailable")
  end
end

hs.ipc.cliInstall()

-- Print helper
function dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k, v in pairs(o) do
      local key = k
      if type(key) ~= 'number' then key = '"' .. key .. '"' end
      s = s .. '[' .. key .. '] = ' .. dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

-- Prefix modal for app/system commands

local prefix = hs.hotkey.modal.new('cmd', ';')
prefix:bind('', "escape", function() prefix:exit() end)

function prefix:entered()
  commandModeAlert = hs.alert.show("Command mode", true)
end

function prefix:exited()
  hs.alert.closeSpecific(commandModeAlert)
end

local function prefixFn(fn)
  return function()
    fn()
    prefix:exit()
  end
end

local lastApp = nil
function getLaunchFocusOrHideAndSwitchBackFn(bundleid, kill)
  kill = kill or false
  return function()
    currentApp = hs.application.frontmostApplication()
    if currentApp and (currentApp:bundleID() == bundleid) and not currentApp:isHidden() then
      if kill then
        currentApp:kill()
      else
        currentApp:hide()
      end
      if lastApp and lastApp.activate and currentApp ~= lastApp then
        lastApp:activate(true)
      end
    else
      hs.application.launchOrFocusByBundleID(bundleid)
      lastApp = currentApp
    end

    -- Center mouse on Window after focus or switch occurs
    currentWindow = hs.window.focusedWindow()
    if currentWindow then
      currentFrame = currentWindow:frame()
      cfx = currentFrame.x + (currentFrame.w / 2)
      cfy = currentFrame.y + (currentFrame.h / 2)
      cfp = hs.geometry.point(cfx, cfy)
      hs.mouse.absolutePosition(cfp)
    end
  end
end

-- Applications
prefix:bind('', 'F', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("org.chromium.Chromium")))
prefix:bind('', 'C', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.microsoft.VSCode")))
prefix:bind('', 'G', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.github.GitHubClient")))
prefix:bind('', 'S', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.spotify.client")))
prefix:bind('', 'E', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.apple.finder")))
prefix:bind('', 'M', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.apple.MobileSMS")))
prefix:bind('', 'V', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.vivaldi.Vivaldi")))
prefix:bind('', 'X', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.googlecode.iterm2")))
prefix:bind('', 'A', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.tinyspeck.slackmacgap")))
prefix:bind('', 'D', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.hnc.Discord")))
prefix:bind('', 'Z', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("us.zoom.xos")))
prefix:bind('', 'O', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.obsproject.obs-studio")))
prefix:bind('', 'H', prefixFn(getLaunchFocusOrHideAndSwitchBackFn("io.robbie.HomeAssistant")))

-- System
prefix:bind('cmd', 'L', prefixFn(function() hs.caffeinate.lockScreen() end))
prefix:bind('cmd', 'P', prefixFn(function() hs.caffeinate.systemSleep() end))
local caffeineBatteryThreshold = 20
local caffeineOverride = false
local caffeineOverrideAlert = nil
local caffeineLastDisabledReason = nil

local function caffeineDisabledReason()
  local reasons = {}

  if #hs.screen.allScreens() ~= 1 then
    table.insert(reasons, "multiple displays")
  end

  local batteryPercentage = hs.battery.percentage()
  if batteryPercentage and batteryPercentage < caffeineBatteryThreshold then
    table.insert(reasons, "battery below " .. caffeineBatteryThreshold .. "%")
  end

  if #reasons > 0 then
    return table.concat(reasons, " and ")
  end
end

local function caffeineAllowed()
  return caffeineDisabledReason() == nil
end

local function clearCaffeineOverride()
  caffeineOverride = false
  if caffeineOverrideAlert then
    hs.alert.closeSpecific(caffeineOverrideAlert)
    caffeineOverrideAlert = nil
  end
end

local function showCaffeineOverride(reason)
  if caffeineOverrideAlert then
    hs.alert.closeSpecific(caffeineOverrideAlert)
  end
  caffeineOverrideAlert = hs.alert.show("CAFFEINE OVERRIDE ACTIVE\n" .. reason, true)
end

local function setCaffeine(on, allowOverride)
  if not spoon.Caffeine then
    hs.alert.show("Caffeine unavailable")
    return
  end

  if not on then
    spoon.Caffeine:setState(false)
    clearCaffeineOverride()
    return
  end

  local disabledReason = caffeineDisabledReason()
  if disabledReason and not allowOverride then
    spoon.Caffeine:setState(false)
    clearCaffeineOverride()
    hs.alert.show("Caffeine disabled: " .. disabledReason)
    return
  end

  spoon.Caffeine:setState(true)
  if disabledReason then
    caffeineOverride = true
    caffeineLastDisabledReason = disabledReason
    showCaffeineOverride(disabledReason)
  else
    clearCaffeineOverride()
  end
end

local function toggleCaffeine()
  local shouldEnable = not hs.caffeinate.get("displayIdle")
  setCaffeine(shouldEnable, shouldEnable)
end

prefix:bind('cmd', 'K', prefixFn(toggleCaffeine))
local function enforceCaffeineAllowed()
  local disabledReason = caffeineDisabledReason()
  if disabledReason and disabledReason ~= caffeineLastDisabledReason then
    local wasOn = hs.caffeinate.get("displayIdle")
    setCaffeine(false)
    if wasOn then
      hs.alert.show("Caffeine disabled: " .. disabledReason)
    end
  elseif not disabledReason and caffeineOverride then
    clearCaffeineOverride()
  end
  caffeineLastDisabledReason = disabledReason
end

caffeineScreenWatcher = hs.screen.watcher.new(function()
  enforceCaffeineAllowed()
end):start()
caffeineBatteryWatcher = hs.battery.watcher.new(function()
  enforceCaffeineAllowed()
end):start()
enforceCaffeineAllowed()
prefix:bind('cmd', 'C', prefixFn(function()
  hs.pasteboard.clearContents()
  hs.alert.show("Clipboard Cleared")
end))

-- Info helpers
prefix:bind('cmd', 'B', prefixFn(function()
  hs.pasteboard.setContents(hs.application.frontmostApplication():bundleID())
  hs.alert.show("BundleID Copied")
end))
prefix:bind('cmd', 'D', prefixFn(function()
  hs.pasteboard.setContents(hs.application.frontmostApplication():title())
  hs.alert.show("Title Copied")
end))
prefix:bind('', '\\', prefixFn(function()
  hs.execute('/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay toggle -name="Dell AW3423DW" -connected')
end))

-- Utils

-- Get around paste blockers with cmd+alt+v
hs.hotkey.bind({ "alt", "cmd", "shift" }, "V", function()
  hs.eventtap.keyStrokes(hs.pasteboard.getContents())
end)

-- Load all modules

require("audio")
require("media")
require("system")
require("http")

-- Reload config on change
local home = os.getenv("HOME")
hs.pathwatcher.new(home .. "/.dotfiles/darwin/.hammerspoon/", function() hs.reload() end):start()
hs.alert.show("Hammerspoon config loaded")
