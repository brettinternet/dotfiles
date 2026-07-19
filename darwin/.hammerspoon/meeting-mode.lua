local caffeine = require("caffeine")

local function defaultMicrophone()
  local microphone = hs.audiodevice.defaultInputDevice()
  if not microphone then
    return nil
  end
  return microphone
end

local function modeState()
  local microphone = defaultMicrophone()
  if not microphone then
    return nil
  end
  return microphone:inputMuted() and caffeine.isEnabled()
end

return {
  id = "com.brettinternet.hammerspoon.meeting-mode",
  name = "Meeting mode",

  appearance = function(_context)
    local enabled = modeState()
    if enabled == nil then
      return {
        title = "No mic",
        state = "inactive",
      }
    end

    if enabled then
      return {
        title = "Meeting",
        state = "active",
      }
    end

    return {
      title = "Normal",
      state = "inactive",
    }
  end,

  press = function(_context)
    local microphone = defaultMicrophone()
    if not microphone then
      error("no default input device")
    end

    local enabled = not (microphone:inputMuted() and caffeine.isEnabled())
    if not microphone:setInputMuted(enabled) then
      error("failed to set microphone mute state")
    end
    caffeine.setEnabled(enabled, true)
  end,
}
