-- Useful for actions with Stream Deck or macropad (without hotkeys)
-- localhost GET requests to run actions in background

local actions = {
  ["/reload"] = hs.reload,
  ["/chrome"] = getLaunchFocusOrHideAndSwitchBackFn("com.google.Chrome"),
  ["/spotify"] = getLaunchFocusOrHideAndSwitchBackFn("com.spotify.client"),
  ["/zoom"] = getLaunchFocusOrHideAndSwitchBackFn("us.zoom.xos"),
  ["/obs"] = getLaunchFocusOrHideAndSwitchBackFn("com.obsproject.obs-studio"),
  ["/weather"] = getLaunchFocusOrHideAndSwitchBackFn("com.apple.weather", true),
  ["/notes"] = getLaunchFocusOrHideAndSwitchBackFn("com.apple.Notes", true),
  ["/homeassistant"] = function()
    local success, windowId = openBrowserTab("com.google.Chrome", "home.gardiner")
    if success and windowId then
      hs.application.get("com.google.Chrome"):activate()
    else
      getLaunchFocusOrHideAndSwitchBackFn("io.robbie.HomeAssistant")()
    end
  end,
  ["/plex"] = function()
    local plex = hs.application.get("tv.plex.desktop")
    if plex and plex:isRunning() then
      getLaunchFocusOrHideAndSwitchBackFn("tv.plex.desktop")()
    else
      local success, windowId = openBrowserTab("com.google.Chrome", "plex.gardiner")
      if success and windowId then
        hs.application.get("com.google.Chrome"):activate()
      else
        getLaunchFocusOrHideAndSwitchBackFn("tv.plex.desktop")()
      end
    end
  end,
  ["/slack"] = getLaunchFocusOrHideAndSwitchBackFn("com.tinyspeck.slackmacgap"),
  ["/discord"] = getLaunchFocusOrHideAndSwitchBackFn("com.hnc.Discord"),
  ["/messages"] = getLaunchFocusOrHideAndSwitchBackFn("com.apple.MobileSMS"),
  ["/play_pause_youtube"] = playPauseOrOpenYoutube,
  ["/bounce_displays"] = bounceDisplays,
  ["/sleep"] = systemSleep,
  ["/outlook"] = function()
    local success, windowId = openBrowserTab("com.google.Chrome", "outlook.office.com")
    print(windowId)
    if windowId then
      hs.application.get("com.google.Chrome"):activate()
    end
  end,
  ["/calendar"] = function()
    openDisposableBrowserWindow("com.google.Chrome", "https://pdq-hq.slack.com/archives/D03JDATJ7D5")
    hs.application.get("com.tinyspeck.slackmacgap"):activate()
  end,
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
