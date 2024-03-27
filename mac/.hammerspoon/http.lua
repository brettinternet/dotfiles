-- Useful for actions with Stream Deck or macropad (without hotkeys)
-- localhost GET requests to run actions in background

lastApp = nil
local function getLaunchFocusOrHideAndSwitchBackFn(bundleid)
  return function()
    currentApp = hs.application.frontmostApplication()
    if lastApp and currentApp and (currentApp:bundleID() == bundleid) then
      currentApp:hide()
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

local actions = {
  ["/chrome"] = getLaunchFocusOrHideAndSwitchBackFn("com.google.Chrome"),
  ["/spotify"] = getLaunchFocusOrHideAndSwitchBackFn("com.spotify.client"),
  ["/zoom"] = getLaunchFocusOrHideAndSwitchBackFn("us.zoom.xos"),
  ["/obs"] = getLaunchFocusOrHideAndSwitchBackFn("com.obsproject.obs-studio"),
  ["/homeassistant"] = getLaunchFocusOrHideAndSwitchBackFn("io.robbie.HomeAssistant"),
  ["/slack"] = getLaunchFocusOrHideAndSwitchBackFn("com.tinyspeck.slackmacgap"),
  ["/discord"] = getLaunchFocusOrHideAndSwitchBackFn("com.hnc.Discord"),
  ["/messages"] = getLaunchFocusOrHideAndSwitchBackFn("com.apple.MobileSMS"),
  ["/play_pause_youtube"] = playPauseOrOpenYoutube,
}

local server = hs.httpserver.new(false)

server:setInterface("localhost")
server:setPort(1337)

server:setCallback(function (method, path)
  if method ~= "GET" then
    return "", 405, {}
  end
  local action = actions[path]
  if action ~= nil then
    action()
    return "OK", 204, {}
  end
  return "", 404, {}
end)

server:start()
