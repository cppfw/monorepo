# Plan: Mouse grab (ruisapp issue #5)

Issue: https://github.com/cppfw/ruisapp/issues/5 — "Add mouse grab exclusively to window to allow e.g. making an FPS game, where there is no mouse cursor, but mouse controls the 3d camera."

## Summary

Add per-window **mouse grab** (aka relative/pointer-lock mouse mode): hide the cursor,
lock the pointer to the window, and report mouse motion as **per-event displacement
(deltas)** instead of absolute window position.

## Hypothesis check (pos as delta from 0,0 in grab mode?)

Yes — this is the natural and implementable contract, with one refinement: **per-event
delta**, not accumulated position.

In grab mode the cursor is pinned to the window center, so the notion of "absolute
position" does not exist. What a game needs is the pointer displacement of *each*
motion event (e.g. `yaw += dx * sensitivity`). If `pos` instead carried the
*accumulated* relative position (as SDL's relative mode reports it raw, i.e.
center-relative coordinates), a game applying `pos` on every event would integrate
quadratically and spin faster the longer it runs. So the contract is:

> **When the window's mouse is grabbed, `mouse_move_event.pos` carries the pointer
> displacement (delta) of this single event, relative to the origin (0,0) which
> corresponds to the window center.** In logical pixels, same units as normal mode.

All backends can produce per-event deltas natively or by trivial bookkeeping:

| Backend | Delta source |
|---|---|
| SDL | `SDL_SetRelativeMouseMode` → `e.motion.xrel`/`yrel` (per-event delta) |
| X11 | grab + manual delta + re-center via `XWarpPointer` (or XI2 `dx`/`dy` later) |
| Wayland | `relative-pointer-unstable-v1` protocol (`dx`/`dy` per event) |
| Windows | `SetCapture` + manual delta + re-center via `SetCursorPos` |
| macOS | cursor hide + manual delta + re-center via `NSEvent warpMouseToLocation:` |
| Android/iOS | no mouse — no-op |

Note that today the SDL glue already breaks under relative mode for exactly this
reason: `glue.cxx` sends `SDL_GetMouseState(&x, &y)` as absolute position, but in
relative mode that state is center-relative. The plan fixes that.

## API changes

### ruis (`repos/ruis/src/ruis/render/native_window.hpp`)

Follow the existing `set_mouse_cursor_visible` / `is_mouse_cursor_visible` pattern:

```cpp
// ============
// = mouse grab =

/**
 * @brief Grab the mouse pointer exclusively to the window.
 * When grabbed, the mouse cursor is hidden and locked to the window, and mouse
 * move events report per-event pointer displacement (delta) from the window
 * center instead of absolute window position.
 * The grabbed state is sticky across focus changes: when the window regains
 * focus the pointer is locked again automatically (see "Grab and window
 * focus" in plan/mouse_grab.md).
 */
virtual void set_mouse_grabbed(bool grabbed) {}

/**
 * @brief Returns the grabbed state (intent) set via set_mouse_grabbed().
 * Survives focus changes; see "Grab and window focus" in plan/mouse_grab.md.
 */
virtual bool is_mouse_grabbed() const noexcept
{
    return false;
}
```

Also document the grab-mode semantics of `mouse_move_event.pos` in
`repos/ruis/src/ruis/util/events.hpp` and of `gui::send_mouse_move()` in
`repos/ruis/src/ruis/gui.hpp`.

### ruisapp (`repos/ruisapp/src/ruisapp/window.hpp` / `window.cpp`)

Convenience pass-throughs on `ruisapp::window` (mirroring how `render()` delegates
to `gui.context.get().window()`):

```cpp
void set_mouse_grabbed(bool grabbed);
bool is_mouse_grabbed() const;
```

Applications can also reach `ruis::render::native_window` directly via
`win.gui.ctx().window()` (as `ruis::context::window()` already exposes it);
the convenience methods just make the feature discoverable.

Optional: `bool mouse_grabbed = false;` in `ruisapp::window_parameters` to grab
from window creation (analogous to `fullscreen`). Recommended, low cost.

### Multi-window grab semantics

There is exactly **one mouse cursor per OS**, so pointer grab is a single global
state: at most **one window may hold the grab at any moment**. Grab ownership is
**transferable**: when a second window grabs while another window holds the grab,
**the grab moves to the new window** and is lost by the previous one. Rules:

- `set_mouse_grabbed(true)` on window B while window A holds the grab: the glue
  releases the OS grab state of A (ungrab A, restore A's cursor according to A's
  `mouse_cursor_visible` state, reset A's bookkeeping) and then acquires the grab
  for B. Both calls succeed; A's `is_mouse_grabbed()` returns false afterwards.
- `set_mouse_grabbed(false)` on the holder: releases the grab. If another window
  called `set_mouse_grabbed(true)` in the meantime, that window holds it.
- Destroying the holder (`destroy_window`): the glue releases the OS grab state
  and resets its holder bookkeeping. No grab survives window destruction.
- Holder window losing focus: the OS-level lock is released (by the OS or
  actively by the glue) but the grab intent is preserved and re-activated
  automatically on focus regain — see "Grab and window focus" below.
- While window B holds the grab, the pointer is trapped in B, so window A
  receives no mouse events at all until B releases the grab. Nothing special to
  implement; backends must not assert on A's event path being idle.

Implementation consequence: each glue backend must track the **single current
grab holder** (one `std::optional<window*>` in the per-display/per-application
glue struct, next to the existing per-window `mouse_cursor_visible` bookkeeping),
not a plain per-window bool. Every backend's `set_mouse_grabbed(true)` starts
with "if the holder is another window, release it".

### Grab and window focus

The grab has two layers:

- **Grab intent** — the per-window state set by `set_mouse_grabbed()`. Sticky:
  it survives focus changes and is cleared only by `set_mouse_grabbed(false)`
  or by destroying the window. `is_mouse_grabbed()` returns this intent.
- **OS-level lock** — the actual pointer trap (hidden cursor, relative motion
  events). Active only while the grabbing window has input focus: most OSes
  release pointer capture when the window is deactivated, and mouse events
  would not be delivered to an unfocused window anyway.

**When the window loses focus while grabbed:**

- The pointer lock is released and the cursor becomes visible again; the mouse
  behaves normally elsewhere (the user can switch to other apps/windows). On
  platforms where the OS does not release it on its own, the glue must actively
  release it: X11 (`XGrabPointer` would otherwise persist — the classic
  "trapped mouse" behavior), macOS (`[NSCursor hide]` persists at app level).
  On Windows (`SetCapture` is lost on deactivation) and SDL (relative mode
  stays enabled globally but delivers no events) there is nothing to release.
- The grab intent is preserved: `is_mouse_grabbed()` keeps returning true.
- The window stops receiving mouse events anyway (it has no focus).
- **Mouse buttons held down are released synthetically** — see below.

**When focus returns to the window:**

- The glue re-activates the OS lock automatically: re-capture, hide the
  cursor, warp the pointer to the window center. The app's camera control
  resumes with no application-side work (no need to call
  `set_mouse_grabbed(true)` again).
- **Delta tracking is reset at (re-)grab**: each backend's `last_pos` / delta
  bookkeeping is re-initialized to the new grab origin (window center), so the
  first reported delta after re-grab is a real movement, not a spurious jump
  from wherever the cursor was before. No mouse-move event is synthesized at
  the moment of (re-)grab.

#### Mouse buttons held down when the window loses the grab

**The problem.** The OS delivers mouse button events only to the window that
has pointer capture/focus. If the user holds a button (e.g. firing in an FPS)
and the window loses the OS-level lock (focus loss, grab transferred to another
window, window destruction), the physical button release is delivered to
wherever the pointer is at that moment — never to this window. The app's
logical state is left desynced: the FPS keeps firing forever, a ruis widget
that captured the mouse (the `mouse_capture_map` in `container.cpp`) keeps
receiving move events, pressed-button visual state sticks.

**The rule: yes, release events must be sent — the backend synthesizes them.**
On every transition that deactivates the window's OS-level mouse lock (focus
loss, grab transfer, window destruction), the glue synthesizes a
`button_action::release` event for each button the window logically has
pressed, then clears its pressed-button state. The events go through the normal
event path (`gui.send_mouse_button`), so ruis-level state unwinds cleanly (the
container drops the mouse capture on the release, button widgets leave the
pressed state). In grab mode the synthesized release carries `pos = (0,0)`
(the grab origin), consistent with grab-mode delta semantics.

Precedent: the Windows glue already does exactly this for `WM_MOUSELEAVE`
(Windows delivers no mouse events for the cursor outside the window):
`app_window::send_mouse_button_event` (`windows/application.cxx`) maintains
`win.mouse_button_state` (a `utki::flags<ruis::mouse_button>` of logically
pressed buttons, also deduplicating redundant physical releases), and on mouse
leave releases every pressed button with an off-window coordinate. The same
pattern (per-window pressed-button state + "release all" helper) must be added
to the SDL, X11, Wayland and macOS glues as part of the grab support. It is
not needed in normal mode on the other platforms: the X server does an implicit
pointer grab on `ButtonPress` and the Wayland compositor delivers the whole
click gesture to the surface that received the press, so the release always
reaches the pressing window there.

Which transitions trigger the synthesized releases:

- Focus loss while the window is the grab holder: yes (synthesize, then
  release the lock).
- Grab transferred from A to B: yes, A synthesizes for its held buttons; B
  starts with an empty button state.
- Destruction of the holder: best effort, while the GUI is still alive
  (otherwise the state dies with the window anyway).
- Explicit `set_mouse_grabbed(false)` while the window still has focus: **no**
  — the window keeps receiving events, so the physical release arrives
  normally; synthesizing here would drop a still-held button early.
- Focus regain: nothing to synthesize (button state was already cleared).

Caveat: if the user is physically still holding the button across the focus
loss (holding fire while alt-tabbing and coming back quickly), the synthesized
release is premature and the app sees a short press/release sequence instead
of a long press; the later real release is deduplicated and ignored. Acceptable
trade-off — identical to the existing Windows mouse-leave workaround.

## Backend implementations

### SDL (`src/ruisapp/glue/sdl/`)

- `set_mouse_grabbed(true)`: `SDL_SetRelativeMouseMode(SDL_TRUE)`. SDL hides the
  cursor and (with the default `SDL_HINT_MOUSE_RELATIVE_MODE_CENTER`) pins the
  pointer to the window center.
- `set_mouse_grabbed(false)`: `SDL_SetRelativeMouseMode(SDL_FALSE)`; SDL restores
  the cursor; keep the existing `mouse_cursor_visible` bookkeeping so a previously
  hidden cursor stays hidden.
- `glue.cxx` `SDL_MOUSEMOTION`: when relative mode is active, send
  `vec2(e.motion.xrel, e.motion.yrel)` (per-event delta) instead of
  `SDL_GetMouseState`.
- `SDL_SetRelativeMouseMode` is a global app state: SDL keeps it enabled
  across focus loss, and on focus gain SDL re-wars the pointer to the center of
  the *newly focused* window by itself. Track the single holder in
  `application_glue` and sync relative mode on every window focus event:
  enable it when the holder gains focus, disable it when focus moves to a
  non-holder window (otherwise SDL would start delivering relative events to
  the wrong window), and disable it when the holder is destroyed. Grabbing a
  second window transfers the grab: release the old holder first.

### X11 (`src/ruisapp/glue/linux/xorg/`)

- `set_mouse_grabbed(true)`:
  - `XGrabPointer(display, window, True, ButtonPressMask|ButtonReleaseMask|PointerMotionMask, GrabModeAsync, GrabModeAsync, window, None, CurrentTime)`
    (traps pointer; pointer stays inside the window),
  - hide cursor with an empty cursor (`XDefineCursor`), reusing the `cursor.hxx`
    cursor-loading machinery,
  - record last pointer position (window center).
- `MotionNotify` while grabbed: `delta = pos - last_pos; last_pos = pos;` send
  `vec2(delta)`; then re-center: `XWarpPointer(display, None, window, 0, 0, 0, 0, w/2, h/2)`.
  With the cursor hidden the warp is invisible. (v2 alternative: XInput2
  `XI_RawMotion` events carry `dx`/`dy` without warping — deferred.)
- `set_mouse_grabbed(false)`: `XUngrabPointer`, restore cursor.
- While grabbed, `EnterNotify`/`LeaveNotify` should not arrive (pointer is
  trapped); guard hover state updates so a stray event can't desync
  `set_hovered`/cursor visibility.
- Track the single holder in the display wrapper; grabbing a second window
  transfers the grab (ungrab the old holder first), and destroying the holder
  releases the grab.
- Focus: `XGrabPointer` persists across focus loss on X11, so the glue must
  actively `XUngrabPointer` + restore the cursor when the holder loses input
  focus (and synthesize button releases), and re-grab + re-center + reset the
  delta bookkeeping when it regains focus.

### Wayland (`src/ruisapp/glue/linux/wayland/`)

Wayland has no client-side pointer warping; true relative motion requires the
**`relative-pointer-unstable-v1`** protocol.

- Add the protocol bindings: generate/include
  `relative-pointer-unstable-v1-client-protocol.h` (from wayland-protocols, the
  same source `xdg-shell-client-protocol.h` comes from — check the existing
  build/package setup for how xdg-shell header is provided and mirror it).
- On grab: request `zwp_relative_pointer_v1` from the seat
  (`wl_seat.get_relative_pointer`), send a `NULL` cursor surface to hide the
  cursor (existing `wayland_cursor_theme_wrapper` plumbing).
- `relative_motion` listener: emit
  `gui.send_mouse_move(vec2(fixed2float(dx), fixed2float(dy)), 0)`.
  Apply the 3x3 transformation matrix (`t_11*dx + t_12*dy`, `t_21*dx + t_22*dy`)
  so trackpad/touchpad rotation is handled (the protocol requires it).
- On ungrab: destroy `zwp_relative_pointer_v1`, restore normal cursor.
- If the compositor does not support the protocol (check
  `wayland_registry` global list): degrade gracefully — log a warning, leave
  `is_mouse_grabbed()` false. (No emulation is possible on Wayland.)
- Focus: when the pointer is no longer focused on a client surface the
  compositor stops delivering `relative_motion` (nothing to release on the
  protocol side); on re-entry re-send the `NULL` cursor surface (the compositor
  resets the cursor on pointer leave) — the `zwp_relative_pointer_v1` object
  stays bound and resumes on its own. Synthesize button releases per "Grab and
  window focus" when the holder loses focus.

### Windows (`src/ruisapp/glue/windows/`)

- `set_mouse_grabbed(true)`: `SetCapture(hwnd)` (trap pointer, incl. outside the
  window), `ShowCursor(FALSE)`, re-center cursor with `SetCursorPos` to the
  window client center.
- `WM_MOUSEMOVE` (in `display.cxx`) while grabbed:
  `delta = (lparam) - center;` send `vec2(delta)`; `SetCursorPos(center)` to
  re-center.
- Recompute/re-apply the center on `WM_WINDOWPOSCHANGING`/resize so the warp
  target stays the client center.
- `set_mouse_grabbed(false)`: `ReleaseCapture()`, `ShowCursor(TRUE)`
  (respect existing `is_mouse_cursor_visible()` state), restore cursor position
  policy (the existing `WM_MOUSELEAVE` show-cursor logic already handles
  re-entry).
- Release capture in the window destructor.
- Focus: `SetCapture` is lost automatically when the window is deactivated
  (nothing to release); on re-activation, if the window still holds the grab
  intent, re-`SetCapture`, hide the cursor, re-center, and reset the delta
  bookkeeping. The existing `win.mouse_button_state` release-all pattern
  (currently triggered on `WM_MOUSELEAVE`) must also be triggered on grab
  loss/focus loss of the holder.
- (v2: register raw input `WM_INPUT` for unaccelerated deltas — deferred.)

### macOS (`src/ruisapp/glue/macos/`)

No native relative mode; emulate:

- `set_mouse_grabbed(true)`: `[NSCursor hide]`, record last location, warp cursor
  to window center via `[NSEvent warpMouseToLocation:]`.
- `mouseMoved:` / `mouseDragged:` (both funnel to `mouseMoved` — already the case)
  while grabbed: `delta = location - last; last = location;` send `vec2(delta)`;
  warp cursor back to the window center.
- `set_mouse_grabbed(false)`: `[NSCursor unhide]` (respect the existing
  `set_mouse_cursor_visible` state).
- Focus: on focus loss, `[NSCursor unhide]` (the NSCursor hide count persists
  at app level) and synthesize button releases per "Grab and window focus"; on
  becoming key window again, re-hide, re-warp to the center, and reset the
  delta bookkeeping.

### Android / iOS

No mouse — inherit the no-op base virtuals. No changes.

## ruis GUI interaction

- Widget-level mouse capture (the `mouse_capture_map` in
  `repos/ruis/src/ruis/widget/container.cpp`) is orthogonal and keeps working in
  grab mode: a `ruis::mouse_proxy` (or any widget) that consumes the button press
  captures subsequent move events and receives them with `pos` = per-event delta —
  exactly what an FPS controller widget needs. No ruis widget changes required.
- `gui::send_mouse_move()` calls `rw.set_hovered(rw.rect().overlaps(pos))`. In grab
  mode `pos` is a delta hovering around (0,0), so the hovered state just tracks
  "is the delta inside the root rect" — harmless. Optionally skip the hover
  recompute when `is_mouse_grabbed()` (cleaner semantics, one conditional);
  acceptable either way.
- Mouse wheel/button events: in grab mode button events keep carrying the (small)
  delta as `pos`; wheel handling is unaffected. Document that `pos` in button
  events is also delta-based in grab mode.
- Synthesized button releases (grab loss, see "Grab and window focus") flow
  through `gui::send_mouse_button()` like any release; the container's capture
  handling removes the capture on release, so a widget that captured the mouse
  during a grab is released correctly.

## Probe & tests

- `ruisapp::application::probe()` (in `application.cpp`): add commands so the
  probe-based test suite can drive and verify the feature headlessly:
  - `set_mouse_grabbed { index { N } enabled { true|false } }` → `ok` /
    `error { ... }` (invalid index),
  - `get_mouse_grabbed { index { N } }` →
    `mouse_grabbed_state { true|false }`.
- `tests/app`: no code changes strictly needed (probe is app-level); add a CI
  test (ruisapp test suite) that toggles grab on window 0, queries the state
  back, and toggles off.
- Manual test matrix (CI where the platform allows):
  - SDL backend on Linux: grab → cursor hidden, camera-control demo rotates with
    the mouse at any speed, ungrab restores cursor and absolute positions;
  - X11 and Wayland (Linux): same;
  - Windows and macOS: same;
  - grab → hold LMB → alt-tab away and back: no stuck-firing (synthesized
    release on focus loss), the grab auto-resumes with no spurious delta;
  - grab transfer A→B while A holds a button: A receives synthesized releases.
- Consider a small FPS-ish demo in `examples/` or `tests/app` (root widget with a
  `mouse_proxy` that integrates `pos` deltas into a yaw/pitch shown as text) —
  useful for manual verification on each backend.

## Implementation order

1. ruis: `native_window::set_mouse_grabbed/is_mouse_grabbed` + docs in
   `events.hpp`/`gui.hpp`.
2. ruisapp: `window::set_mouse_grabbed/is_mouse_grabbed` pass-throughs (+
   `window_parameters::mouse_grabbed` if adopted).
3. SDL backend (default desktop backend; unblocks immediate use & CI).
4. X11 backend.
5. Windows backend.
6. macOS backend.
7. Wayland backend (needs relative-pointer protocol bindings; can be a
   follow-up commit).
8. Per-backend pressed-button state: generalize the Windows
   `mouse_button_state` + release-all pattern (the `WM_MOUSELEAVE` workaround)
   to SDL, X11, Wayland and macOS; wire the release-all into every
   grab-deactivating transition.
9. Probe commands + tests.
10. Docs: update the `mouse_move_event`/`send_mouse_move` doxygen, ruisapp wiki
    page about the window API.

## Alternatives considered

- **Add an explicit `vec2 delta` field to `mouse_move_event`** (populated in both
  modes, `pos` stays absolute in normal mode via `gui` tracking the last pos).
  More regular API, but touches the event struct, the gui (last-pos state), and
  every backend (must compute deltas in normal mode too). Strictly not needed for
  the FPS use case; keep as a follow-up if widget code later wants per-event
  deltas in normal mode (e.g. flickable improvements).
- **SDL `SDL_SetWindowGrab` (window grab, not relative mode)**: traps the pointer
  but keeps reporting absolute positions — wrong semantics for FPS; rejected.
- **XInput2 / Windows raw input / `WM_INPUT` for unaccelerated deltas**: better
  feel (no OS pointer acceleration), but adds significant per-backend complexity;
  deferred to v2, the manual-delta approach already behaves acceptably.
