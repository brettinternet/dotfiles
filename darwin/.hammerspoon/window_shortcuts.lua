local M = {}

function M.start()
  local commands = {
    [hs.keycodes.map.left] = "Left",
    [hs.keycodes.map.right] = "Right",
    [hs.keycodes.map.up] = "Top",
    [hs.keycodes.map.down] = "Bottom",
    -- macOS can translate Fn-arrows before the event reaches Hammerspoon.
    [hs.keycodes.map.home] = "Left",
    [hs.keycodes.map["end"]] = "Right",
    [hs.keycodes.map.pageup] = "Top",
    [hs.keycodes.map.pagedown] = "Bottom",
  }
  local restoreKeyCode = hs.keycodes.map.r

  return hs.eventtap
    .new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp }, function(event)
      local flags = event:getFlags()
      local keyCode = event:getKeyCode()
      local command = commands[keyCode]
      if
        not (command or keyCode == restoreKeyCode)
        or not flags.fn
        or not flags.ctrl
        or flags.cmd
        or flags.alt
        or flags.shift
      then
        return false
      end

      -- Preserve the existing native Fn-Control-R behavior when available.
      local app = hs.application.frontmostApplication()
      -- Shell-launched Chromium profiles can have an invalid application PID.
      -- Their menus are inaccessible to Hammerspoon; leave native input intact.
      if app and app:bundleID() == "org.chromium.Chromium" and app:pid() == -1 then
        return false
      end
      local path = { "Window", "Move & Resize", command or "Return to Previous Size" }
      local menuItem = app and app:findMenuItem(path)
      if not command then
        return not (menuItem and menuItem.enabled)
      end

      -- Invoke the native command ourselves so apps cannot reinterpret the chord.
      if
        event:getType() == hs.eventtap.event.types.keyDown
        and event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 0
        and menuItem
        and menuItem.enabled
      then
        app:selectMenuItem(path)
      end
      return true
    end)
    :start()
end

return M
