-- Run inside Hammerspoon: dofile(hs.configdir .. "/Spoons/WindowCycle.spoon/tests.lua")
-- Isolated fake windows: these tests never move the user's focus.
local source = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local screen = { id = function() return 1 end,
  fullFrame = function() return { x = -1000, y = 0, w = 1000, h = 1000 } end }
local focused, windows, ids = nil, {}, {}
local calls = 0
local function window(id, x, y, options)
  options = options or {}
  local w = {}
  function w:id() return id end
  function w:frame() return { x = x - 50, y = y - 50, w = 100, h = 100 } end
  function w:screen() return options.screen or screen end
  function w:isStandard() return not options.nonstandard end
  function w:isMinimized() return options.minimized or false end
  function w:isVisible() return not options.hidden end
  function w:application() return { bundleID = function() return options.app or "test.app" end } end
  function w:focus() focused = self; calls = calls + 1; return self end
  return w
end
local fake = {
  logger = { new = function() return { w = function() end } end },
  screen = { mainScreen = function() return screen end },
  spaces = { activeSpaceOnScreen = function() return 10 end,
    windowsForSpace = function() return ids end },
  window = { focusedWindow = function() return focused end,
    allWindows = function() return windows end },
  hotkey = { bind = function(_, _, callback)
    local key = { enabled = true, callback = callback }
    function key:delete() self.enabled = false end
    return key
  end },
}
local env = setmetatable({ hs = fake }, { __index = _G })
local cycle = assert(loadfile(source .. "init.lua", "t", env))()
local nw, ne = window(1, -750, 250), window(2, -250, 250)
local se, sw = window(3, -250, 750), window(4, -750, 750)
windows, ids, focused = { sw, ne, nw, se }, { 1, 2, 3, 4 }, nw
for _, expected in ipairs({ ne, se, sw, nw }) do
  assert(cycle:clockwise() and focused == expected, "clockwise / wrap")
  -- Simulate changing z-order after each focus.
  windows = { windows[4], windows[1], windows[2], windows[3] }
end
for _, expected in ipairs({ sw, se, ne, nw }) do
  assert(cycle:counterclockwise() and focused == expected, "reverse / wrap")
end
local duplicate = window(5, -750, 250)
windows, ids, focused = { duplicate, nw }, { 1, 5 }, nw
assert(cycle:clockwise() and focused == duplicate, "overlap tie-break")
assert(cycle:clockwise() and focused == nw, "stable overlap wrap")
windows, ids = { nw, window(6, 0, 0, { minimized = true }),
  window(7, 0, 0, { hidden = true }), window(8, 0, 0, { nonstandard = true }),
  window(9, 0, 0, { app = "com.apple.WindowManager" }),
  window(10, 0, 0, { screen = { id = function() return 2 end } }), ne },
  { 1, 6, 7, 8, 9, 10 }
assert(#cycle:orderedWindows() == 1, "exclude minimized/hidden/system/other screen/other Space")
assert(not cycle:clockwise(), "single window is a no-op")
focused = nil
assert(cycle:counterclockwise() and focused == nw, "no focused window")
ids = nil
local before = calls
assert(not cycle:clockwise() and calls == before, "Space failure must not broaden scope")
ids, windows = {}, {}
assert(not cycle:clockwise(), "empty Space")
cycle:bindHotkeys({ clockwise = { { "cmd" }, "`" }, counterclockwise = { { "cmd", "shift" }, "`" } })
local old = cycle._hotkeys.clockwise
cycle:bindHotkeys({ clockwise = { { "cmd" }, "`" } })
assert(not old.enabled and cycle:status().bindings.clockwise, "rebinding cleans old hotkeys")
cycle:stop()
assert(next(cycle:status().bindings) == nil, "stop removes bindings")
print("WindowCycle: all isolated behavior tests passed")
