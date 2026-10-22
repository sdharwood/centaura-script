# Centaura camera aim assist

The `main-xeno.luau` entrypoint now contains camera aim assist (v2.0). It smoothly turns the camera toward a visible enemy while right-click is held and a gun with a `Barrel` part is equipped. The radius is centered on the camera crosshair.

This version uses Roblox camera, input, GUI and raycast APIs. It does not require `getsenv`, `getgc`, `getconnections`, `hookfunction`, upvalue access, the Drawing API or a remote UI library. Optional `getgenv` is used only to retain the controller between executions; `shared` is the fallback.

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
| Targeting radius | Set the acquisition radius, 40–650 pixels |
| Aim strength | Set camera response, 3–30 per second; higher turns faster |
| Right Shift | Hide or show the panel |
| Header | Drag the panel |
| Unload assist | Remove the UI, render binding and event listeners |

Team and wall checks are always enabled. Visibility is checked from both the camera and gun barrel. Dead and forcefield-protected characters are excluded. A valid target is retained while held, then released when it becomes ineligible. Head targeting falls back to the root part when needed.

Assistance pauses while typing, using the panel, opening Roblox's menu, losing window focus or using a scriptable camera. It also waits through death, respawn, unequipping and camera replacement. Running this version again cleans up the previous camera controller and preserves its settings.

## Status and troubleshooting

The status card is below **Team + wall checks**.

- **Ready**: a gun is equipped; hold right-click.
- **Tracking: …**: the camera update callback found a target and wrote a camera rotation.
- **No visible target**: no eligible enemy passed the radius and both visibility checks.
- **Equip a gun**: the equipped tool has no direct `Barrel` BasePart.
- **Input paused / Camera paused / Waiting for spawn**: assistance is intentionally suspended.
- **Needs attention**: read the detail and the `[Centaura]` warning in F9. Toggle Camera assist off and on to retry after resolving the cause.

The camera-update counter measures executed camera writes, not successful hits. Weapon spread, recoil and server hit validation still affect shots. Another game camera script may overwrite the result. Camera assistance visibly moves your aim; it is not silent aim.

If the old interface still appears immediately after this update, rejoin and load the same URL with `?v=2` appended to request a fresh cached response.

## Validation

The actual entrypoint passed 18 scenarios in a Lua VM with simulated Roblox services. Coverage includes target eligibility and retention, camera/muzzle obstruction, missing head fallback, input gating, camera replacement, respawn, sliders, panel controls, repeated execution, unloading, error recovery and smoothing parameters at 30/60/144 FPS.

These tests check Lua execution and control logic. They do not emulate Roblox's full renderer, actual CFrame interpolation, executor permissions or Centaura's live camera scripts. Live validation in Centaura with Xeno v1.3.65 has not been performed.

To run the simulation with Node.js:

```sh
npm install
npm test
```

Before treating a build as live-tested:

1. Rejoin, run the loader and equip a gun.
2. Hold right-click with a visible enemy inside the radius; verify camera movement and Tracking status.
3. Release right-click, then test blocked enemies and teammates.
4. Test respawn, window focus, typing, the menu and both sliders.
5. Unload and confirm camera assistance stops. Rerun and check that only one panel remains.

The earlier silent-aim implementation remains available in Git history.
