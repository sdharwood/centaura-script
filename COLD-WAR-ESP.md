# Cold War ESP only

Standalone local visual overlay. The dynamic crosshair remains a separate task pending the Cold War ballistics export.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/sdharwood/centaura-script/cold-war-esp-only/cold-war-esp.luau"))()
```

Rejoin first to clear any older silent-aim hooks. Run the loader and enable **Player ESP**. Outlines start enabled; nametags start hidden. The master ESP switch starts off on every execution.

## Controls

- **Outlines:** enemy silhouettes visible through walls. **Soft silhouette fill** adds a faint fill.
- **Nametags:** separate from outlines. Optional health and distance details have their own toggles.
- **Show teammates:** off initially. Teammates appear blue when enabled.
- **Range:** cycles through 250, 500, 1000, 1500, 2500 and 5000 studs.
- **Enemy colour:** coral, mint, blue or gold.
- Drag the header. Right Shift or the minus button collapses the panel; the CW / ESP button reopens it.
- **Unload ESP:** disconnects listeners and destroys the overlay's UI and visual objects.

The panel scrolls on short viewports. The overlay updates five times per second. Dead players, forcefield-protected players, out-of-range players and departed players are excluded. Respawns and team changes are refreshed automatically. Losing window focus clears visuals immediately; menus and missing cameras pause them at the next update. Repeated execution replaces the prior controller and preserves appearance settings.

This code creates its own Highlight and BillboardGui instances. It does not modify Cold War's MarkersGui or Teammate billboards.

## Detection and scope

No undetectability or ban-prevention claim. Ordinary Roblox rendering APIs do not make an executor or its overlay invisible to the game's checks. Cold War/Real live rendering and detection have not been verified.

The entrypoint does not install weapon hooks, inspect/decompile scripts, scan garbage-collected functions, execute remote UI libraries, invoke game remotes, simulate clicks, change aim or alter shots. It uses optional getgenv only to retain its controller and falls back to shared. Unloading the earlier controller cannot undo already-installed executor hooks; rejoin first for a fresh client.

This is solely the ESP portion. The dynamic crosshair will need actual weapon/projectile data to model drop and range accurately.

## Validation

The actual entrypoint passes 36 simulated execution checks in Fengari: default state, independent names/outlines, health/distance details, colours/fill, teammates, death/protection/range filters, respawn, focus/menu/camera pauses, panel controls, departure, repeated execution, external GUI destruction, partial-creation failure cleanup and recovery. Deliberately failing executor hook/introspection functions remain unused during these checks.

```sh
npm install
node tests/run-cold-war-esp.cjs
```

The simulation does not verify Roblox's renderer, live executor permissions, game-specific character structures or anti-cheat behavior.
