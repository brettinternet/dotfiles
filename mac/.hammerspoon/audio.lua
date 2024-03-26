-- A better push to talk / toggle mute
local function clearMuteAlert()
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
hs.hotkey.bind(nil, "f13", nil, toggleMute)
