-- Todo: modify https://github.com/dbalatero/SkyRocket.spoon

-- https://www.hammerspoon.org/Spoons/SpoonInstall.html
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true

-- Print helper
function dump(o)
  if type(o) == 'table' then
     local s = '{ '
     for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump(v) .. ','
     end
     return s .. '} '
  else
     return tostring(o)
  end
end

-- Prefix modal for app/system commands

prefix = hs.hotkey.modal.new('cmd', ';')
prefix:bind('', "escape", function() prefix:exit() end)
lastApp = nil

function prefix:entered()
  commandModeAlert = hs.alert.show("Command mode", true)
end

function prefix:exited()
  hs.alert.closeSpecific(commandModeAlert)
end

function prefixFn(fn)
  return function()
    fn()
    prefix:exit()
  end
end

local function launchFocusOrSwitchBack(bundleid)
  return function()
    currentApp = hs.application.frontmostApplication()
    if lastApp and currentApp and (currentApp:bundleID() == bundleid) then
      lastApp:activate(true)
    else
      hs.application.launchOrFocusByBundleID(bundleid)
    end
    lastApp = currentApp

    -- Center mouse on Window after focus or switch occurs
    currentWindow = hs.window.focusedWindow()
    currentFrame = currentWindow:frame()
    cfx = currentFrame.x + (currentFrame.w / 2)
    cfy = currentFrame.y + (currentFrame.h / 2)
    cfp = hs.geometry.point(cfx, cfy)
    hs.mouse.absolutePosition(cfp)
  end
end

-- Applications
prefix:bind('', 'B', prefixFn(launchFocusOrSwitchBack("com.google.Chrome")))
prefix:bind('', 'S', prefixFn(launchFocusOrSwitchBack("com.spotify.client")))
prefix:bind('', 'F', prefixFn(launchFocusOrSwitchBack("com.apple.finder")))
prefix:bind('', 'C', prefixFn(launchFocusOrSwitchBack("com.microsoft.VSCode")))
prefix:bind('', 'X', prefixFn(launchFocusOrSwitchBack("com.googlecode.iterm2")))
prefix:bind('', 'A', prefixFn(launchFocusOrSwitchBack("com.tinyspeck.slackmacgap")))
prefix:bind('', 'D', prefixFn(launchFocusOrSwitchBack("com.hnc.Discord")))
prefix:bind('', 'Z', prefixFn(launchFocusOrSwitchBack("us.zoom.xos")))
prefix:bind('', 'O', prefixFn(launchFocusOrSwitchBack("com.obsproject.obs-studio")))
prefix:bind('', 'H', prefixFn(launchFocusOrSwitchBack("io.robbie.HomeAssistant")))

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
hs.hotkey.bind({"alt", "cmd", "shift"}, "V", function()
  hs.eventtap.keyStrokes(hs.pasteboard.getContents())
end)


hs.loadSpoon("AClock")
hs.hotkey.bind({"cmd", "ctrl"}, "z", function()
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
hs.pathwatcher.new(home .. "/.dotfiles/mac/.hammerspoon/", function() hs.reload() end):start()
hs.alert.show("Hammerspoon config loaded")
