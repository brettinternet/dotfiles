local loaded, streamdeck = pcall(require, "streamdeck")
if not loaded then
  print("Stream Deck integration unavailable")
  return
end

local caffeine = require("caffeine")

-- Add new button action modules to this list. Actions return plain definitions and
-- do not register themselves, which keeps their behavior testable and reusable.
local actions = {
  (require("keep-awake")),
  (require("meeting-mode")),
  (require("caffeine-alert")),
}

local refreshGeneration = 0

local function refreshAll()
  refreshGeneration = refreshGeneration + 1
  for _, action in ipairs(actions) do
    streamdeck.refresh(action.id)
  end
end

for _, action in ipairs(actions) do
  local press = action.press
  action.press = function(context)
    local generation = refreshGeneration
    press(context)
    if generation == refreshGeneration then
      refreshAll()
    end
  end
  streamdeck.register(action)
end

caffeine.subscribe(refreshAll)
streamdeck.start()
