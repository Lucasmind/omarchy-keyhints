-- Key Hints observer. Watches modifier keys and tells the Omarchy shell what to
-- show. It never binds, consumes or replays a key: Hyprland's own bindings keep
-- working exactly as before. Loaded (guarded) from ~/.config/hypr/hyprland.lua.
--
-- The one-tick deferral technique comes from NextKey
-- (github.com/russellmorton/next-key, MIT): input.keyboard.key fires before
-- Hyprland updates the state hl.is_key_down() reads.

-- The QML does its own dim and fade.
hl.layer_rule({ match = { namespace = "^keyhints$" }, no_anim = true })

local MODIFIER_KEYCODES = {
  [37] = true, [105] = true, -- Control_L / Control_R
  [50] = true, [62] = true,  -- Shift_L / Shift_R
  [64] = true, [108] = true, -- Alt_L / Alt_R
  [133] = true, [134] = true, -- Super_L / Super_R
}

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
  if win.floating then flags[#flags + 1] = "floating" end
  if (tonumber(win.fullscreen) or 0) > 0 then flags[#flags + 1] = "fullscreen" end
  if win.pinned then flags[#flags + 1] = "pinned" end
  if win.group ~= nil then flags[#flags + 1] = "grouped" end
  return tostring(win.class or ""), tostring(win.title or ""), table.concat(flags, ",")
end

local function monitor_name()
  local ok, mon = pcall(hl.get_active_monitor)
  return (ok and mon and tostring(mon.name or "")) or ""
end

-- IDLE: nothing shown. ACTIVE: Super held, card requested. SUPPRESSED: an
-- action key was pressed with Super held; stay quiet until Super is released.
local state = "IDLE"
local shown_mods = ""
local pending

local function handle(keycode, key_state)
  local mods = modifiers()
  local super = mods:find("SUPER", 1, true) ~= nil

  if not super then
    if state == "ACTIVE" then send("hide") end
    state, shown_mods = "IDLE", ""
    return
  end

  local is_modifier = MODIFIER_KEYCODES[tonumber(keycode)] == true

  if state == "IDLE" then
    if key_state == 1 and is_modifier then
      state, shown_mods = "ACTIVE", mods
      local class, title, flags = window_info()
      send("show", mods, monitor_name(), class, title, flags)
    end
  elseif state == "ACTIVE" then
    if key_state == 1 and not is_modifier then
      state = "SUPPRESSED"
      send("hide")
    elseif mods ~= shown_mods then
      shown_mods = mods
      send("update", mods)
    end
  end
end

local function flush()
  if not pending then return end
  local event = pending
  pending = nil
  handle(event.keycode, event.state)
end

local timer
timer = hl.timer(function()
  timer:set_enabled(false)
  flush()
end, { timeout = 1, type = "repeat" })
timer:set_enabled(false)

hl.on("input.keyboard.key", function(keycode, _, key_state)
  timer:set_enabled(false)
  flush()
  if key_state == 2 then return end -- key repeat
  pending = { keycode = keycode, state = key_state }
  timer:set_timeout(1)
  timer:set_enabled(true)
end)

hl.on("config.reloaded", function()
  timer:set_enabled(false)
  pending, state, shown_mods = nil, "IDLE", ""
  send("reload")
end)
