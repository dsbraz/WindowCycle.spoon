# WindowCycle

Cycle keyboard focus clockwise around the screen, across applications in the
active macOS Space on the focused window's monitor, or cycle between monitors.

Install into your Hammerspoon configuration:

```sh
git clone https://github.com/dsbraz/WindowCycle.spoon.git ~/.hammerspoon/Spoons/WindowCycle.spoon
```

Then add to `init.lua`:

```lua
hs.loadSpoon("WindowCycle")
spoon.WindowCycle:bindHotkeys({
  clockwise = { { "cmd" }, "`" },
  counterclockwise = { { "cmd", "shift" }, "`" },
  nextMonitor = { { "alt" }, "`" },
  previousMonitor = { { "alt", "shift" }, "`" },
})
```

The Command bindings replace the native Command-grave window switcher. Each press
moves one step; Shift reverses the direction. The pointer stays in place.

Window centers are sorted by angle around the center of the full screen,
clockwise from twelve o'clock. Equal angles are ordered by distance from the
screen center, then window ID. Bringing a window forward does not reorder the
cycle; moving/resizing, opening, or closing windows updates it on the next press.

Only standard, visible, non-minimized windows on that monitor and Space are
eligible. Hidden applications, desktop surfaces, and windows on other Spaces
are excluded. Overlapped windows remain eligible. Stage Manager membership
is not a separate filter: eligible windows are selected by Space, not by stage.
If Space lookup fails, no window is focused. With no eligible focused window,
the cycle starts at the first (or last, in reverse) candidate.

Option-grave cycles monitors from left to right, wrapping at the end; Shift
reverses the direction. Monitors at the same horizontal position are ordered
top to bottom. Each press focuses the frontmost eligible window in the
destination monitor's active Space and moves the pointer inside that window.
On an empty monitor, only the pointer moves to its center; the next press
continues from that monitor. With one monitor, nothing changes.

## API

- `clockwise()` / `counterclockwise()`: focus the next/previous window.
- `nextMonitor()` / `previousMonitor()`: focus the next/previous monitor.
- `orderedWindows()`: inspect the current clockwise list without changing focus.
- `bindHotkeys(mapping)`: replace bindings.
- `stop()`: delete bindings and clear monitor-cycle state.
- `status()`: report version and enabled bindings.

Requires Hammerspoon with Accessibility permission and `hs.spaces` support.
It works with FocusFollowsMouse's existing keyboard-focus protection; no
cross-Spoon callbacks are needed. Window cycling leaves the pointer in place;
monitor cycling moves it to the destination.

## Tests

Run in the Hammerspoon console:

```lua
dofile(hs.configdir .. "/Spoons/WindowCycle.spoon/tests.lua")
```

These isolated tests cover clockwise and reverse wraparound, stable overlap
ordering, Space/monitor eligibility, missing focus, empty lists, failed Space
lookup, and hotkey cleanup without changing real window focus.
