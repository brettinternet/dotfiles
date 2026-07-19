local loaded, streamdeck = pcall(require, "streamdeck")
if not loaded then
  print("Stream Deck integration unavailable")
  return
end

local caffeine = require("caffeine")

-- Add new button action modules to this list. Actions return plain definitions and
-- do not register themselves, which keeps their behavior testable and reusable.
local applicationAction = require("application")
local actions = {
  (require("keep-awake")),
  (require("caffeine-alert")),
  applicationAction,
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
local relevantApplicationEvents = {
  [hs.application.watcher.activated] = true,
  [hs.application.watcher.deactivated] = true,
  [hs.application.watcher.hidden] = true,
  [hs.application.watcher.unhidden] = true,
  [hs.application.watcher.launched] = true,
  [hs.application.watcher.terminated] = true,
}

local applicationWatcher = hs.application.watcher.new(function(_name, event, _application)
  if relevantApplicationEvents[event] then
    streamdeck.refresh(applicationAction.id)
  end
end)
applicationWatcher:start()

streamdeck.start()
