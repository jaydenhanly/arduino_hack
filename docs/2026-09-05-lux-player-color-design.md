# Lux-driven player color design

## Goal

Prototype using the Uno Q's Modulino Light sensor to drive a live visual
variable in gameplay, scoped to a single, easily observable asset: the
snake's own color in the snake stage. Low ambient lux (a dark room) should
brighten the snake; high ambient lux (a bright room) should darken it. Off
the board, or in a well-lit desktop test environment with no bridge process
writing lux data, the snake stays its normal color.

This is a deliberate inversion of the ambient-matching "dark mode" feature
this project previously implemented and then removed (`light_sensor.gd` +
`presentation_director.gd`'s `dark_level`/`palette()` darkening, which faded
the *whole stage palette* toward black as the room got darker). That feature
is gone; this is a new, narrower feature reusing the same sensor-reading
mechanics for a different, single-asset effect.

## Scope

Snake stage only, for this first test. The other three stages render their
player very differently (frogger and asteroids use fully hardcoded literal
colors baked directly into their `draw_stage()` calls; maze already routes
its player through a per-stage palette lookup for a different reason) and
have no equivalent single hook to reuse cleanly. Extending this to other
stages, if wanted later, is a separate follow-up.

## Component: `scripts/controller/light_sensor.gd` (recreated)

Same reading and smoothing mechanism as the removed version:

- Polls `STATE_PATH = "/game/light_state.json"` every `POLL_INTERVAL = 0.5s`.
  This file is written externally by the board's bridge process reading the
  Modulino Light module; off the board it never appears, so `_poll()` is a
  no-op and the target stays at its default (no tint).
- Runs its own `_process` so the fade keeps tracking even while gameplay is
  paused (matches prior behavior).
- Smooths the current value toward the target at `FADE_PER_SECOND = 0.5`/sec
  via `move_toward`, so changes glide rather than snap.

What's different from the removed version: instead of an unsigned
`dark_level` in `[0, 1]` (0 = full brightness, 1 = darkest reading, always
darkening), it computes a **signed** `tint` in `[-1, 1]`:

- `lux <= LUX_LOW` (`15.0`, reused constant) → `tint = 1.0` (brightest)
- `lux >= LUX_HIGH` (`250.0`, reused constant) → `tint = -1.0` (darkest)
- Linear in between; `tint = 0.0` at the midpoint lux (no change from the
  snake's normal colors)

```gdscript
static func tint_for_state(text: String) -> Variant:
    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("lux"):
        return null
    var lux: float = float(parsed["lux"])
    var normalized := clampf((lux - LUX_LOW) / (LUX_HIGH - LUX_LOW), 0.0, 1.0)
    return 1.0 - 2.0 * normalized
```

(Pure, testable without a board or `/game` mount — same split-out shape as
the removed `level_for_state`.)

A static helper turns a signed tint into an actual color:

```gdscript
const MAX_TINT := 0.6

static func tinted(base_color: Color) -> Color:
    if _current_tint > 0.0:
        return base_color.lerp(Art.LIGHT, _current_tint * MAX_TINT)
    elif _current_tint < 0.0:
        return base_color.lerp(Color.BLACK, -_current_tint * MAX_TINT)
    return base_color
```

`MAX_TINT = 0.6` is reused from the removed feature's `MAX_DARKEN`, so the
snake never fully bleaches to `Art.LIGHT` or crushes to pure black — it stays
a tint, not a replacement.

## Hook-in: `game_board.gd::_draw_snake`

Currently the head is drawn with the fixed constant `Art.INK` and the body
with `Art.DARK`; eyes are drawn with `Art.LIGHT`. This changes to:

- Head: `LightSensor.tinted(Art.INK)` (was `Art.INK`)
- Body: `LightSensor.tinted(Art.DARK)` (was `Art.DARK`)
- Eyes: **unchanged**, stay fixed at `Art.LIGHT` regardless of lux. This is
  deliberate: at the brightest reading the body tints *toward* `Art.LIGHT`,
  so if the eyes moved too they'd risk disappearing into the body at the
  extremes. Fixed eyes keep the snake readable at every lux value.

## Wiring: `scripts/game_flow.gd`

Re-add, mirroring exactly how it was wired before its removal:

- `const LightSensor = preload("res://scripts/controller/light_sensor.gd")`
- `var light_sensor: Node`
- In `_ready()`: `light_sensor = LightSensor.new(); add_child(light_sensor)`

No other part of `game_flow.gd` changes. This module has no relationship to
input handling, `hardware_feedback.gd`, or `vibration_transport.gd`.

## Testing

Recreate `tests/hardware/light_sensor_probe.gd`, adapted to check the new
signed-tint math instead of the old unsigned-darken math:

- `tint_for_state()` returns `1.0` at `LUX_LOW`, `-1.0` at `LUX_HIGH`, `0.0`
  at the midpoint, clamps beyond both ends, and returns `null` for malformed
  or lux-less JSON (mirrors the exact edge cases the removed probe covered).
- `tinted()` returns `base_color` unchanged at `tint = 0`, lerps toward
  `Art.LIGHT` for positive tint and toward `Color.BLACK` for negative tint,
  and never exceeds `MAX_TINT` at the extremes.

Re-add `light_sensor` to the `tests/hardware/run.sh` probe loop (it was
removed in the same change that deleted the probe) and re-add
`"controller/light_sensor"` to `release_check.gd`'s manifest-inclusion list.

## Non-goals

- No changes to maze, frogger, or asteroids player rendering.
- No revival of the global stage-palette "dark mode" (`presentation_director.gd`
  stays as-is: `palette(stage)` returns unmodified colors).
- No new UI, settings, or toggle to disable this — off-board it's already a
  no-op by construction (no `/game/light_state.json` to read).
