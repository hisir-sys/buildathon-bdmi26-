# The Cleaner - bathroom layout V22

## Run

1. Extract this folder.
2. Open `project.godot` in Godot 4.7.2.
3. Press **F5**.

## Controls

- **WASD**: move
- **Mouse**: look around
- **E**: interact with dust, spider webs, furniture, and bathroom fixtures
- **Escape**: release or recapture the mouse

The room now has a 10-minute countdown, a ceiling, blinking colored ceiling lights, a 40-column by 20-row wooden tiled floor, a first-person mop handle, six scattered yellow-gold dust piles, four corner spider webs, and the sofa pickup/place task.

The latest floor-plan pass also adds:

- A mop station, rug, and broken mirror on the back wall
- A sofa placement zone and cabinet on the right side
- A TV centered on the front wall
- A broken-floor area on the front-left
- A closed bathroom built inside the back-right corner of the main room
- A commode, basin, and dirty mirror that takes 8 seconds to clean
- A compact score/task HUD with sound and pause controls
- A hanging red-bulb lamp, refrigerator, wall pipeline, and rewire panel
- A pipeline repair minigame with a 4x3 rotating pipe grid, inlet/outlet flow, and cyan completion glow
- A visible falling-water leak and puddle that stop when the pipeline is connected
- Interactions for cleaning the refrigerator, opening the pipeline puzzle, and rewiring the panel
- The bathroom mirror remains in place after cleaning; only its dirt disappears
- The bathroom stays inside the original room footprint; it does not expand the main room
- The bathroom is compacted with a bathtub, improved toilet, and dirty mirror
- The bathroom uses its own tile surface without overlapping the main-room floor tiles
- Spider webs are currently removed from the playable room and task board; they can be reintroduced later
- A wall-mounted storage rack on the bathroom's left wall, moved away from the basin, with its open shelf side facing the bathtub
- A small ajar bathroom door in the doorway opening, with a dusty layer that takes 6 seconds to wipe clean (its own interaction, counted toward the WASHROOM task alongside the mirror, now shown as 0/2)

These props are generated from code at runtime, so the ZIP stays self-contained and does not need downloaded textures or 3D assets.

Dust and web tasks take 10 seconds each. Look at a task and press **E** once to start cleaning; the interaction prompt shows live progress until it disappears.