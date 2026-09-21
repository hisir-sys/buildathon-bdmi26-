# The Cleaner - bathroom layout V24

## Run

1. Extract this folder.
2. Open `project.godot` in Godot 4.7.2.
3. Press **F5**.

## Controls

- **WASD**: move
- **Mouse**: look around
- **E**: interact with dust, spider webs, furniture, and bathroom fixtures
- **SPACE**: open/close the bathroom door (only while looking at it)
- **Escape**: release or recapture the mouse

The room now has a 10-minute countdown, a ceiling, blinking colored ceiling lights, a 40-column by 20-row wooden tiled floor, a first-person mop handle, six scattered yellow-gold dust piles, four corner spider webs, and the sofa pickup/place task.

The latest floor-plan pass also adds:

- A mop station and rug on the back wall
- A sofa placement zone and cabinet on the right side
- A TV centered on the front wall
- A broken-floor area on the front-left
- A closed bathroom built inside the back-right corner of the main room
- A commode, basin, and dirty mirror that takes 8 seconds to clean
- A compact score/task HUD with sound and pause controls
- A hanging red-bulb lamp, refrigerator, and rewire panel
- A visible falling-water leak and puddle at the bathroom pipe that stop once it's reconnected
- Interactions for cleaning the refrigerator, opening the pipeline puzzle, and rewiring the panel
- The bathroom mirror remains in place after cleaning; only its dirt disappears
- The bathroom stays inside the original room footprint; it does not expand the main room
- The bathroom is compacted with a bathtub, improved toilet, and dirty mirror
- The bathroom uses its own tile surface without overlapping the main-room floor tiles
- Spider webs are currently removed from the playable room and task board; they can be reintroduced later
- A wall-mounted storage rack on the bathroom's left wall, moved away from the basin, with its open shelf side facing the bathtub
- A bathroom door sized up from the previous pass and shifted further left along the front wall (away from the commode/tub corner), resting slightly ajar; SPACE swings it fully open/closed while E still wipes the dust off it (6 seconds), counted toward WASHROOM (now 0/3)
- The only pipeline in the game is now the bathroom one, mounted on its right wall near the bathtub - the old main-room pipe and the broken-mirror "window" beside it have been removed, and the PIPELINE line is gone from the task board (its progress is tracked under WASHROOM instead)
- The pipeline puzzle now does a live connectivity check: as you rotate segments, any unbroken run of pipe from the inlet lights up cyan in real time and goes dark again the instant a rotation breaks it - it solves the moment the lit run reaches the outlet, not by matching one fixed layout. On solve it shows "FLOW RESTORED — WATER RUNNING" for a beat before the panel closes
- Fixed the floor-tile seam for real: the previous fix only checked each plank's center point against the bathroom boundary, but a plank is nearly as deep as its own grid step, so a plank could still visually overlap into the bathroom by up to half a tile even with its center outside the line. The check now compares each plank's full edge-to-edge extent, so nothing overlaps

These props are generated from code at runtime, so the ZIP stays self-contained and does not need downloaded textures or 3D assets.

Dust and web tasks take 10 seconds each. Look at a task and press **E** once to start cleaning; the interaction prompt shows live progress until it disappears.