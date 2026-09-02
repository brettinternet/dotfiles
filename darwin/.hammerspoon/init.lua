-- Todo: modify https://github.com/dbalatero/SkyRocket.spoon

hs.ipc.cliInstall()

-- Print helper
function dump(o)
  if type(o) == "table" then
    local s = "{ "
    for k, v in pairs(o) do
      local key = k
      if type(key) ~= "number" then
        key = '"' .. key .. '"'
      end
      s = s .. "[" .. key .. "] = " .. dump(v) .. ","
    end
    return s .. "} "
  else
    return tostring(o)
  end
end

-- Prefix modal for app/system commands

local prefix = hs.hotkey.modal.new("cmd", ";")
prefix:bind("", "escape", function()
  prefix:exit()
end)

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
local focusIndicator = require("focus_indicator")

local function getLaunchOrFocusFn(bundleid)
  return function()
    local currentApp = hs.application.frontmostApplication()
    local alreadyFocused = currentApp and currentApp:bundleID() == bundleid and not currentApp:isHidden()
    if not alreadyFocused then
      hs.application.launchOrFocusByBundleID(bundleid)
    end

    local currentWindow = hs.window.focusedWindow()
    if currentWindow then
      local currentFrame = currentWindow:frame()
      hs.mouse.absolutePosition(
        hs.geometry.point(currentFrame.x + currentFrame.w / 2, currentFrame.y + currentFrame.h / 2)
      )
    end

    if alreadyFocused then
      focusIndicator.show(currentWindow, currentApp:name())
    end
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
prefix:bind("", ";", prefixFn(getLaunchOrFocusFn("com.mitchellh.ghostty")))
prefix:bind("", "J", prefixFn(getLaunchOrFocusFn("org.chromium.Chromium")))
prefix:bind("", "H", prefixFn(getLaunchOrFocusFn("com.apple.finder")))
prefix:bind("", "K", prefixFn(getLaunchOrFocusFn("com.tinyspeck.slackmacgap")))
prefix:bind("", "L", prefixFn(getLaunchOrFocusFn("com.hnc.Discord")))
prefix:bind("", "C", prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.microsoft.VSCode")))
prefix:bind("", "G", prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.github.GitHubClient")))
prefix:bind("", "S", prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.spotify.client")))
prefix:bind("", "M", prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.apple.MobileSMS")))
prefix:bind("", "P", prefixFn(getLaunchFocusOrHideAndSwitchBackFn("us.zoom.xos")))
prefix:bind("", "O", prefixFn(getLaunchFocusOrHideAndSwitchBackFn("com.obsproject.obs-studio")))

-- System
prefix:bind(
  "cmd",
  "L",
  prefixFn(function()
    hs.caffeinate.lockScreen()
  end)
)
prefix:bind(
  "cmd",
  "P",
  prefixFn(function()
    hs.caffeinate.systemSleep()
  end)
)
local caffeine = require("caffeine").start()
prefix:bind("cmd", "K", prefixFn(caffeine.toggle))
prefix:bind(
  "cmd",
  "J",
  prefixFn(function()
    local systemIdlePrevention = caffeine.toggleSystemIdle() and "enabled" or "disabled"
    local displayIdlePrevention = caffeine.isEnabled() and "enabled" or "disabled"
    hs.alert.show(
      "System-idle prevention: " .. systemIdlePrevention .. "\nDisplay-idle prevention: " .. displayIdlePrevention
    )
  end)
)
local idlesim = require("idlesim")
prefix:bind(
  "cmd",
  "I",
  prefixFn(function()
    idlesim.toggle()
  end)
)
hs.shutdownCallback = function()
  idlesim.stop()
end
prefix:bind(
  "cmd",
  "C",
  prefixFn(function()
    hs.pasteboard.clearContents()
    hs.alert.show("Clipboard Cleared")
  end)
)

-- Info helpers
prefix:bind(
  "cmd",
  "B",
  prefixFn(function()
    hs.pasteboard.setContents(hs.application.frontmostApplication():bundleID())
    hs.alert.show("BundleID Copied")
  end)
)
prefix:bind(
  "cmd",
  "D",
  prefixFn(function()
    hs.pasteboard.setContents(hs.application.frontmostApplication():title())
    hs.alert.show("Title Copied")
  end)
)
prefix:bind(
  "",
  "\\",
  prefixFn(function()
    hs.execute('/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay toggle -name="Dell AW3423DW" -connected')
  end)
)

-- Utils

-- Get around paste blockers with cmd+alt+v
hs.hotkey.bind({ "alt", "cmd", "shift" }, "V", function()
  hs.eventtap.keyStrokes(hs.pasteboard.getContents())
end)

-- Keep Fn-Control-R reserved for macOS's native window command. When the
-- command is unavailable, consume the chord before the focused app sees Control-R.
local returnToPreviousSizePath = { "Window", "Move & Resize", "Return to Previous Size" }
local returnToPreviousSizeKeyCode = hs.keycodes.map.r
windowShortcutGuard = hs.eventtap
    .new({ hs.eventtap.event.types.keyDown }, function(event)
      local flags = event:getFlags()
      if
          event:getKeyCode() ~= returnToPreviousSizeKeyCode
          or not flags.fn
          or not flags.ctrl
          or flags.cmd
          or flags.alt
          or flags.shift
      then
        return false
      end

      local app = hs.application.frontmostApplication()
      local menuItem = app and app:findMenuItem(returnToPreviousSizePath)
      return not (menuItem and menuItem.enabled)
    end)
    :start()

-- Load all modules

require("audio")
require("media")
require("system")
require("http")
require("sd")
focusIndicator.start({
  closeFocusBundleIDs = {
    "com.apple.finder",
    "com.mitchellh.ghostty",
    "com.spotify.client",
    "com.tinyspeck.slackmacgap",
    "org.chromium.Chromium",
  },
})

-- Reload config on change
local home = os.getenv("HOME")
hs.pathwatcher
    .new(home .. "/.dotfiles/darwin/.hammerspoon/", function()
      hs.reload()
    end)
    :start()
hs.alert.show("Hammerspoon config loaded")
