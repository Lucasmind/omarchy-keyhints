-- hypr/KeyhintsState.lua without Hyprland. Run: lua tests/state.test.lua
local dir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local State = dofile(dir .. "../hypr/KeyhintsState.lua")

local SUPER, SHIFT, W = 133, 50, 25
local log
local function machine()
  log = {}
  return State.new({
    show = function(m) log[#log + 1] = "show " .. m end,
    update = function(m) log[#log + 1] = "update " .. m end,
    hide = function() log[#log + 1] = "hide" end,
    pressed = function(m, k) log[#log + 1] = "pressed " .. m .. " " .. k end,
  })
end
local function expect(want)
  assert(table.concat(log, "; ") == table.concat(want, "; "),
    "\n  want: " .. table.concat(want, "; ") .. "\n  got:  " .. table.concat(log, "; "))
end
local passed = 0
local function test(name, fn) fn(); passed = passed + 1; print("ok - " .. name) end

test("Super press shows, release hides", function()
  local m = machine()
  m:key(SUPER, 1, "SUPER")
  m:key(SUPER, 0, "")
  expect({ "show SUPER", "hide" })
end)

test("adding a modifier updates the layer", function()
  local m = machine()
  m:key(SUPER, 1, "SUPER")
  m:key(SHIFT, 1, "SUPER SHIFT")
  m:key(SHIFT, 0, "SUPER")
  expect({ "show SUPER", "update SUPER SHIFT", "update SUPER" })
end)

test("a shortcut is counted, hides, and stays quiet until Super is released", function()
  local m = machine()
  m:key(SUPER, 1, "SUPER")
  m:key(W, 1, "SUPER")
  m:key(SHIFT, 1, "SUPER SHIFT")
  m:key(W, 1, "SUPER SHIFT")
  m:key(SUPER, 0, "SHIFT")
  m:key(SUPER, 1, "SUPER SHIFT")
  expect({ "show SUPER", "pressed SUPER 25", "hide", "pressed SUPER SHIFT 25", "show SUPER SHIFT" })
end)

test("pointer drag or workspace switch suppresses", function()
  local m = machine()
  m:key(SUPER, 1, "SUPER")
  m:suppress()
  m:key(SHIFT, 1, "SUPER SHIFT")
  expect({ "show SUPER", "hide" })
  assert(m.state == "SUPPRESSED")
end)

test("suppress while idle does nothing", function()
  local m = machine()
  m:suppress()
  expect({})
  assert(m.state == "IDLE")
end)

test("keys without Super are ignored", function()
  local m = machine()
  m:key(SHIFT, 1, "SHIFT")
  m:key(W, 1, "SHIFT")
  expect({})
end)

print(passed .. " passed")
