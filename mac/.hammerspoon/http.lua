-- Useful for actions with Stream Deck or macropad (without hotkeys)
-- localhost GET requests to run actions in background

local actions = {
  ["/reload"] = hs.reload,
  ["/chrome"] = getLaunchFocusOrHideAndSwitchBackFn("com.google.Chrome"),
  ["/spotify"] = getLaunchFocusOrHideAndSwitchBackFn("com.spotify.client"),
  ["/zoom"] = getLaunchFocusOrHideAndSwitchBackFn("us.zoom.xos"),
  ["/obs"] = getLaunchFocusOrHideAndSwitchBackFn("com.obsproject.obs-studio"),
  ["/homeassistant"] = getLaunchFocusOrHideAndSwitchBackFn("io.robbie.HomeAssistant"),
  ["/slack"] = getLaunchFocusOrHideAndSwitchBackFn("com.tinyspeck.slackmacgap"),
  ["/discord"] = getLaunchFocusOrHideAndSwitchBackFn("com.hnc.Discord"),
  ["/messages"] = getLaunchFocusOrHideAndSwitchBackFn("com.apple.MobileSMS"),
  ["/play_pause_youtube"] = playPauseOrOpenYoutube,
  ["/bounce_displays"] = bounceDisplays,
  ["/sleep"] = systemSleep,
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
