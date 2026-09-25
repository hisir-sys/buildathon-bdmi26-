# Spy-as-Cleaner Update — Integration Guide

This adds the systems from the architecture spec on top of your existing
project **without rewriting anything that already works**. Everything new
is additive; a few small, targeted edits were made to existing files where
there was no safe way to add the feature otherwise (listed below).

## What's new

```
scripts/autoload/suspicion_manager.gd     - Autoload "SuspicionManager"
scripts/autoload/ending_state_machine.gd  - Autoload "EndingStateMachine"
scripts/autoload/inner_voice_manager.gd   - Autoload "InnerVoiceManager"
scripts/autoload/run_generator.gd         - NOT an autoload, see below
scripts/tasks/lock_pick_drawer.gd         - Task 1 (drawer + launches minigame)
scripts/tasks/lock_pick_minigame.gd       - Task 1 (timing-bar UI)
scripts/tasks/crooked_picture.gd          - Task 2
scripts/tasks/spill_cleaner.gd            - Task 3
scripts/tasks/permanent_stain.gd          - Task 4 (narrative clue)
shaders/spill_stain.gdshader              - shared by Tasks 3 & 4
```

The three autoloads are already registered in `project.godot` under
`[autoload]`, so they work as soon as you open the project — nothing to do
in the editor for those three.

## Small edits made to existing files

- **`project.godot`** — added the `[autoload]` section above, and switched
  `renderer/rendering_method` from `gl_compatibility` to `forward_plus`
  (mobile export still falls back to `gl_compatibility`). **This is a real
  trade-off, not a formality** — SSAO, SSIL and Volumetric Fog from the spec
  do not exist in Compatibility mode at all; Forward+ is required to render
  them. Forward+ needs a desktop-class GPU with Vulkan/D3D12/Metal support.
  If you need the game to run on low-end or integrated GPUs, revert this one
  line to `gl_compatibility` — the rest of this update works fine either
  way, you'll just lose the three environment effects.
- **`scenes/main_room.tscn`** — added `tonemap_mode/exposure/white`,
  `ssao_*`, `ssil_*`, and `volumetric_fog_*` properties to the existing
  `Environment_room` resource, using exactly the values from the spec.
  Everything else in the scene is untouched.
- **`scripts/ending_screen.gd`** — added one `5:` branch to the
  `_ending_data()` match statement (CAUGHT_RED_HANDED). The other four
  branches are byte-for-byte unchanged.
- **`scripts/hud.gd`** — added a suspicion meter (top-right glass panel) and
  a `set_suspicion(value, max)` method, auto-wired to `SuspicionManager` in
  `_ready()`. All existing HUD methods/layout are unchanged.

Nothing else was touched beyond what's described below — `main_room.gd`'s
task-completion logic and ending-trigger flow were extended (not replaced)
to account for the 4 new tasks; see "Winning now covers all 9 tasks" below.

## What's now placed in the scene (done for you)

All 4 new tasks, the 3 key-spawn points, and `RunGenerator` are now built by
`main_room.gd` itself — `_build_spy_mechanics_update()`, called at the end
of the existing `_build_floor_plan_props()`, right after everything else
(including the key) already exists. This matches how every other prop in
this project is placed (procedurally, in code) rather than hand-edited into
the `.tscn` file.

| Object | World position | Notes |
|---|---|---|
| `LockPickDrawer` | `(-9.85, 0.9, 4.0)`, facing into the room | Built into the left-wall paneling, between the fridge switch and the TV corner — an open stretch of wall. Reads as a hidden compartment, which fits the spy framing. |
| `CrookedPicture` | `(-3.0, 1.8, -9.8)` | Main back wall, between the mop station and the desk/chest. |
| `SpillCleaner` | `(-3.5, 0, -2.0)` | Open floor, clear of the rug, dust spots, and the rewire panel/fridge wall furniture. |
| `PermanentStain` | `(6.4, 0, -3.0)` | Just outside the bathroom doorway. |
| `KeySpawn_A/B/C` | bathroom shelf (original spot) / rack's top shelf / mop station shelf | `RunGenerator` picks one per run; the key (`ChestKey`) is now in the `chest_key` group so it finds it automatically. |
| `RunGenerator` | plain child node, no transform | Runs its randomization once in `_ready()`. |

**Important honesty check:** I placed these by reading the coordinates of
every existing wall, room, and prop in `main_room.gd`/`main_room.tscn` and
picking clear, non-overlapping spots — but I cannot render the scene, so
I've verified the *math* (no overlapping bounding boxes) and the *logic*
(interaction, collision, groups all wire up correctly), not the *look*
(does the picture frame's front face the room, is the wall-drawer's height
comfortable to reach). Open it in the editor and if anything is facing the
wrong way or floating oddly, it's a single position/rotation field to
nudge — the mechanics underneath don't depend on getting that pixel-perfect.

All 9 tasks — your original `dust`, `panel_repair`, `fridge`, `furniture`,
`washroom`, plus the 4 new `lockpick`, `picture`, `spill`, `stain` — are now
in `RunGenerator`'s pool. Each run it randomly deactivates 4 of the 9,
leaving exactly 5 active, and **all 9 now count toward winning** when
they're the active ones for that run — see the next section for exactly how.

For the 4 new (single-node) tasks, deactivation is physical: the node is
hidden and its collision/processing disabled via
`RunGenerator.apply_node_active()`. For your 5 pre-existing tasks,
deactivation is *not* physical — those are multi-node/aggregate systems (6
dust spots, 3 washroom sub-items, etc.) that were never built to be toggled
as a unit, and blind-hiding them without a running engine to test against
risked breaking something that already works. So if e.g. "dust" is
deactivated for a run, dusting still physically works if the player does it
anyway — it's just not *required*, and it drops off the HUD checklist for
that run. Want those 5 properly hidden too once you can test in-editor?
Say the word.

## Winning now covers all 9 tasks

`main_room.gd`'s `_tasks_done_count()` / `_all_tasks_done()` were rewritten
around the `task_active` dictionary populated by `RunGenerator`: winning
means completing whichever 5 of the 9 tasks are active this run, no more,
no less. Completion is tracked per task via `_task_complete(id)`:

| id | "complete" means |
|---|---|
| `dust` | `dust_cleaned >= 6` |
| `panel_repair` | `panel_repaired >= 1` |
| `fridge` | `fridge_done >= 1` |
| `furniture` | `furniture_placed >= FURNITURE_TOTAL` |
| `washroom` | `_washroom_total() >= 3` |
| `lockpick` | `LockPickDrawer.unlocked` has fired |
| `picture` | `CrookedPicture.straightened` has fired |
| `spill` | `SpillCleaner.cleaned` has fired |
| `stain` | `PermanentStain.capped` has fired (see below) |

The HUD checklist (`hud.set_task_counts()`) now takes a dynamic list of
rows instead of a hardcoded 5-argument signature, and only lists whichever
tasks are active — so the `X/5` fraction and the checklist itself always
match the current run, whether 5 tasks are active (the normal case) or all
9 are (if `RunGenerator` hasn't run yet, e.g. it was removed from the
scene — `task_active` defaults every entry to `true`).

**The permanent stain is a special case.** It's designed to never fully
fade (`scrub_progress` caps at 99%, per the spec) — but that shouldn't mean
a run is unwinnable if `stain` happens to be picked as one of the 5 active
tasks. So `permanent_stain.gd` now fires a `capped` signal once
`scrub_progress` hits its ceiling, which is what `_task_complete("stain")`
checks for. The clue text still fires at the usual 3-second mark; the stain
itself stays on the floor forever exactly as before — it's just no longer a
dead end for winning.

## Suspicion — now wired into existing gameplay too

- `player_controller.gd`'s `_select_tool()` now calls
  `SuspicionManager.set_cover_state(index == 0)` every time the tool
  changes, so cover state tracks the mop being equipped/put away globally —
  not just during the new spill tasks (which no longer set cover state
  themselves, to avoid the two writers fighting each other).
- `treasure_chest.gd`'s `_run_sequence()` now calls
  `SuspicionManager.add_suspicion(15.0)` the moment the player opens the
  chest — a real snooping action, priced accordingly.

Your other existing snooping-adjacent actions (moving the cabinet, opening
drawers on it) don't currently add suspicion — I left those alone rather
than guessing at numbers for interactions I didn't write. The pattern to
add more is the same two lines used above:

```gdscript
var suspicion_manager := get_node_or_null("/root/SuspicionManager")
if suspicion_manager != null:
    suspicion_manager.call("add_suspicion", 10.0) # pick a number
```

## Wiring the caught ending (suspicion = 100)

Already automatic: `EndingStateMachine` connects to
`SuspicionManager.caught_ending_triggered` in its own `_ready()` and drives
the existing fade → `ending_screen.tscn` transition by itself. You don't
need to call anything for this to work — just make sure
`main_room.gd`'s own `_finish_game()` sets `game_over = true` (or similar)
early enough that it doesn't also try to run its own ending transition in
the same frame. A one-line guard is enough:

```gdscript
func _finish_game(tasks_finished: bool) -> void:
    if game_over:
        return
    game_over = true
```

(this line already exists in your `_finish_game()`, so no change needed —
just confirm nothing else can call it after suspicion caps.)

## Adding further tasks later

The 4 new tasks build their own visuals in code (matching how
`dust_spot.gd` / `treasure_chest.gd` already work), so placing another
instance anywhere else in the room, or in a future room, is just:

1. Add a node of the matching base type as a child in `main_room.gd` (or
   the `.tscn`, either works) — e.g. another `StaticBody3D`.
2. `set_script()` (or attach) the matching task script.
3. Nothing else required — `_ready()` builds the meshes/collision itself.

## RunGenerator — why it's not an autoload, and how it's already wired

The spec lists it alongside the other three managers, but by design it
needs a direct reference to *this specific scene's* `Marker3D` key-spawn
points — the same reason `game_manager.gd` in your project is a plain child
node (`$GameManager`), not a singleton. It's added the same way, by
`_build_run_generator()` in `main_room.gd` (see the table above for what it
built).

Task selection itself is ID-based, not group-based: `RunGenerator` knows
the 9 fixed task IDs (`TASK_IDS` constant) and just picks which 4 to
deactivate, emitting them on `run_generated`. It never touches scene nodes
directly for that — `main_room.gd`'s `_on_run_generated()` is the only place
that maps an ID to an actual system, since it's the only place with
references to all 9. This is why `_build_run_generator()` connects to
`run_generated` **before** `add_child()`: adding a node whose parent is
already in the tree runs its `_ready()` immediately, and that's where
`run_generated` fires — connecting after `add_child()` would miss it.

Adding a 10th task later means: pick a new ID, add it to `RunGenerator`'s
`TASK_IDS` array, and add a `"my_new_id":` case to both `_task_complete()`
and `_on_run_generated()`'s `match` in `main_room.gd`. Also bump
`ACTIVE_TASK_COUNT` in `run_generator.gd` if you want more than 5 active at
once.

## Adapted-from-spec design calls (and why)

- **Task 3 ("hold Left Click")** → adapted to your project's existing
  E-to-start / auto-progress convention (same as `dust_spot.gd`), rather
  than adding a new "held mouse button" input path that nothing else in the
  project uses. Functionally equivalent from the player's side.
- **Task 1 drawer animation** → uses an `AnimationPlayer` if you add a
  child named `AnimationPlayer` with an `open` animation; otherwise falls
  back to a `Tween`, matching how `treasure_chest.gd` already animates its
  lid without any imported animation assets.
- **Task 2 "Area3D mouse/raycast interaction"** → uses the project's
  existing crosshair-raycast + E-key interaction (`interaction_raycast.gd`)
  instead of a separate `Area3D` mouse-picking Area3D, for consistency with
  every other interactable object in the scene.
