-- Useful for actions with Stream Deck or macropad (without hotkeys)
-- localhost GET requests to run actions in background

local actions = {
  ["/reload"] = hs.reload,
  ["/vivaldi"] = getLaunchFocusOrHideAndSwitchBackFn("com.vivaldi.Vivaldi"),
  ["/chrome"] = getLaunchFocusOrHideAndSwitchBackFn("org.chromium.Chromium"),
  ["/zed"] = getLaunchFocusOrHideAndSwitchBackFn("dev.zed.Zed"),
  ["/github"] = getLaunchFocusOrHideAndSwitchBackFn("com.github.GitHubClient"),
  ["/spotify"] = getLaunchFocusOrHideAndSwitchBackFn("com.spotify.client"),
  ["/zoom"] = getLaunchFocusOrHideAndSwitchBackFn("us.zoom.xos"),
  ["/obs"] = getLaunchFocusOrHideAndSwitchBackFn("com.obsproject.obs-studio"),
  ["/weather"] = getLaunchFocusOrHideAndSwitchBackFn("com.apple.weather", true),
  ["/notes"] = getLaunchFocusOrHideAndSwitchBackFn("com.apple.Notes", true),
  ["/mail"] = getLaunchFocusOrHideAndSwitchBackFn("com.apple.mail"),
  ["/slack"] = getLaunchFocusOrHideAndSwitchBackFn("com.tinyspeck.slackmacgap"),
  ["/discord"] = getLaunchFocusOrHideAndSwitchBackFn("com.hnc.Discord"),
  ["/messages"] = getLaunchFocusOrHideAndSwitchBackFn("com.apple.MobileSMS"),
  ["/homeassistant"] = function()
    local success, windowId = openBrowserTab("org.chromium.Chromium", "home.gardiner")
    if success and windowId then
      hs.application.get("org.chromium.Chromium"):activate()
    else
      getLaunchFocusOrHideAndSwitchBackFn("io.robbie.HomeAssistant")()
    end
  end,
  ["/plex"] = function()
    local plex = hs.application.get("tv.plex.desktop")
    if plex and plex:isRunning() then
      getLaunchFocusOrHideAndSwitchBackFn("tv.plex.desktop")()
    else
      local success, windowId = openBrowserTab("org.chromium.Chromium", "plex.gardiner")
      if success and windowId then
        hs.application.get("org.chromium.Chromium"):activate()
      else
        getLaunchFocusOrHideAndSwitchBackFn("tv.plex.desktop")()
      end
    end
  end,
  ["/play_pause_youtube"] = playPauseOrOpenYoutube,
  ["/bounce_displays"] = bounceDisplays,
  ["/sleep"] = systemSleep,
  ["/outlook"] = function()
    local success, windowId = openBrowserTab("org.chromium.Chromium", "outlook.office.com")
    if windowId then
      hs.application.get("org.chromium.Chromium"):activate()
    end
  end,
  ["/calendar/work"] = function()
    openDisposableBrowserWindow("org.chromium.Chromium", "https://pdq-hq.slack.com/archives/D03JDATJ7D5")
    hs.application.get("com.tinyspeck.slackmacgap"):activate()
  end,
  ["/calendar/personal"] = getLaunchFocusOrHideAndSwitchBackFn("com.apple.iCal", true),
}

local server = hs.httpserver.new(false)

server:setInterface("localhost")
server:setPort(1337)

server:setCallback(function(method, path)
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
