-- Installation is the machine-local opt-in; no hostname list is kept in dotfiles.
local lidAwake = {}
local helper = "/Library/PrivilegedHelperTools/local.lid-awake"
local menubar, timer, task
local enabled = false
local known = false

local function refresh()
  local output, success = hs.execute("/usr/bin/pmset -g")
  known = success
  enabled = success and output:match("SleepDisabled%s+1") ~= nil
  menubar:setTitle(known and (enabled and "Lid: awake" or "Lid: sleep") or "Lid: ?")
  menubar:setTooltip("Closed-lid sleep override; resets when AC power is unplugged")
end

local function setEnabled(value)
  if task then
    return
  end
  task = hs.task.new("/usr/bin/sudo", function(code, _, stderr)
    task = nil
    if code ~= 0 then
      hs.alert.show("Lid override failed: " .. stderr)
    end
    refresh()
  end, { "-n", helper, value and "enable" or "disable" })
  if not task or not task:start() then
    task = nil
    hs.alert.show("Could not start the lid override helper")
  end
end

function lidAwake.start()
  if menubar or not hs.fs.attributes(helper) then
    return lidAwake
  end
  menubar = hs.menubar.new()
  refresh()
  menubar:setMenu(function()
    refresh()
    return {
      {
        title = "Keep awake with lid closed",
        checked = enabled,
        disabled = task ~= nil or not known,
        fn = function()
          setEnabled(not enabled)
        end,
      },
      { title = "Resets on AC → battery or reboot", disabled = true },
      { title = "Do not transport while enabled", disabled = true },
    }
  end)
  timer = hs.timer.doEvery(5, refresh)
  return lidAwake
end

return lidAwake
