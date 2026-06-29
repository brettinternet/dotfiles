-- A more specific play/pause to only toggle Spotify
local spotifyBundleID = "com.spotify.client"
local function playSpotify()
  local spotify = hs.application.get(spotifyBundleID)
  -- No other way to check if app is in "background" state (closed but not quit)
  -- `newKeyEvent` only works on apps that are hidden or open 🤔
  local isBackgroundOrClosed = not (spotify and spotify:focusedWindow())
  if isBackgroundOrClosed then
    hs.application.launchOrFocusByBundleID(spotifyBundleID)
    spotify = hs.application.get(spotifyBundleID)
    spotify:hide()
  end
  local playKey = hs.eventtap.event.newKeyEvent(nil, "space", true)
  playKey:post(spotify)
end

local focusingSpotify = false
local spotifyPressReleased = true
local function longPressSpotify()
  local spotify = hs.application.get(spotifyBundleID)
  if spotify and focusingSpotify and spotifyPressReleased then
    if spotify:isFrontmost() and not spotify:isHidden() then
      spotify:hide()
    else
      hs.application.launchOrFocusByBundleID(spotifyBundleID)
    end
    spotifyPressReleased = false
  end
  focusingSpotify = true
end

-- On long key press, focus spotify unless already focused, then hide
-- On shot key press, play or pause Spotify
local function playOrPauseSpotify()
  local spotify = hs.application.get(spotifyBundleID)
  if not focusingSpotify then
    local isSpotifyRunning = spotify ~= nil and spotify:isRunning() or false
    if isSpotifyRunning then
      playSpotify()
    else
      local currentApp = hs.application.frontmostApplication()
      hs.application.open(spotifyBundleID)
      currentApp:activate()
      hs.timer.doAfter(1, playSpotify)
      currentApp:activate()
    end
  end
  focusingSpotify = false
  spotifyPressReleased = true
end

hs.hotkey.bind(nil, "f20", nil, playOrPauseSpotify, longPressSpotify)


-- Change audio output
local function toggleAudioOutput()
  local current = hs.audiodevice.defaultOutputDevice()
  local speakers = hs.audiodevice.findOutputByName('Stone Pro Audio')
  local headphones = hs.audiodevice.findOutputByName('Elgato Wave XLR')

  if toggleAudioOutputAlertID then
    hs.alert.closeSpecific(toggleAudioOutputAlertID)
  end
  if current:name() == speakers:name() then
    headphones:setDefaultOutputDevice()
    toggleAudioOutputAlertID = hs.alert.show(headphones:name())
  else
    speakers:setDefaultOutputDevice()
    toggleAudioOutputAlertID = hs.alert.show(speakers:name())
  end
end

hs.hotkey.bind(nil, "f13", toggleAudioOutput)

-- YouTube

local youtubeBrowserBundleID = "org.chromium.Chromium"
local youtubeTabPattern = "youtube\\.com|youtu\\.be"
local youtubeHomeUrl = "https://www.youtube.com"

function openBrowserTab(browser, url)
  local script = ([[(function() {
    var browser = Application('%s');

    for (win of browser.windows()) {
      var urlMatch = new RegExp('%s');
      var tabIndex = win.tabs().findIndex(tab => tab.url().match(urlMatch));
      if (tabIndex !== -1) {
        win.activeTabIndex = (tabIndex + 1);
        win.index = 1;
        return win.id();
      }
    }
  })();
  ]]):format(browser, url)
  return hs.osascript.javascript(script)
end

function openNewBrowserWindow(browser, url)
  local script = ([[(function() {
    var browser = Application('%s');
    var window = browser.Window().make();
    window.tabs[0].url = '%s';
    return window.id();
  })();
  ]]):format(browser, url)
  return hs.osascript.javascript(script)
end

local function focusBrowserTabOrOpen(browser, urlPattern, fallbackUrl)
  local success, windowId = openBrowserTab(browser, urlPattern)
  local browserApp = hs.application.get(browser)

  if success and windowId then
    if browserApp then
      browserApp:activate()
    end
    return browserApp, windowId
  end

  success = openNewBrowserWindow(browser, fallbackUrl)
  browserApp = hs.application.get(browser)
  if success and browserApp then
    browserApp:activate()
  end
  return browserApp, nil
end

local youtubeShortcuts = {
  play_pause = { key = "k" },
  next = { modifiers = { "shift" }, key = "n" },
  previous = { modifiers = { "shift" }, key = "p" },
  rewind = { key = "j" },
  forward = { key = "l" },
  mute = { key = "m" },
  captions = { key = "c" },
  fullscreen = { key = "f" },
  theater = { key = "t" },
  miniplayer = { key = "i" },
  volume_up = { key = "up" },
  volume_down = { key = "down" },
  speed_up = { modifiers = { "shift" }, key = "." },
  speed_down = { modifiers = { "shift" }, key = "," },
  frame_next = { key = "." },
  frame_previous = { key = "," },
  beginning = { key = "0" },
  seek_10 = { key = "1" },
  seek_20 = { key = "2" },
  seek_30 = { key = "3" },
  seek_40 = { key = "4" },
  seek_50 = { key = "5" },
  seek_60 = { key = "6" },
  seek_70 = { key = "7" },
  seek_80 = { key = "8" },
  seek_90 = { key = "9" },
}

function openYoutubeLocation(url, urlPattern)
  focusBrowserTabOrOpen(youtubeBrowserBundleID, urlPattern or url, url)
end

function focusYoutube()
  return focusBrowserTabOrOpen(youtubeBrowserBundleID, youtubeTabPattern, youtubeHomeUrl)
end

function youtubeShortcut(action)
  local shortcut = youtubeShortcuts[action]
  if not shortcut then
    hs.alert.show("Unknown YouTube action: " .. tostring(action))
    return false
  end

  local currentApp = hs.application.frontmostApplication()
  local browserApp, windowId = focusYoutube()
  if browserApp and windowId then
    hs.eventtap.keyStroke(shortcut.modifiers or {}, shortcut.key, 0, browserApp)
  end
  if currentApp then
    currentApp:activate()
  end
  return browserApp ~= nil and windowId ~= nil
end

function playPauseOrOpenYoutube()
  return youtubeShortcut("play_pause")
end

hs.hotkey.bind(nil, "f19", playPauseOrOpenYoutube)

function openDisposableBrowserWindow(browser, url)
  local script = ([[(function() {
    var browser = Application('%s');
    var window = browser.Window().make();
    window.tabs[0].url = '%s';
    return window.id();
  })();
  ]]):format(browser, url)
  local success, windowId = hs.osascript.javascript(script)
  if success and windowId then
    local script = ([[(function() {
      var browser = Application('%s');
      var windowId = '%s';
      for (win of browser.windows()) {
        if (win.id() === windowId) {
          win.close();
          return;
        }
      }
    })();
    ]]):format(browser, windowId)
    hs.timer.doAfter(0.5, function() hs.osascript.javascript(script) end)
  end
end
