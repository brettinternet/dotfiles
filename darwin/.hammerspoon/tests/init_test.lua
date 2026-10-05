local initPath = (arg[0]:match("(.*/)") or "") .. "../init.lua"
local installed = false
local starts, loaded = 0, false
local function noop() end
local prefix = { bind = noop }
local stub = {
  start = function()
    return {}
  end,
}
local environment = setmetatable({
  hs = {
    ipc = { cliInstall = noop },
    hotkey = { modal = {
      new = function()
        return prefix
      end,
    }, bind = noop },
    fs = {
      attributes = function(path)
        assert(path == "/Library/Application Support/local.lid-awake")
        return installed and {} or nil
      end,
    },
    pathwatcher = {
      new = function()
        return stub
      end,
    },
    alert = {
      show = function()
        loaded = true
      end,
    },
  },
  require = function(name)
    if name == "lid_awake" then
      assert(installed, "module 'lid_awake' not found on an unconfigured desktop")
      return {
        start = function()
          starts = starts + 1
        end,
      }
    end
    return stub
  end,
}, { __index = _G })

local init = assert(loadfile(initPath, "t", environment))
init()
assert(loaded and starts == 0, "Desktop startup must finish without the optional module")
installed, loaded = true, false
init()
assert(loaded and starts == 1, "Opted-in machines must still start lid-awake")
print("init tests passed")
