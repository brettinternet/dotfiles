local browser = require("browser")

-- Focus the real browser, but use the opt-in launcher for a cold start.
return function(bundleID)
  if bundleID == browser.bundleID then
    local app = hs.application.get(bundleID)
    if (not app or not app:isRunning()) and hs.fs.attributes(browser.launcher, "mode") == "directory" then
      return hs.application.launchOrFocus(browser.launcher)
    end
  end
  return hs.application.launchOrFocusByBundleID(bundleID)
end
