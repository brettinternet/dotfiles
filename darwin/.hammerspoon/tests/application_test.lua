local module_path = (arg[0]:match("(.*/)") or "") .. "../?.lua"
package.path = module_path .. ";" .. package.path

local function assert_equal(actual, expected, message)
  assert(actual == expected, string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
end

local function assert_true(value, message)
  assert(value == true, message)
end

local function new_application(options)
  local application = {
    bundle_id = "com.example.TestApp",
    frontmost = options.frontmost,
    hidden = options.hidden,
    running = options.running ~= false,
    has_main_window = options.has_main_window ~= false,
    hide_calls = 0,
    unhide_calls = 0,
    activate_calls = 0,
    last_activate_all_windows = nil,
  }

  function application:bundleID()
    return self.bundle_id
  end

  function application:isFrontmost()
    return self.frontmost
  end

  function application:isHidden()
    return self.hidden
  end

  function application:isRunning()
    return self.running
  end

  function application:mainWindow()
    return self.has_main_window and {} or nil
  end

  function application:name()
    return "Test App"
  end

  function application:hide()
    self.hide_calls = self.hide_calls + 1
    self.hidden = true
    return true
  end

  function application:unhide()
    self.unhide_calls = self.unhide_calls + 1
    self.hidden = false
    return true
  end

  function application:activate(all_windows)
    self.activate_calls = self.activate_calls + 1
    self.last_activate_all_windows = all_windows
    self.frontmost = true
    return true
  end

  function application:kill()
    return true
  end

  return application
end

local running_application
local frontmost_application
local launched_bundle_id
local activation_callback
_G.hs = {
  application = {
    get = function()
      return running_application
    end,
    frontmostApplication = function()
      return frontmost_application
    end,
    launchOrFocusByBundleID = function(bundle_id)
      launched_bundle_id = bundle_id
      return true
    end,
    watcher = {
      activated = "activated",
      new = function(callback)
        activation_callback = callback
        return {
          start = function()
          end,
        }
      end,
    },
  },
}

package.loaded.application = nil
local action = require("application")

assert_equal(action.settingsSchemaVersion, 1, "settings schema version")
assert_equal(action.settingsSchema[2].type, "boolean", "focus setting type")
assert_equal(action.settingsSchema[2].key, "focusOnShow", "focus setting key")
assert_equal(action.settingsSchema[2].default, false, "focus setting default")

local function activate(application)
  frontmost_application = application
  application.frontmost = true
  activation_callback(nil, "activated", application)
end

local function press(application, options)
  options = options or {}
  running_application = application
  launched_bundle_id = nil
  local settings = options.unconfigured and {} or {
    bundleID = "com.example.TestApp",
    focusOnShow = options.focus_on_show,
  }
  action.press({ settings = settings, instanceId = options.instance_id or "configured" })
end

local windowless_application = new_application({ frontmost = false, hidden = false, has_main_window = false })
press(windowless_application)
assert_equal(launched_bundle_id, "com.example.TestApp", "windowless app should be launched or focused")
assert_equal(windowless_application.hide_calls, 0, "windowless app should not be hidden")
assert_equal(windowless_application.unhide_calls, 0, "windowless app should not be unhidden")

local windowless_appearance = action.appearance({ settings = { bundleID = "com.example.TestApp" } })
assert_equal(windowless_appearance.state, "active", "windowless app should appear hidden")

local stopped_application = new_application({ frontmost = false, hidden = false, running = false, has_main_window = false })
press(stopped_application)
assert_equal(launched_bundle_id, "com.example.TestApp", "stopped app should be launched")
assert_equal(stopped_application.unhide_calls, 0, "stopped app should not be unhidden")

local frontmost_application_with_window = new_application({ frontmost = true, hidden = false })
press(frontmost_application_with_window)
assert_equal(launched_bundle_id, nil, "frontmost app should not be launched")
assert_equal(frontmost_application_with_window.hide_calls, 1, "frontmost app should be hidden")

local background_application = new_application({ frontmost = false, hidden = false })
press(background_application)
assert_equal(launched_bundle_id, nil, "visible background app should not be relaunched")
assert_equal(background_application.activate_calls, 0, "show should not focus by default")

local focused_background_application = new_application({ frontmost = false, hidden = false })
press(focused_background_application, { focus_on_show = true })
assert_equal(launched_bundle_id, nil, "focused visible app should not be relaunched")
assert_equal(focused_background_application.activate_calls, 1, "focus option should activate the app")
assert_true(focused_background_application.last_activate_all_windows, "focus option should bring all windows forward")

local previously_focused_application = new_application({ frontmost = true, hidden = false })
local focused_target_application = new_application({ frontmost = false, hidden = false })
frontmost_application = previously_focused_application
press(focused_target_application, { focus_on_show = true, instance_id = "refocus" })
frontmost_application = focused_target_application
press(focused_target_application, { instance_id = "refocus" })
assert_equal(focused_target_application.hide_calls, 1, "focused target should be hidden")
assert_equal(previously_focused_application.activate_calls, 1, "previous app should be refocused after hiding")
assert_true(previously_focused_application.last_activate_all_windows, "refocus should bring previous windows forward")

local externally_previously_focused = new_application({ frontmost = true, hidden = false })
local externally_focused_target = new_application({ frontmost = false, hidden = false })
activate(externally_previously_focused)
activate(externally_focused_target)
press(externally_focused_target, { instance_id = "external-refocus" })
assert_equal(externally_focused_target.hide_calls, 1, "externally focused target should be hidden")
assert_equal(externally_previously_focused.activate_calls, 1, "activation history should refocus the previous app")

local hidden_application = new_application({ frontmost = false, hidden = true })
press(hidden_application)
assert_equal(launched_bundle_id, nil, "running hidden app should not be relaunched")
assert_equal(hidden_application.unhide_calls, 1, "hidden app should be unhidden")
assert_equal(hidden_application.activate_calls, 0, "hidden app should not be focused by default")

local focused_hidden_application = new_application({ frontmost = false, hidden = true })
press(focused_hidden_application, { focus_on_show = true })
assert_equal(launched_bundle_id, nil, "focused hidden app should not be relaunched")
assert_equal(focused_hidden_application.unhide_calls, 1, "focused hidden app should be unhidden")
assert_equal(focused_hidden_application.activate_calls, 1, "focus option should focus a hidden app")
assert_true(focused_hidden_application.last_activate_all_windows, "focus option should bring hidden windows forward")

frontmost_application = new_application({ frontmost = true, hidden = false })
press(frontmost_application, { unconfigured = true, instance_id = "unconfigured" })
assert_equal(frontmost_application.hide_calls, 1, "unconfigured frontmost app should be hidden")
frontmost_application = new_application({ frontmost = true, hidden = false })
press(nil, { unconfigured = true, instance_id = "unconfigured" })
assert_equal(frontmost_application.activate_calls, 0, "unconfigured show should not focus by default")

press(nil)
assert_equal(launched_bundle_id, "com.example.TestApp", "absent app should be launched")

print("application tests passed")
