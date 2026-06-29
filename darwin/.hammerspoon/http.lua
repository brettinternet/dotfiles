-- Useful for actions with Stream Deck or macropad (without hotkeys)
-- localhost GET requests to run actions in background

local actions = {
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
  ["/youtube"] = focusYoutube,
  ["/youtube/home"] = function() openYoutubeLocation("https://www.youtube.com", "youtube\\.com/?$") end,
  ["/youtube/subscriptions"] = function() openYoutubeLocation("https://www.youtube.com/feed/subscriptions", "youtube\\.com/feed/subscriptions") end,
  ["/youtube/history"] = function() openYoutubeLocation("https://www.youtube.com/feed/history", "youtube\\.com/feed/history") end,
  ["/youtube/watch_later"] = function() openYoutubeLocation("https://www.youtube.com/playlist?list=WL", "youtube\\.com/playlist\\?list=WL") end,
  ["/youtube/playlists"] = function() openYoutubeLocation("https://www.youtube.com/feed/playlists", "youtube\\.com/feed/playlists") end,
  ["/youtube/shorts"] = function() openYoutubeLocation("https://www.youtube.com/shorts", "youtube\\.com/shorts") end,
  ["/youtube/trending"] = function() openYoutubeLocation("https://www.youtube.com/feed/trending", "youtube\\.com/feed/trending") end,
  ["/youtube/music"] = function() openYoutubeLocation("https://music.youtube.com", "music\\.youtube\\.com") end,
  ["/youtube/play_pause"] = playPauseOrOpenYoutube,
  ["/youtube/next"] = function() youtubeShortcut("next") end,
  ["/youtube/previous"] = function() youtubeShortcut("previous") end,
  ["/youtube/rewind"] = function() youtubeShortcut("rewind") end,
  ["/youtube/forward"] = function() youtubeShortcut("forward") end,
  ["/youtube/mute"] = function() youtubeShortcut("mute") end,
  ["/youtube/captions"] = function() youtubeShortcut("captions") end,
  ["/youtube/fullscreen"] = function() youtubeShortcut("fullscreen") end,
  ["/youtube/theater"] = function() youtubeShortcut("theater") end,
  ["/youtube/miniplayer"] = function() youtubeShortcut("miniplayer") end,
  ["/youtube/volume_up"] = function() youtubeShortcut("volume_up") end,
  ["/youtube/volume_down"] = function() youtubeShortcut("volume_down") end,
  ["/youtube/speed_up"] = function() youtubeShortcut("speed_up") end,
  ["/youtube/speed_down"] = function() youtubeShortcut("speed_down") end,
  ["/youtube/frame_next"] = function() youtubeShortcut("frame_next") end,
  ["/youtube/frame_previous"] = function() youtubeShortcut("frame_previous") end,
  ["/youtube/beginning"] = function() youtubeShortcut("beginning") end,
  ["/youtube/seek_10"] = function() youtubeShortcut("seek_10") end,
  ["/youtube/seek_20"] = function() youtubeShortcut("seek_20") end,
  ["/youtube/seek_30"] = function() youtubeShortcut("seek_30") end,
  ["/youtube/seek_40"] = function() youtubeShortcut("seek_40") end,
  ["/youtube/seek_50"] = function() youtubeShortcut("seek_50") end,
  ["/youtube/seek_60"] = function() youtubeShortcut("seek_60") end,
  ["/youtube/seek_70"] = function() youtubeShortcut("seek_70") end,
  ["/youtube/seek_80"] = function() youtubeShortcut("seek_80") end,
  ["/youtube/seek_90"] = function() youtubeShortcut("seek_90") end,
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

local function responseHeaders(extra)
  local headers = {
    ["Cache-Control"] = "no-store",
    ["Content-Type"] = "text/plain; charset=utf-8",
    ["X-Content-Type-Options"] = "nosniff",
  }

  if extra then
    for key, value in pairs(extra) do
      headers[key] = value
    end
  end

  return headers
end

local function requestHeader(headers, name)
  if type(headers) ~= "table" then
    return nil
  end

  local lowerName = name:lower()
  for key, value in pairs(headers) do
    if type(key) == "string" and key:lower() == lowerName then
      return value
    end
  end

  return nil
end

local function isBrowserCrossOriginRequest(headers)
  if requestHeader(headers, "Origin") or requestHeader(headers, "Referer") then
    return true
  end

  local fetchSite = requestHeader(headers, "Sec-Fetch-Site")
  return fetchSite ~= nil and fetchSite ~= "none" and fetchSite ~= "same-origin"
end

streamDeckHttpServer = hs.httpserver.new(false, false)

streamDeckHttpServer:setInterface("localhost")
streamDeckHttpServer:setPort(1337)

streamDeckHttpServer:setCallback(function(method, path, headers)
  if method ~= "GET" then
    return "", 405, responseHeaders({ ["Allow"] = "GET" })
  end

  if isBrowserCrossOriginRequest(headers) then
    return "", 403, responseHeaders()
  end

  local action = actions[path]
  if action ~= nil then
    local ok, err = pcall(action)
    if not ok then
      return tostring(err), 500, responseHeaders()
    end
    return "", 204, responseHeaders()
  end
  return "", 404, responseHeaders()
end)

streamDeckHttpServer:start()
