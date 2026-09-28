local module_path = (arg[0]:match("(.*/)") or "") .. "../?.lua"
package.path = module_path .. ";" .. package.path

local callback
local enabled = true
local present = true
local selections = {}
local app = {
  findMenuItem = function(_, path)
    assert(path[1] == "Window" and path[2] == "Move & Resize")
    return present and { enabled = enabled } or nil
  end,
  selectMenuItem = function(_, path)
    selections[#selections + 1] = path[3]
    return true
  end,
}
local frontmost = app
_G.hs = {
  keycodes = {
    map = {
      left = 123,
      right = 124,
      up = 126,
      down = 125,
      home = 115,
      ["end"] = 119,
      pageup = 116,
      pagedown = 121,
      r = 15,
    },
  },
  application = {
    frontmostApplication = function()
      return frontmost
    end,
  },
  eventtap = {
    event = {
      types = { keyDown = 10, keyUp = 11 },
      properties = { keyboardEventAutorepeat = 8 },
    },
    new = function(types, handler)
      assert(types[1] == 10 and types[2] == 11)
      callback = handler
      return {
        start = function(self)
          return self
        end,
      }
    end,
  },
}
require("window_shortcuts").start()

local function send(key, flags, eventType, repeated)
  return callback({
    getKeyCode = function()
      return hs.keycodes.map[key] or 0
    end,
    getFlags = function()
      return flags or { fn = true, ctrl = true }
    end,
    getType = function()
      return eventType or 10
    end,
    getProperty = function()
      return repeated or 0
    end,
  })
end

for _, key in ipairs({ "left", "right", "up", "down" }) do
  assert(send(key), "arrow chord must be consumed")
end
assert(table.concat(selections, ",") == "Left,Right,Top,Bottom")
assert(send("up", nil, 11), "key release must be consumed")
assert(send("up", nil, 10, 1), "autorepeat must be consumed")
assert(#selections == 4, "release and repeat must not reapply tiling")

for _, flags in ipairs({
  {},
  { ctrl = true },
  { fn = true },
  { fn = true, ctrl = true, shift = true },
  { fn = true, ctrl = true, alt = true },
  { fn = true, ctrl = true, cmd = true },
}) do
  assert(not send("up", flags), "unrelated modifier combinations must pass through")
end
for _, key in ipairs({ "home", "end", "pageup", "pagedown" }) do
  assert(send(key), "translated Fn-arrow must be consumed")
  assert(send(key, nil, 11), "translated key release must be consumed")
  assert(send(key, nil, 10, 1), "translated autorepeat must be consumed")
  assert(not send(key, { ctrl = true }), "ordinary Ctrl-navigation must pass through")
  assert(not send(key, { fn = true }), "ordinary Fn-navigation must pass through")
end
assert(table.concat(selections, ",") == "Left,Right,Top,Bottom,Left,Right,Top,Bottom")
assert(not send("x"), "unrelated keys must pass through")
assert(not send("r"), "available native restore must pass through")
enabled = false
assert(send("r"), "unavailable restore must be consumed")
assert(send("up"), "disabled tiling must be consumed")
present = false
assert(send("down"), "missing tiling must be consumed")
frontmost = nil
assert(send("left"), "missing application must be handled")
assert(#selections == 8, "unavailable commands must not be selected")
print("window_shortcuts tests passed")
