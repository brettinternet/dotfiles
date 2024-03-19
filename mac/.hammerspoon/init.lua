-- https://www.hammerspoon.org/Spoons/SpoonInstall.html
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true

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

-- Applications
prefix:bind('', 'W', prefixFn(function() launchFocusOrSwitchBack("com.google.Chrome") end))
prefix:bind('', 'S', prefixFn(function() launchFocusOrSwitchBack("com.spotify.client") end))
prefix:bind('', 'F', prefixFn(function() launchFocusOrSwitchBack("com.apple.finder") end))
prefix:bind('', 'C', prefixFn(function() launchFocusOrSwitchBack("com.microsoft.VSCode") end))
prefix:bind('', 'X', prefixFn(function() launchFocusOrSwitchBack("com.googlecode.iterm2") end))
prefix:bind('', 'A', prefixFn(function() launchFocusOrSwitchBack("com.tinyspeck.slackmacgap") end))
prefix:bind('', 'D', prefixFn(function() launchFocusOrSwitchBack("com.hnc.Discord") end))

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


-- A better push to talk / toggle mute
function clearMuteAlert()
  if muteAlertId then
    hs.alert.closeSpecific(muteAlertId)
  end
end

local holdingToTalk = false
local function pushToTalk()
  holdingToTalk = true
  local audio = hs.audiodevice.defaultInputDevice()
  local muted = audio:inputMuted()
  if muted then
    clearMuteAlert()
    muteAlertId = hs.alert.show("🎤 Microphone on", true)
    audio:setInputMuted(false)
  end
end

local function toggleMute()
  local audio = hs.audiodevice.defaultInputDevice()
  local muted = audio:inputMuted()
  audio:setInputMuted(not muted)
end

local function toggleMuteOrPTT()
  local audio = hs.audiodevice.defaultInputDevice()
  local muted = audio:inputMuted()
  local muting = not muted
  if holdingToTalk then
    holdingToTalk = false
    audio:setInputMuted(true)
    muting = true
  else
    audio:setInputMuted(muting)
  end
  clearMuteAlert()
  if muting then
    muteAlertId = hs.alert.show("📵 Microphone muted")
  else
    muteAlertId = hs.alert.show("🎤 Microphone on")
  end
end

hs.hotkey.bind({"cmd", "shift"}, "a", nil, toggleMuteOrPTT, pushToTalk)
hs.hotkey.bind(nil, "f19", nil, toggleMute)


-- A more specific play/pause to only toggle Spotify

local spotifyBundleID = "com.spotify.client"
local function playSpotify()
  local spotify = hs.application.get(spotifyBundleID)
  -- No other way to check if app is in "background" state (closed but not quit)
  -- `newKeyEvent` only works on apps that are hidden or open 🤔
  local isBackgroundOrClosed = not (spotify and spotify:focusedWindow())
  if isBackgroundOrClosed then
    hs.application.launchOrFocusByBundleID(spotifyBundleID)
    spotify = hs.application.get(spotifyBundleID)
    spotify:hide()
  end
  playKey = hs.eventtap.event.newKeyEvent(nil, "space", true)
  playKey:post(spotify)
end

local focusingSpotify = false
local spotifyPressReleased = true
local function longPressSpotify()
  local spotify = hs.application.get(spotifyBundleID)
  if spotify and focusingSpotify and spotifyPressReleased then
    if spotify:isFrontmost() then
      spotify:hide()
    else
      hs.application.launchOrFocusByBundleID(spotifyBundleID)
    end
    spotifyPressReleased = false
  end
  focusingSpotify = true
end

-- On long key press, focus spotify unless already focused, then hide
-- On shot key press, play or pause Spotify
local function playOrPauseSpotify()
  local spotify = hs.application.get(spotifyBundleID)
  if not focusingSpotify then
    local isSpotifyRunning = spotify ~= nil and spotify:isRunning() or false
    if isSpotifyRunning then
      playSpotify()
    else
      local currentApp = hs.application.frontmostApplication()
      hs.application.open(spotifyBundleID)
      currentApp:activate()
      hs.timer.doAfter(1, playSpotify)
      currentApp:activate()
    end
  end
  focusingSpotify = false
  spotifyPressReleased = true
end

hs.hotkey.bind(nil, "f20", nil, playOrPauseSpotify, longPressSpotify)
prefix:bind('', '/', prefixFn(playOrPauseSpotify))


-- Change audio output
local function toggleAudioOutput()
  local current = hs.audiodevice.defaultOutputDevice()
  local speakers = hs.audiodevice.findOutputByName('Stone Pro Audio')
  local headphones = hs.audiodevice.findOutputByName('Elgato Wave XLR')

  if toggleAudioOutputAlertID then
    hs.alert.closeSpecific(toggleAudioOutputAlertID)
  end
  if current:name() == speakers:name() then
    headphones:setDefaultOutputDevice()
    toggleAudioOutputAlertID = hs.alert.show(headphones:name())
  else
    speakers:setDefaultOutputDevice()
    toggleAudioOutputAlertID = hs.alert.show(speakers:name())
  end
end

prefix:bind('', ']', prefixFn(toggleAudioOutput))


-- Reload config on change
local home = os.getenv("HOME")
hs.pathwatcher.new(home .. "/.dotfiles/mac/.hammerspoon/", function() hs.reload() end):start()
hs.alert.show("Hammerspoon config loaded")
