package.path = (arg[0]:match("(.*/)") or "") .. "../?.lua;" .. package.path
local running = false
local installed = true
local launched
local launchResult = true
local launcher = os.getenv("HOME") .. "/Applications/Chromium Default.app"
hs = {
  plist = {
    read = function(path)
      assert(path == launcher .. "/Contents/Info.plist")
      return { BrowserBundleIdentifier = "com.google.Chrome" }
    end,
  },
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
assert(launch("com.google.Chrome"))
assert(launched == launcher, "the browser recorded by the launcher must use it")
launchResult = false
assert(not launch("com.google.Chrome"), "failed wrapper must not fall back to an unflagged browser")
running = true
assert(launch("com.google.Chrome"))
assert(launched == "com.google.Chrome", "focus the running browser, not the short-lived wrapper")
running = false
installed = false
assert(launch("com.google.Chrome"))
assert(launched == "com.google.Chrome", "machines without the opt-in keep their existing behavior")
installed = true
assert(launch("org.chromium.Chromium"))
assert(launched == "org.chromium.Chromium", "browsers the launcher does not target must not be redirected")
print("launch application tests passed")
