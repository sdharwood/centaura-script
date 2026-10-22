# Cold War tools

`cold-war.luau` is a separate Cold War entrypoint adapted from the user-supplied Sneekys script. It does not change the Centaura entrypoint.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sdharwood/centaura-script/main/cold-war.luau"))()
```

## Controls

- Drag the header to move the panel. Right Shift hides/shows it; the CW button reopens it on touch devices.
- **Silent aim** and **Enemy ESP** start off on the first execution. Silent aim resets off on every reload. ESP retains its last setting on reload.
- **Radius** cycles through 80, 120, 180, 250, 350 and 500 pixels. It follows the mouse on desktop and the viewport centre on touch-only devices.
- **Prefer head** switches the order of head/torso/root candidates. R6 and R15 parts are supported.
- **Team filter** applies to both aim and ESP. It starts on. Visibility checks for aim remain on.
- **Enemy ESP** displays through-wall outlines, names, health and distance. Range cycles through 500, 1000 and 2000 studs. It updates five times per second.
- **Attach / retry** loads `PlayerScripts.BallisticsClient.ClientFire` and attempts to hook its selected function. Equip a gun first.
- **Export** cycles the named functions returned by ClientFire. `fireVolley` is preferred; otherwise a unique function other than `fire` is selected. Ambiguous exports require a second explicit attach after selection.
- **Print diagnostics to F9** prints the place ID, executor label, available exports, callback count and redirect count. It does not print weapon arguments or account data.
- **Unload** disconnects listeners, removes UI/ESP and disables redirection. An installed executor hook remains as a passthrough bridge, so repeated loads reuse it instead of stacking wrappers. Rejoin for a completely fresh client.

## Changes from the uploaded script

- Removed both remote UI/notification downloads. UI and ESP use Roblox instances; no Drawing API is needed.
- Clear raycasts return the target's position instead of leaving it nil.
- Fixed neutral/unassigned-team filtering, missing-part handling and R15 torso fallback.
- Removed reliance on Map folders and the automatic exclusion of barriers/vegetation from visibility checks.
- Named and checked the hook export rather than choosing an arbitrary non-fire value from a table.
- Missing modules, require failures and unavailable hooks leave the panel and ESP usable.
- Validates origin/direction argument types and copies the direction array before changing it. Existing direction magnitudes and the original function's multiple return values are preserved.
- Refreshes camera references and gates redirection during typing, focus loss, dragging, menus and death.
- Adds reload/unload handling and ESP cleanup for respawns, team changes, distance, death and player departure.

## Compatibility and diagnosis

**Not live-tested in Cold War or Real.** The uploaded script's expected weapon layout is retained: the fourth function argument is a Vector3 origin; the fifth is an array of Vector3 directions. No claim is made that the current game uses this layout or exposes the same module.

1. Spawn, equip a weapon and click **Attach / retry**.
2. Enable Silent aim and fire manually at a visible enemy inside the radius.
3. **Callbacks = 0** means the chosen function was not observed. The export may be wrong, the game may have changed, or the executor hook may not work. Try another export only if you know it is the weapon's volley function.
4. **Argument layout differs** means the callback was reached but its arguments did not match. Those calls are forwarded unchanged. Updating this adapter requires the current ClientFire source/signature.
5. **Callbacks increase, redirects stay 0** can also mean no eligible target, disabled silent aim, obstruction or paused input.
6. **Redirects increase** only confirms a local argument rewrite. It does not prove gunfire, a server hit, or successful hook integration.

Xeno/Real support and executor-provided functions are not assumed merely because they exist. There is no safety, undetectability or ban-prevention guarantee.

## Validation

The entrypoint passes a Lua 5.3 syntax check and 20 simulated execution checks using Fengari. These cover forwarding/return values, target selection with clear raycasts, argument validation, vector magnitude preservation, focus/team/death/wall filters, ESP creation and cleanup, reload bridge reuse, unloading, ambiguous exports and missing hooks. The mock does not emulate Roblox rendering, executor hooks, actual weapon networking or server hit validation.

With the repository's existing development dependencies installed:

```sh
npm install
node tests/run-cold-war.cjs
```

Before calling this live-tested, verify the panel, radius alignment, hook callbacks and gunfire in Cold War; then test teammates, walls, typing, menus, focus, respawn, team switches, ESP range, reload and unload.
