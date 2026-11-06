-- Key Hints state machine, kept free of Hyprland calls so tests/state.lua can
-- drive it with plain Lua.
--
-- IDLE: nothing shown. ACTIVE: Super held, hints requested.
-- SUPPRESSED: Super still held, but a shortcut was pressed, the pointer moved
-- (Super+drag) or the workspace changed; stay quiet until Super is released.

local State = {}
State.__index = State

State.MODIFIER_KEYCODES = {
  [37] = true, [105] = true,  -- Control_L / Control_R
  [50] = true, [62] = true,   -- Shift_L / Shift_R
  [64] = true, [108] = true,  -- Alt_L / Alt_R
  [133] = true, [134] = true, -- Super_L / Super_R
}

local function noop() end

-- callbacks: show(mods), update(mods), hide(), pressed(mods, keycode)
function State.new(callbacks)
  callbacks = callbacks or {}
  return setmetatable({
    state = "IDLE",
    shown_mods = "",
    show = callbacks.show or noop,
    update = callbacks.update or noop,
    hide = callbacks.hide or noop,
    pressed = callbacks.pressed or noop,
  }, State)
end

-- key_state: 0 release, 1 press (repeats are filtered by the caller).
-- mods: "SUPER SHIFT" etc., read after the event was applied.
function State:key(keycode, key_state, mods)
  if not mods:find("SUPER", 1, true) then
    if self.state == "ACTIVE" then self.hide() end
    self.state, self.shown_mods = "IDLE", ""
    return
  end

  local is_modifier = State.MODIFIER_KEYCODES[tonumber(keycode)] == true

  if key_state == 1 and not is_modifier then
    -- A Super chord. Count it whether or not the hints were showing.
    self.pressed(mods, keycode)
    self:suppress()
    return
  end

  if self.state == "IDLE" then
    if key_state == 1 then
      self.state, self.shown_mods = "ACTIVE", mods
      self.show(mods)
    end
  elseif self.state == "ACTIVE" and mods ~= self.shown_mods then
    self.shown_mods = mods
    self.update(mods)
  end
end

-- Pointer moved or workspace changed while Super is held.
function State:suppress()
  if self.state == "ACTIVE" then self.hide() end
  if self.state ~= "IDLE" then self.state = "SUPPRESSED" end
end

function State:reset()
  self.state, self.shown_mods = "IDLE", ""
end

return State
