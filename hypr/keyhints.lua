-- Key Hints observer. Watches modifier keys and tells the Omarchy shell what to
-- show. It never binds, consumes or replays a key: Hyprland's own bindings keep
-- working exactly as before. Loaded (guarded) from ~/.config/hypr/hyprland.lua
-- by bin/keyhints-install.
--
-- The one-tick deferral technique comes from NextKey
-- (github.com/russellmorton/next-key, MIT): input.keyboard.key fires before
-- Hyprland updates the state hl.is_key_down() reads.

local dir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local State = dofile(dir .. "KeyhintsState.lua")

-- The QML does its own dim and fade.
hl.layer_rule({ match = { namespace = "^keyhints$" }, no_anim = true })

local function shell_quote(value)
  return "'" .. tostring(value or ""):gsub("'", "'\"'\"'") .. "'"
end

local function send(method, ...)
  local parts = { "omarchy-shell", "-q", "keyhints", method }
  for i = 1, select("#", ...) do
    parts[#parts + 1] = shell_quote(select(i, ...))
  end
  hl.exec_cmd(table.concat(parts, " "))
end

local function down(key)
  local ok, value = pcall(hl.is_key_down, key)
  return ok and value == true
end

local function modifiers()
  local parts = {}
  if down("Super_L") or down("Super_R") then parts[#parts + 1] = "SUPER" end
  if down("Shift_L") or down("Shift_R") then parts[#parts + 1] = "SHIFT" end
  if down("Control_L") or down("Control_R") then parts[#parts + 1] = "CTRL" end
  if down("Alt_L") or down("Alt_R") then parts[#parts + 1] = "ALT" end
  return table.concat(parts, " ")
end

local function window_info()
  local ok, win = pcall(hl.get_active_window)
  if not ok or win == nil then return "", "", "" end
  local flags = {}
  local fullscreen = tonumber(win.fullscreen) or 0
  if win.floating then flags[#flags + 1] = "floating" end
  if fullscreen == 2 then flags[#flags + 1] = "fullscreen" end -- Super+F
  if fullscreen == 1 then flags[#flags + 1] = "maximized" end  -- Super+Alt+F
  if win.pinned then flags[#flags + 1] = "pinned" end
  if win.group ~= nil then flags[#flags + 1] = "grouped" end
  return tostring(win.class or ""), tostring(win.title or ""), table.concat(flags, ",")
end

local function monitor_name()
  local ok, mon = pcall(hl.get_active_monitor)
  return (ok and mon and tostring(mon.name or "")) or ""
end

local function cursor()
  local ok, pos = pcall(hl.get_cursor_pos)
  if not ok or pos == nil then return nil end
  return { x = tonumber(pos.x) or 0, y = tonumber(pos.y) or 0 }
end

-- While the hints are up, watch the pointer: Super+drag (move/resize) should
-- reveal the windows, not leave them dimmed. Runs only while Super is held.
local DRAG_THRESHOLD = 12
local anchor
local pointer_timer

local machine = State.new({
  show = function(mods)
    local class, title, flags = window_info()
    anchor = cursor()
    pointer_timer:set_enabled(true)
    send("show", mods, monitor_name(), class, title, flags)
  end,
  update = function(mods) send("update", mods) end,
  hide = function()
    pointer_timer:set_enabled(false)
    send("hide")
  end,
  pressed = function(mods, keycode) send("pressed", mods, keycode) end,
})

pointer_timer = hl.timer(function()
  if machine.state ~= "ACTIVE" then
    pointer_timer:set_enabled(false)
    return
  end
  local now = cursor()
  if anchor and now and (math.abs(now.x - anchor.x) > DRAG_THRESHOLD or math.abs(now.y - anchor.y) > DRAG_THRESHOLD) then
    machine:suppress()
  end
end, { timeout = 50, type = "repeat" })
pointer_timer:set_enabled(false)

local pending
local function flush()
  if not pending then return end
  local event = pending
  pending = nil
  machine:key(event.keycode, event.state, modifiers())
end

local settle_timer
settle_timer = hl.timer(function()
  settle_timer:set_enabled(false)
  flush()
end, { timeout = 1, type = "repeat" })
settle_timer:set_enabled(false)

hl.on("input.keyboard.key", function(keycode, _, key_state)
  settle_timer:set_enabled(false)
  flush()
  if key_state == 2 then return end -- key repeat
  pending = { keycode = keycode, state = key_state }
  settle_timer:set_timeout(1)
  settle_timer:set_enabled(true)
end)

-- Super+scroll switches workspaces; the dimmed view would hide where you landed.
hl.on("workspace.active", function() machine:suppress() end)

hl.on("config.reloaded", function()
  settle_timer:set_enabled(false)
  pointer_timer:set_enabled(false)
  pending = nil
  machine:reset()
  send("reload")
end)
