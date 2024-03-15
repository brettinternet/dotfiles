-- https://www.hammerspoon.org/go
-- https://developer.okta.com/blog/2020/10/22/set-up-a-mute-indicator-light-for-zoom-with-hammerspoon
-- http://peterhajas.com/blog/streamdeck.html
-- https://github.com/peterhajas/dotfiles/blob/master/hammerspoon/.hammerspoon/streamdeck/peek.lua

-- https://www.hammerspoon.org/Spoons/SpoonInstall.html
-- hs.loadSpoon("SpoonInstall")

-- https://www.hammerspoon.org/Spoons/PushToTalk.html
-- spoon.SpoonInstall:andUse(
--   "PushToTalk",
--   {
--     start = true,
--     config = {
--       app_switcher = {["zoom.us"] = "push-to-talk", ["discord"] = "push-to-talk"},
--       detect_on_start = true
--     }
--   }
-- )

-- https://www.hammerspoon.org/docs/hs.caffeinate.html
-- https://www.hammerspoon.org/docs/hs.notify.html
-- https://www.hammerspoon.org/docs/hs.noises.html
-- https://www.hammerspoon.org/Spoons/TextClipboardHistory.html
-- https://www.hammerspoon.org/Spoons/Caffeine.html

-- https://www.hammerspoon.org/Spoons/MicMute.html
-- hs.loadSpoon("MicMute")
-- -- muteHotKey = {toggle = {"cmd", "shift"}, "X"}
-- -- spoon.MicMute:bindHotkeys(muteHotKey, 0.75)

-- muted = false
-- muteAlertId = nil
-- hs.hotkey.bind({"cmd", "shift"}, "A", function()
--   if muteAlertId then
--     hs.alert.closeSpecific(muteAlertId)
--   end
--   if muted then
--     muted = false
--     muteAlertId = hs.alert.show("Unmuted")
--   else
--     muted = true
--     muteAlertId = hs.alert.show("Muted", nil, hs.screen.mainScreen(), 10)
--   end
--   spoon.MicMute:toggleMicMute()
-- end)

hs.loadSpoon("AClock")
hs.hotkey.bind({"cmd", "shift"}, "Z", function()
  spoon.AClock.textSize = 300
  spoon.AClock.width = 960
  spoon.AClock.height = 690
  spoon.AClock.textFont = "Fira Code"
  spoon.AClock.textColor = hs.drawing.color.hammerspoon.black
  spoon.AClock:toggleShow()
end)
