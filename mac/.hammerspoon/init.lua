-- https://developer.okta.com/blog/2020/10/22/set-up-a-mute-indicator-light-for-zoom-with-hammerspoon
-- http://peterhajas.com/blog/streamdeck.html
-- https://github.com/peterhajas/dotfiles/blob/master/hammerspoon/.hammerspoon/streamdeck/peek.lua
-- https://github.com/arkag/hammerspoon-config/blob/master/init.lua
-- https://github.com/levinine/hammerspoon-config/blob/main/window-management.lua
-- https://github.com/arkag/hammerspoon-config/blob/master/init.lua

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

local holdingToTalk = false
local pushToTalk = function()
  holdingToTalk = true
  local audio = hs.audiodevice.defaultInputDevice()
  local muted = audio:inputMuted()
  if muted then
    audio:setInputMuted(false)
  end
end

local toggleMute = function()
  local audio = hs.audiodevice.defaultInputDevice()
  local muted = audio:inputMuted()
  audio:setInputMuted(not muted)
end

local muteNotification = nil
local toggleMuteOrPTT = function()
  local audio = hs.audiodevice.defaultInputDevice()
  local muted = audio:inputMuted()
  local muting = not muted
  if holdingToTalk then
    holdingToTalk = false
    audio:setInputMuted(true)
    muting = true
  else
    audio:setInputMuted(muting)
    if muteAlertId then
      hs.alert.closeSpecific(muteAlertId)
    end
  end
  if muteNotification then
    muteNotification:withdraw()
  end
  -- TODO: set notification image
  -- https://www.hammerspoon.org/docs/hs.image.html
  -- https://www.hammerspoon.org/docs/hs.notify.html#contentImage
  if muting then
    muteNotification = hs.notify.new(toggleMute, {
      title = "Muted",
      autoWithdraw = false,
      withdrawAfter = 0
    })
    muteNotification:send()
    -- muteAlertId = hs.alert.show("Muted")
  else
    muteNotification = hs.notify.new(toggleMute, {
      title = "Not muted"
    })
    muteNotification:send()
    -- muteAlertId = hs.alert.show("Unmuted")
  end
end

hs.hotkey.bind({"cmd", "shift"}, "a", nil, toggleMuteOrPTT, pushToTalk)
hs.hotkey.bind(nil, "f19", nil, toggleMute)

-- A more specific play/pause to only toggle Spotify

local spotifyBundleID = "com.spotify.client"
local playSpotify = function()
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
local focusSpotify = function()
  focusingSpotify = true
end

-- On long key press, focus spotify unless already focused, then hide
-- On shot key press, play or pause Spotify
local playOrPauseSpotify = function()
  local spotify = hs.application.get(spotifyBundleID)
  if spotify and focusingSpotify then
    focusingSpotify = false
    if spotify:isFrontmost() then
      spotify:hide()
    else
      hs.application.launchOrFocusByBundleID(spotifyBundleID)
    end
  else
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
end

hs.hotkey.bind(nil, "f20", nil, playOrPauseSpotify, focusSpotify)
