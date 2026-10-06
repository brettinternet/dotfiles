-- Focus the real browser, but use the opt-in launcher for a cold start.
return function(bundleID)
  if bundleID == "org.chromium.Chromium" then
    local app = hs.application.get(bundleID)
    local launcher = os.getenv("HOME") .. "/Applications/Chromium Default.app"
    if (not app or not app:isRunning()) and hs.fs.attributes(launcher, "mode") == "directory" then
      return hs.application.launchOrFocus(launcher)
    end
  end
  return hs.application.launchOrFocusByBundleID(bundleID)
end
