# Centaura silent aim and ESP

This separate entrypoint adapts the Cold War panel and ESP to Centaura's gun code supplied by the user on 22 October 2026. It does not replace main-xeno.luau or claim to use Cold War's weapon module.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sdharwood/centaura-script/centaura-silent-wallchecks/centaura-silent.luau"))()
```

## Use

1. Rejoin if a legacy gun-hook script was loaded.
2. Run the loader, equip a gun and click **Attach / retry**.
3. Enable **Silent aim**. Fire manually with a visible enemy inside the radius.
4. Enable **Enemy ESP** separately. **ESP nametags** hides/shows the name, distance and health label while retaining outlines.
5. Right Shift hides/shows the panel. Drag the header to move it. Radius and ESP range buttons cycle their values.

Silent aim resets off on each execution. ESP settings persist within the same client. Switching guns requires Attach / retry again. The attached gun is shown in the panel. This script does not move the camera or simulate firing.

## Weapon integration

The supplied gun LocalScript defines getSpread(aimPoint, optionalFlag), which normally returns a spread-adjusted Vector3. SemiFire and the other weapon branches call that function before constructing the shot ray.

The adapter searches the equipped Tool's Gun LocalScript for a function named getSpread whose upvalues contain that exact Tool and a numeric spread value. It searches up to three levels from Shoot, with bounded traversal. It does not rely on a fixed upvalue index or source line. Optional getgc fallback additionally requires the exact Gun script environment.

Required: working hookfunction plus function metadata and upvalue inspection. Discovery uses getsenv, or getgc with getfenv as a fallback. Introspection support is executor-dependent. Unavailable APIs, unknown names, mismatched ownership and ambiguous candidates produce a panel diagnostic instead of installing an arbitrary hook.

The getSpread input is an aim point, **not a muzzle origin**. Target checks derive the actual barrel, head and camera positions afresh on each callback. The adapter redirects the returned aim point, leaving the camera unchanged. Calls with unsupported argument types, disabled/paused state, an unequipped gun or no eligible target use the original function and retain its return values.

## Wall checks

A target point must pass all three raycasts immediately before redirection:

- Current camera to target.
- Local character head to target, covering the supplied gun code's head-origin firing path.
- Equipped gun barrel to target, covering its CornerFire path.

Only the local character and its equipped tool are excluded. Map folders, IgnoreList, vegetation, barriers and terrain are not blanket-excluded. The target's own body is accepted as a ray hit. A visible head/torso/root candidate may be used when another body part is obstructed. If every candidate is obstructed, no redirection occurs. Missing head/barrel also prevents redirection.

These checks apply to script-selected shots. They do not disable the game's existing weapon penetration for manual shots, guarantee server hit resolution, or account for unreplicated geometry or an obstacle moving after the checks. ESP intentionally remains able to display outlines through walls and is independent of shot eligibility.

## Diagnostics and lifecycle

**Callbacks** counts observed calls through the selected hook. **Redirects** counts returned target aim points after the visibility checks. Neither counter proves a server hit.

- No callbacks while firing: the function may not be used, the game may have changed, or the executor hook may not work.
- Cannot identify getSpread: the executor's metadata/upvalue access or current gun source differs from the supplied code.
- Callbacks without redirects: check the silent-aim toggle, focus, typing, menus, target radius, teams, health and all visibility checks.
- Rejoin warning: another legacy hook is present, or a hook API failed to return a callable original.

Unload disables the controller and removes its listeners, UI and ESP. Installed hooks become passthrough bridges and can be reused across reloads. Rejoin for a completely fresh client.

## Validation and limitations

**Not live-tested in Centaura or Real. No undetectability or ban-prevention claim.** The prior Cold War build led to a reported in-game cheating ban; this work does not add detection evasion.

The actual entrypoint passes 31 simulated checks in Fengari, including camera/head/barrel obstructions, newly obstructed targets, target filtering, argument forwarding, independent nametags, lifecycle cleanup, missing APIs and strict function identification. Roblox rendering, live executor semantics and current server weapon handling are not emulated.

```sh
npm install
node tests/run-centaura-silent.cjs
```
