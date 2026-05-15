-- Useful for actions with Stream Deck or macropad (without hotkeys)
-- localhost GET requests to run actions in background

local actions = {
  ["/reload"] = hs.reload,
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
    local browser = "org.chromium.Chromium"
    local success, windowId = openBrowserTab(browser, "outlook.office.com")
    if success and windowId then
      hs.application.get(browser):activate()
    else
      local success = openNewBrowserWindow(browser, "https://outlook.office.com/mail")
      if success then
        local chrome = hs.application.get(browser)
        chrome:activate()
      end
    end
  end,
  ["/calendar/work"] = function()
    openDisposableBrowserWindow("org.chromium.Chromium", "https://pdq-hq.slack.com/archives/D03JDATJ7D5")
    hs.application.get("com.tinyspeck.slackmacgap"):activate()
  end,
  ["/calendar/personal"] = getLaunchFocusOrHideAndSwitchBackFn("com.apple.iCal", true),
  ["/claude"] = getLaunchFocusOrHideAndSwitchBackFn("com.anthropic.claudefordesktop"),
}

if streamDeckHttpServer then
  streamDeckHttpServer:stop()
end

streamDeckHttpServer = hs.httpserver.new(false, false)

streamDeckHttpServer:setInterface("localhost")
streamDeckHttpServer:setPort(1337)

streamDeckHttpServer:setCallback(function(method, path)
  if method ~= "GET" then
    return "", 405, {}
  end
  local action = actions[path]
  if action ~= nil then
    local ok, err = pcall(action)
    if not ok then
      return tostring(err), 500, {}
    end
    return "", 204, {}
  end
  return "", 404, {}
end)

streamDeckHttpServer:start()
