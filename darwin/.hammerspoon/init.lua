-- Todo: modify https://github.com/dbalatero/SkyRocket.spoon

-- https://www.hammerspoon.org/Spoons/SpoonInstall.html
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true

hs.ipc.cliInstall()

-- Print helper
function dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k, v in pairs(o) do
      if type(k) ~= 'number' then k = '"' .. k .. '"' end
      s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
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


hs.loadSpoon("AClock")
hs.hotkey.bind({ "cmd", "ctrl" }, "z", function()
  spoon.AClock.textSize = 300
  spoon.AClock.width = 960
  spoon.AClock.height = 690
  spoon.AClock.textFont = "Fira Code"
  spoon.AClock.textColor = hs.drawing.color.hammerspoon.black
  spoon.AClock:toggleShow()
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
