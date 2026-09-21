local obj = {}
obj.__index = obj

obj.name = "WindowCycle"
obj.version = "0.1.0"
obj.author = "Daniel Braz"
obj.license = "MIT"

obj.logger = hs.logger.new("WindowCycle")
obj._hotkeys = {}
obj.excludedApps = {
  ["com.apple.dock"] = true,
  ["com.apple.WindowManager"] = true,
  ["com.apple.systemuiserver"] = true,
}

-- Start at twelve o'clock and increase clockwise in screen coordinates.
-- Geometry and window IDs, never focus/z-order, determine the cycle.
function obj:_sortWindows(windows, screen)
  local frame = screen:fullFrame()
  local cx, cy = frame.x + frame.w / 2, frame.y + frame.h / 2
  local entries = {}
  for _, window in ipairs(windows) do
    local bounds = window:frame()
    local dx = bounds.x + bounds.w / 2 - cx
    local dy = bounds.y + bounds.h / 2 - cy
    entries[#entries + 1] = {
      window = window,
      id = window:id(),
      angle = (math.atan(dy, dx) + math.pi / 2) % (2 * math.pi),
      distance = dx * dx + dy * dy,
    }
  end
  table.sort(entries, function(a, b)
    if a.angle ~= b.angle then return a.angle < b.angle end
    if a.distance ~= b.distance then return a.distance < b.distance end
    return a.id < b.id
  end)
  local ordered = {}
  for _, entry in ipairs(entries) do ordered[#ordered + 1] = entry.window end
  return ordered
end

function obj:orderedWindows()
  local focused = hs.window.focusedWindow()
  local screen = focused and focused:screen() or hs.screen.mainScreen()
  if not screen then return {} end

  local spaceID, reason = hs.spaces.activeSpaceOnScreen(screen)
  if not spaceID then
    self.logger.w("Cannot resolve active Space: " .. tostring(reason))
    return {}
  end
  local ids, spaceError = hs.spaces.windowsForSpace(spaceID)
  if not ids then
    self.logger.w("Cannot list Space windows: " .. tostring(spaceError))
    return {}
  end
  local inSpace = {}
  for _, id in ipairs(ids) do inSpace[id] = true end

  local windows = {}
  for _, window in ipairs(hs.window.allWindows()) do
    -- A window can disappear while Accessibility is enumerating it.
    local ok, eligible = pcall(function()
      local app, windowScreen = window:application(), window:screen()
      return inSpace[window:id()]
        and window:isStandard()
        and not window:isMinimized()
        and window:isVisible()
        and app and not self.excludedApps[app:bundleID()]
        and windowScreen and windowScreen:id() == screen:id()
    end)
    if ok and eligible then windows[#windows + 1] = window end
  end
  return self:_sortWindows(windows, screen)
end

function obj:_cycle(step)
  local ok, result = pcall(function()
    local windows = self:orderedWindows()
    if #windows == 0 then return false end
    local focused = hs.window.focusedWindow()
    local focusedID = focused and focused:id()
    local index
    for i, window in ipairs(windows) do
      if window:id() == focusedID then index = i; break end
    end
    local nextIndex = index and ((index - 1 + step) % #windows + 1)
      or (step > 0 and 1 or #windows)
    local target = windows[nextIndex]
    if target:id() == focusedID then return false end
    return target:focus() ~= nil
  end)
  if not ok then
    self.logger.w("Cannot cycle windows: " .. tostring(result))
    return false
  end
  return result
end

function obj:clockwise()
  return self:_cycle(1)
end

function obj:counterclockwise()
  return self:_cycle(-1)
end

function obj:bindHotkeys(mapping)
  self:stop()
  for _, action in ipairs({ "clockwise", "counterclockwise" }) do
    local binding = mapping[action]
    if binding then
      local hotkey = hs.hotkey.bind(binding[1], binding[2], function() self[action](self) end)
      if hotkey then self._hotkeys[action] = hotkey end
    end
  end
  return self
end

function obj:stop()
  for _, hotkey in pairs(self._hotkeys) do hotkey:delete() end
  self._hotkeys = {}
  return self
end

function obj:status()
  local bindings = {}
  for action, hotkey in pairs(self._hotkeys) do bindings[action] = hotkey.enabled == true end
  return { version = self.version, bindings = bindings }
end

return obj
