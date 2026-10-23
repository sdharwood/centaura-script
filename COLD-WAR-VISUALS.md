# Cold War dynamic crosshair and ESP

A separate, self-contained visual entrypoint built from the Cold War source exports supplied by the user on 23 October 2026. Includes only a ballistic impact crosshair and player ESP.

**Not live-tested. Not verified safe from bans.** The user reported a ban immediately after executing the source exporter while ESP had been running. Timing does not prove which action was detected; the exported physics and weapon code does not establish a cause. No additional in-game extraction is needed.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sdharwood/centaura-script/cold-war-dynamic-crosshair/cold-war-visuals.luau"))()
```

## Crosshair

The panel starts with both the crosshair and ESP switched off. The crosshair is an impact marker projected from the simulated flight path; it is not attached to screen centre and does not select or aim at players.

- **Dynamic crosshair:** connects to the equipped handheld gun's state and displays its predicted first-surface impact.
- **Shape:** cross or filled dot.
- **Size:** cross arm length or dot diameter, 2–32 pixels.
- **Cross thickness:** 1–8 pixels.
- **Cross centre gap:** 0–20 pixels.
- **Crosshair colour:** any six-digit RGB hex colour, such as #70D6BC.
- **Impact range label:** optional path distance in metres; “limit” distinguishes a lifetime/range endpoint from a surface hit.
- Type numeric values or a hex colour, then leave the field to apply. Invalid values retain the prior setting; out-of-range numbers are clamped.

The marker recomputes its world-space prediction at up to 20 Hz and reprojects it with the current camera every render frame. It pauses for typing, menus, lost focus, missing cameras, death and unequipping. Appearance settings persist across reloads. Crosshair and ESP master switches reset off.

## What the exported code established

The supplied Ballistics.Trajectory uses the following free-flight model. For launch direction d, muzzle speed v, drag coefficient k, gravity g and elapsed time t:

- Forward travel is v*t when k is approximately zero.
- Otherwise forward travel is v/k * (1-exp(-k*t)).
- Position is origin + direction*forwardTravel - worldUp*(g*t*t/2).

WeaponSource maps the current ammunition's MuzzleVelocity to muzzle speed and Drag to k, defaulting a missing Drag to 1. Gravity is omitted from that weapon profile, so Trajectory uses workspace.Gravity. ProjectileTypes supplies a five-second lifetime and 5,000-stud travel limit.

Discharge chooses the animated viewmodel muzzle in first person when WeaponViewmodel.isShown() is true; otherwise it uses the physical attachment. It corrects an obstructed muzzle origin from the real character's Right Arm, applies the current ZeroController.zeroAngle(), then adds random spread. This build reproduces that origin correction, attachment selection and zeroing, and ignores random spread as requested.

A zeroing angle of zero intentionally overrides DefaultAngle, matching Lua's treatment of zero as truthy. Active muzzle and ammunition changes are read at prediction time rather than hard-coded to Muzzle1 or ammo type 1.

The existing game CrosshairController traces straight rays. It does not integrate this ballistic curve.

## Live data access

The build requires the game's existing ZeroController, WeaponViewmodel and CollisionGroups modules. It uses bounded, read-only upvalue access to ZeroController.zeroAngle to obtain the current weapon state, validating that it belongs to the currently equipped Tool. It reads currentMuzzle.config, getBulletIndex(), attachment and viewmodelAttachment. It does not call firing, attach, zero-scroll or projectile-casting methods.

This needs an executor with working require and debug.getupvalues or debug.getupvalue/getupvalue. No decompile, getsenv, GC scans or weapon hooks are used. These choices do **not** establish invisibility to the game's checks. If the executor returns a separate module state, strips access, or the game changes its interfaces, the panel reports unavailable data and the marker stays hidden. It does not substitute a centre-screen reticle or guessed ballistics.

## Prediction limits

- Only handheld Tool weapons with the exported controller structure are supported. Mounted vehicle guns need a separate adapter.
- This is the predicted **first contact**, not the final impact after penetration or ricochet.
- Random spread is excluded. Explosions and moving-target lead are not simulated.
- Raycasts use the weapon's team collision group and the exported Arming exclusions; water and live duds remain queryable.
- Lifetime and accumulated path-distance limits match the supplied default weapon pipeline.
- The curve is sampled with a timestep derived from the current frame, bounded to 1/240–1/20 seconds. Analytic positions match the exported model; sampled collisions can differ from later live frames, particularly near edges or moving geometry.
- Network quantization, streaming, latency, changing obstacles and server validation can also produce differences.
- Raycast work depends on flight length. Up to 1,202 segments are allowed per prediction; a budget failure hides the marker and reports that condition.
- Range labels use the exported ZeroSolver's 3.57 studs/metre conversion.
- The build does not change the game's existing reticle or cursor.

## Player ESP and lifecycle

Player outlines and nametags are independent. Health/distance details, teammate display, faint fill, enemy colour and range have separate controls. Dead, protected, departed and out-of-range characters are excluded.

The ESP portion creates only its own Highlight and BillboardGui instances. It does not edit Cold War's Teammate/MarkersGui objects. Focus loss clears it; team/character changes refresh at five Hz. Right Shift collapses the panel, the header is draggable, and the panel scrolls on short viewports.

Unload removes both features' visuals and listeners. Reload replaces the previous controller. If an older silent-aim script was run in the same client, unloading its controller does not remove executor hooks that were already installed. A fresh client is required to clear those old hooks.

## Validation

The actual entrypoint passed **70 offline Fengari checks**, retaining the ESP cases and adding analytic drag/gravity results, active ammo, zero-angle semantics, first-person versus physical muzzle selection, collision filters, first contact, path/lifetime limits, muzzle pushback, cross/dot style, numeric/hex controls, missing state, focus, camera and unload behavior.

```sh
npm install
node tests/run-cold-war-visuals.cjs
```

These are simulated service/geometry tests. They do not certify live Cold War behavior, executor module-cache semantics, rendering, performance or anti-cheat safety. No anti-cheat bypass or detection-hiding logic is included.
