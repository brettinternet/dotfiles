-- Installation is the machine-local opt-in; no hostname list is kept in dotfiles.
local lidAwake = {}
-- The root daemon applies this request file; the installer makes the directory user-owned.
local control = "/Library/Application Support/local.lid-awake"
local request = control .. "/enabled"
local menubar, timer
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
  local ok, err
  if value then
    local file
    file, err = io.open(request, "w")
    ok = file and file:close()
  else
    ok, err = os.remove(request)
    ok = ok or not hs.fs.attributes(request)
  end
  if not ok then
    hs.alert.show("Lid override failed: " .. tostring(err))
  end
  -- Show the daemon's applied state, not the request; it normally reacts at once.
  hs.timer.doAfter(0.2, refresh)
  hs.timer.doAfter(1.5, refresh)
end

function lidAwake.start()
  if menubar or not hs.fs.attributes(control) then
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
        disabled = not known,
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
