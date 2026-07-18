-- Power states

function systemSleep()
  hs.caffeinate.systemSleep()
end

hs.hotkey.bind(nil, "f15", systemSleep)

-- Sleep displays and then wake, (so if another active input is available, monitor switches to that)
local userActivityId = nil
function bounceDisplays()
  hs.execute("pmset displaysleepnow")
  hs.timer.doAfter(10, function()
    userActivityId = hs.caffeinate.declareUserActivity(userActivityId)
  end)
end

hs.hotkey.bind(nil, "f16", bounceDisplays)
