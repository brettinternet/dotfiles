package.path = (arg[0]:match("(.*/)") or "") .. "../?.lua;" .. package.path
local running = false
local installed = true
local launched
local launchResult = true
hs = {
  application = {
    get = function()
      return running and {
        isRunning = function()
          return true
        end,
      } or nil
    end,
    launchOrFocus = function(path)
      launched = path
      return launchResult
    end,
    launchOrFocusByBundleID = function(id)
      launched = id
      return true
    end,
  },
  fs = {
    attributes = function()
      return installed and "directory" or nil
    end,
  },
}
local launch = require("launch_application")
assert(launch("org.chromium.Chromium"))
assert(launched == os.getenv("HOME") .. "/Applications/Chromium Default.app")
launchResult = false
assert(not launch("org.chromium.Chromium"), "failed wrapper must not fall back to an unflagged browser")
running = true
assert(launch("org.chromium.Chromium"))
assert(launched == "org.chromium.Chromium", "focus the running browser, not the short-lived wrapper")
running = false
installed = false
assert(launch("org.chromium.Chromium"))
assert(launched == "org.chromium.Chromium", "machines without the opt-in keep their existing behavior")
installed = true
assert(launch("com.apple.Safari"))
assert(launched == "com.apple.Safari", "other applications must not be redirected")
print("launch application tests passed")
