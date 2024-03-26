-- A better push to talk / toggle mute
local shouldCaffeinate = false
local muteMenu = hs.menubar.new()

local function setMuteDisplay(mute)
  if mute then
    muteMenu:setTitle("📵")
  else
    muteMenu:setTitle("🎤")
  end
end

local function clearMuteAlert()
  if muteAlertId then
    hs.alert.closeSpecific(muteAlertId)
  end
end

local function setMute(mute)
  local audio = hs.audiodevice.defaultInputDevice()
  audio:setInputMuted(mute)
  setMuteDisplay(mute)
end

local function getMuteState()
  local audio = hs.audiodevice.defaultInputDevice()
  return audio:inputMuted()
end

local holdingToTalk = false
local function pushToTalk()
  holdingToTalk = true
  local audio = hs.audiodevice.defaultInputDevice()
  local muted = audio:inputMuted()
  if muted then
    clearMuteAlert()
    muteAlertId = hs.alert.show("🎤 Microphone on", true)
    setMute(false)
  end
end

local function toggleMute()
  setMute(not getMuteState())
end

local function toggleMuteOrPTT()
  local muted = getMuteState()
  local muting = not muted
  if holdingToTalk then
    holdingToTalk = false
    setMute(true)
    muting = true
  else
    setMute(muting)
  end
  clearMuteAlert()
  if muting then
    muteAlertId = hs.alert.show("📵 Microphone muted")
  else
    muteAlertId = hs.alert.show("🎤 Microphone on")
  end
end

hs.hotkey.bind({"cmd", "shift"}, "a", nil, toggleMuteOrPTT, pushToTalk)
hs.hotkey.bind(nil, "f18", nil, toggleMute)

if muteMenu then
  muteMenu:setClickCallback(toggleMute)
  local muted = getMuteState()
  setMuteDisplay(muted)
end
