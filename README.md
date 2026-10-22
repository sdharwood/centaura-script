# Centaura camera aim assist

The `main-xeno.luau` entrypoint contains camera aim assist (v2.1), optional aligned autofire and enemy ESP. It smoothly turns the camera toward a visible enemy while right-click is held and a gun with a `Barrel` part is equipped. The radius is centered on the camera crosshair.

Camera assist and ESP use Roblox camera, input, GUI, raycast, Highlight and BillboardGui APIs. Autofire additionally requires a working executor-provided `mouse1click` function. It does not require `getsenv`, `getgc`, `getconnections`, `hookfunction`, upvalue access, the Drawing API or a remote UI library. Optional `getgenv` is used only to retain the controller between executions; `shared` is the fallback.

No undetectability or ban-prevention guarantee is made. Using ordinary rendering APIs does not make an executor or its scripts undetectable.

## Run

Rejoin once if you previously ran the old silent-aim version. The new script detects its old state and asks for a clean session.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sdharwood/centaura-script/main/main-xeno.luau"))()
```

## Controls

| Control | Behaviour |
| --- | --- |
| Hold right-click | Assist camera aiming while an eligible enemy is inside the radius |
| Release right-click | Stop assisting immediately |
| Camera assist toggle | Pause or enable assistance |
| Show radius toggle | Hide or show the centered radius circle |
| Autofire toggle | Opt into click attempts while holding right-click with an aligned, eligible target |
| Enemy ESP toggle | Show enemy outlines, names, distance in studs and current health through walls |
| Targeting radius | Set the acquisition radius, 40–650 pixels |
| Aim strength | Set camera response, 3–30 per second; higher turns faster |
| Autofire rate | Set click attempts, 2–10 per second; the weapon's own fire rate still applies |
| Right Shift | Hide or show the panel |
| Header | Drag the panel |
| Unload assist | Remove the UI, render binding and event listeners |

Autofire and ESP default to **off** on their first run. Enable them separately in the panel. Subsequent executions preserve settings. If autofire was already enabled when reloading, refocus Roblox or press right-click again before it resumes, so a reload from an external window cannot immediately reuse stale held-button state.

Autofire waits until the chosen aim point is within 8 screen pixels of the crosshair after the camera update. It rechecks visibility, team, health, focus, input and the equipped gun immediately before each click. It does not fire while the left mouse button is already held, and allows only one pending click task. A missing or failing `mouse1click` disables autofire without disabling camera aim or ESP. The script requests complete clicks, rather than holding a simulated mouse button down.

ESP updates five times per second and shows living enemy characters within 2,000 studs. It excludes teammates and forcefield-protected players. The current aim target uses the accent colour; other enemies use red. ESP is independent of the aim radius and camera-assist toggle. Disabling ESP or unloading removes its highlights and labels; respawns, team changes, player departures and out-of-range characters are refreshed automatically. ESP is hidden when window focus is lost or Roblox's menu is open.

Team and wall checks are always enabled. Visibility is checked from both the camera and gun barrel. Dead and forcefield-protected characters are excluded. A valid target is retained while held, then released when it becomes ineligible. Head targeting falls back to the root part when needed.

Assistance pauses while typing, using the panel, opening Roblox's menu, losing window focus or using a scriptable camera. It also waits through death, respawn, unequipping and camera replacement. Running this version again cleans up the previous camera controller and preserves its settings.

## Status and troubleshooting

The status card is below **Aim / fire: team + wall checks**. Its bottom line shows autofire state and the ESP count, or an optional-feature error.

- **Ready**: a gun is equipped; hold right-click.
- **Tracking: …**: the camera update callback found a target and wrote a camera rotation.
- **No visible target**: no eligible enemy passed the radius and both visibility checks.
- **Equip a gun**: the equipped tool has no direct `Barrel` BasePart.
- **Input paused / Camera paused / Waiting for spawn**: assistance is intentionally suspended.
- **Needs attention**: read the detail and the `[Centaura]` warning in F9. Toggle Camera assist off and on to retry after resolving the cause.

The camera-update counter measures executed camera writes, not successful hits. Weapon spread, recoil and server hit validation still affect shots. Another game camera script may overwrite the result. Camera assistance visibly moves your aim; it is not silent aim.

Autofire's **Click attempted** state and attempt counter mean the click function was called, not that Xeno emitted input or the gun fired. If Xeno exposes a nonfunctional implementation, the script cannot establish that from a successful return alone. If autofire is unavailable, manual firing and ESP can still be used.

If the old interface still appears immediately after this update, load the same URL with `?v=2.1` appended to request a fresh cached response. This camera version can replace its previous controller without a rejoin; rejoin when switching from the legacy silent-aim script.

## Validation

The actual entrypoint passed 30 scenarios in a Lua VM with simulated Roblox services. Coverage includes target eligibility and retention, camera/muzzle obstruction, missing head fallback, input gating, camera replacement, respawn, sliders, panel controls, repeated execution, unloading, error recovery and smoothing parameters at 30/60/144 FPS. Added scenarios cover autofire alignment, rate limits, unavailable/failing input, manual firing, deferred cancellation, reload focus and single-task scheduling, plus ESP lifecycle, filtering and partial-creation cleanup.

These tests check Lua execution and control logic. They do not emulate Roblox's full renderer, actual CFrame interpolation, executor input/permissions or Centaura's live camera scripts. The user reported that v2.0 camera aiming works in-game. The v2.1 autofire and ESP additions have not yet been live-tested in Centaura with Xeno v1.3.65.

To run the simulation with Node.js:

```sh
npm install
npm test
```

Before treating a build as live-tested:

1. Rejoin, run the loader and equip a gun.
2. Hold right-click with a visible enemy inside the radius; verify camera movement and Tracking status.
3. Release right-click, then test blocked enemies and teammates.
4. Enable Autofire and check that click attempts produce gunfire only when aligned; test walls, teammates, manual firing, focus, typing and menus. Confirm it stops on release.
5. Enable Enemy ESP and check enemy outlines/labels, health changes, death, respawn and team changes. Confirm ESP stays independent of aim radius and the camera-assist toggle.
6. Test all sliders. Unload and confirm camera assistance stops and ESP disappears. Rerun and check that only one panel remains.

The earlier silent-aim implementation remains available in Git history.
