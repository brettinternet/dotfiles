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
  playKey = hs.eventtap.event.newKeyEvent(nil, "space", true)
  playKey:post(spotify)
end

local focusingSpotify = false
local spotifyPressReleased = true
local function longPressSpotify()
  local spotify = hs.application.get(spotifyBundleID)
  if spotify and focusingSpotify and spotifyPressReleased then
    if spotify:isFrontmost() then
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

-- Play/Pause YouTube

local function openBrowserTab(browser, url)
  local script = ([[(function() {
    var browser = Application('%s');
    browser.activate();
    var tabIndex;

    for (win of browser.windows()) {
      tabIndex = win.tabs().findIndex(tab => tab.url().match(/%s/));
      if (tabIndex !== -1) {
        win.activeTabIndex = (tabIndex + 1);
        win.index = 1;
        break;
      }
    }
    return tabIndex;
  })();
  ]]):format(browser, url)
  return hs.osascript.javascript(script)
end

local function openNewBrowserWindow(browser, url)
  local script = ([[(function() {
    var browser = Application('%s');
    browser.activate();
    browser.Window().make();
    browser.windows[0].tabs[0].url = '%s';
  })();
  ]]):format(browser, url)
  return hs.osascript.javascript(script)
end

function playPauseOrOpenYoutube()
  local currentApp = hs.application.frontmostApplication()
  local browser = "com.google.Chrome"
  local chrome = hs.application.get(browser)
  local success, tabIndex = openBrowserTab(browser, "youtube.com")
  if success then
    if tabIndex > -1 then
      local playKey = hs.eventtap.event.newKeyEvent(nil, "k", true)
      playKey:post(chrome)
    else
      local success = openNewBrowserWindow(browser, "https://youtube.com")
      if success then
        hs.application.launchOrFocusByBundleID(browser)
      end
    end
  end
  currentApp:activate()
end

hs.hotkey.bind(nil, "f19", playPauseOrOpenYoutube)
