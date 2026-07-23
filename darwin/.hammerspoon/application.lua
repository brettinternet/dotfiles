local target_by_instance = {}
local previous_application_by_instance = {}
local last_activated_application
local previous_activated_application
local application_history_watcher

local function settings_for(context)
  local settings = nil
  if context and type(context.getSettings) == "function" then
    settings = context:getSettings()
  elseif context then
    settings = context.settings
  end

  if type(settings) ~= "table" then
    return nil, false
  end

  local bundle_id = settings.bundleID
  if type(bundle_id) ~= "string" or bundle_id == "" or #bundle_id > 128 then
    return nil, false
  end
  return bundle_id, settings.focusOnShow == true
end

local function target_key(context)
  return context and context.instanceId or "default"
end

local function require_application_api(method_name)
  if type(hs) ~= "table" or type(hs.application) ~= "table" or type(hs.application[method_name]) ~= "function" then
    error("application unavailable")
  end
end

local function frontmost_application()
  require_application_api("frontmostApplication")

  local ok, application = pcall(hs.application.frontmostApplication)
  if not ok then
    error("failed to inspect frontmost application: " .. tostring(application))
  end
  return application
end

local function start_application_history()
  if
    type(hs) ~= "table"
    or type(hs.application) ~= "table"
    or type(hs.application.watcher) ~= "table"
    or type(hs.application.watcher.new) ~= "function"
  then
    return
  end

  local ok, current = pcall(hs.application.frontmostApplication)
  if ok then
    last_activated_application = current
  end

  local watcher_api = hs.application.watcher
  local watcher_ok, watcher = pcall(watcher_api.new, function(_, event, application)
    if event == watcher_api.activated and application and application ~= last_activated_application then
      previous_activated_application = last_activated_application
      last_activated_application = application
    end
  end)
  if not watcher_ok or not watcher or type(watcher.start) ~= "function" then
    return
  end

  application_history_watcher = watcher
  pcall(watcher.start, watcher)
end

start_application_history()

local MAX_ICON_BYTES = 32768

local function application_bundle_id(application)
  if not application or type(application.bundleID) ~= "function" then
    return nil
  end

  local ok, bundle_id = pcall(application.bundleID, application)
  if not ok or type(bundle_id) ~= "string" or bundle_id == "" then
    return nil
  end
  return bundle_id
end

local function application_icon(application, configured_bundle_id)
  local bundle_id = configured_bundle_id or application_bundle_id(application)
  if
    not bundle_id
    or type(hs) ~= "table"
    or type(hs.image) ~= "table"
    or type(hs.image.imageFromAppBundle) ~= "function"
  then
    return nil
  end

  local ok, image = pcall(hs.image.imageFromAppBundle, bundle_id)
  if not ok or not image or type(image.bitmapRepresentation) ~= "function" then
    return nil
  end

  local bitmap_ok, bitmap = pcall(image.bitmapRepresentation, image, { w = 72, h = 72 })
  if not bitmap_ok or not bitmap or type(bitmap.encodeAsURLString) ~= "function" then
    return nil
  end

  local encoded_ok, data_url = pcall(bitmap.encodeAsURLString, bitmap, true, "PNG")
  if not encoded_ok or type(data_url) ~= "string" then
    return nil
  end

  local data_base64 = data_url:match("^data:image/png;base64,(.+)")
  if not data_base64 then
    return nil
  end
  data_base64 = data_base64:gsub("%s+", "")
  local base64_payload = data_base64:match("^[A-Za-z0-9+/]+=?=?")
  if #data_base64 == 0 or #data_base64 % 4 ~= 0 or base64_payload ~= data_base64 then
    return nil
  end

  local padding = data_base64:sub(-2) == "==" and 2 or data_base64:sub(-1) == "=" and 1 or 0
  local byte_count = (#data_base64 / 4) * 3 - padding
  if byte_count <= 0 or byte_count > MAX_ICON_BYTES then
    return nil
  end

  local icon = {
    kind = "custom",
    mediaType = "image/png",
    dataBase64 = data_base64,
  }
  local protocol_ok, protocol = pcall(require, "streamdeck.protocol")
  if not protocol_ok or type(protocol.validateAppearanceIcon) ~= "function" then
    return nil
  end
  local valid_ok, valid = pcall(protocol.validateAppearanceIcon, icon)
  if not valid_ok or valid ~= true then
    return nil
  end
  return icon
end

local function configured_application(bundle_id)
  require_application_api("get")

  local ok, application = pcall(hs.application.get, bundle_id)
  if not ok then
    error("failed to find application " .. bundle_id .. ": " .. tostring(application))
  end
  return application
end

local function launch_or_focus_application(bundle_id)
  require_application_api("launchOrFocusByBundleID")

  local ok, result = pcall(hs.application.launchOrFocusByBundleID, bundle_id)
  if not ok then
    error("failed to open application: " .. tostring(result))
  end
  if result ~= true then
    error("failed to open application")
  end
end

local function application_for(context)
  local bundle_id, focus_on_show = settings_for(context)
  if bundle_id ~= nil then
    return configured_application(bundle_id), bundle_id, focus_on_show
  end

  return target_by_instance[target_key(context)] or frontmost_application(), nil, false
end

local function application_is_running(application)
  local ok, running = pcall(application.isRunning, application)
  if not ok then
    error("failed to inspect application running state: " .. tostring(running))
  end
  if type(running) ~= "boolean" then
    error("failed to inspect application running state")
  end
  return running
end

local function application_has_main_window(application)
  local ok, main_window = pcall(application.mainWindow, application)
  if not ok then
    error("failed to inspect application windows: " .. tostring(main_window))
  end
  return main_window ~= nil
end

local function application_is_actually_hidden(application)
  local ok, hidden = pcall(application.isHidden, application)
  if not ok then
    error("failed to inspect application visibility: " .. tostring(hidden))
  end
  if type(hidden) ~= "boolean" then
    error("failed to inspect application visibility")
  end
  return hidden
end

local function application_is_hidden(application)
  if not application_is_running(application) then
    return true
  end
  if application_is_actually_hidden(application) then
    return true
  end
  return not application_has_main_window(application)
end

local function application_is_frontmost(application)
  local ok, frontmost = pcall(application.isFrontmost, application)
  if not ok then
    error("failed to inspect application focus: " .. tostring(frontmost))
  end
  if type(frontmost) ~= "boolean" then
    error("failed to inspect application focus")
  end
  return frontmost
end

local function application_name(application)
  local ok, name = pcall(application.name, application)
  if not ok or type(name) ~= "string" or name == "" then
    return "Unknown app"
  end
  return name
end

local function toggle_application(application)
  local hidden = application_is_hidden(application)
  local method_name = hidden and "unhide" or "hide"
  local operation = hidden and "show" or "hide"
  local method = application[method_name]
  if type(method) ~= "function" then
    error("application cannot " .. operation)
  end

  local ok, result = pcall(method, application)
  if not ok then
    error("failed to " .. operation .. " application: " .. tostring(result))
  end
  return hidden
end

local function activate_application(application)
  if type(application.activate) ~= "function" then
    error("application cannot focus")
  end

  local ok, result = pcall(application.activate, application, true)
  if not ok then
    error("failed to focus application: " .. tostring(result))
  end
  if result ~= true then
    error("failed to focus application")
  end
end

local function remember_previous_application(context, target)
  local previous = frontmost_application()
  if previous == target then
    previous = previous_activated_application
  end
  if previous and previous ~= target then
    previous_application_by_instance[target_key(context)] = previous
  end
end

local function refocus_previous_application(context, target)
  local key = target_key(context)
  local previous = previous_application_by_instance[key]
  previous_application_by_instance[key] = nil
  if not previous then
    previous = frontmost_application()
  end
  if previous and previous ~= target and application_is_running(previous) then
    activate_application(previous)
  end
end

local function unhide_application(application)
  if type(application.unhide) ~= "function" then
    error("application cannot show")
  end

  local ok, result = pcall(application.unhide, application)
  if not ok then
    error("failed to show application: " .. tostring(result))
  end
end

local function show_application(context, application, bundle_id, focus_on_show)
  local key = target_key(context)
  local target_bundle_id = bundle_id
  if application then
    if application_is_running(application) and application_has_main_window(application) then
      previous_application_by_instance[key] = nil
      if focus_on_show then
        remember_previous_application(context, application)
      end
      if application_is_actually_hidden(application) then
        unhide_application(application)
      end
      if focus_on_show then
        activate_application(application)
      end
      return
    end
    target_bundle_id = target_bundle_id or application_bundle_id(application)
  end

  previous_application_by_instance[key] = nil
  remember_previous_application(context, application)
  if not target_bundle_id then
    error("application cannot show")
  end
  launch_or_focus_application(target_bundle_id)
end

local function close_application(application)
  if type(application.kill) ~= "function" then
    error("application cannot close")
  end

  local ok, result = pcall(application.kill, application)
  if not ok then
    error("failed to close application: " .. tostring(result))
  end
  if result ~= true then
    error("failed to close application")
  end
end

return {
  id = "com.brettinternet.hammerspoon.application-launcher",
  name = "Hide/show application",
  settingsSchemaVersion = 1,
  settingsSchema = {
    { type = "text", key = "bundleID", label = "Application bundle ID", maxLength = 128 },
    { type = "boolean", key = "focusOnShow", label = "Focus application when shown", default = false },
  },

  appearance = function(context)
    local application, bundle_id = application_for(context)
    local appearance
    if application then
      appearance = {
        title = application_name(application),
        state = application_is_hidden(application) and "active" or "inactive",
      }
    else
      appearance = {
        title = "No app",
        state = "inactive",
      }
    end

    local icon = application_icon(application, bundle_id)
    if icon then
      appearance.appearanceVersion = 1
      appearance.icon = icon
    end
    return appearance
  end,

  press = function(context)
    local application, bundle_id, focus_on_show = application_for(context)
    if not application and bundle_id == nil then
      error("no frontmost application")
    elseif
      application
      and not application_is_hidden(application)
      and (bundle_id == nil or not focus_on_show or application_is_frontmost(application))
    then
      remember_previous_application(context, application)
      local was_hidden = toggle_application(application)
      if not was_hidden then
        refocus_previous_application(context, application)
      end
      if bundle_id == nil then
        local key = target_key(context)
        target_by_instance[key] = was_hidden and nil or application
      end
    else
      show_application(context, application, bundle_id, focus_on_show)
      if bundle_id == nil then
        target_by_instance[target_key(context)] = nil
      end
    end
  end,
  longPress = function(context)
    local application, bundle_id = application_for(context)
    if not application then
      if bundle_id ~= nil then
        error("application not running: " .. bundle_id)
      end
      error("no frontmost application")
    end

    close_application(application)
    local key = target_key(context)
    if bundle_id == nil then
      target_by_instance[key] = nil
    end
    previous_application_by_instance[key] = nil
  end,
}
