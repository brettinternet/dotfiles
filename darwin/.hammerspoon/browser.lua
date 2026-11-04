-- chromium-apps --install-url-handler records this machine's browser in the launcher.
local launcher = os.getenv("HOME") .. "/Applications/Chromium Default.app"
local info = hs.plist.read(launcher .. "/Contents/Info.plist")

return {
  bundleID = info and info.BrowserBundleIdentifier or "org.chromium.Chromium",
  launcher = launcher,
}
