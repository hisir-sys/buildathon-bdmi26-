# The Mechanic — Project Overview

I am building a game called **The Mechanic** for the Buildathon, using **Godot 4.x** and **GDScript**.

**Premise:** Lucas is told by his owner to clean the house and is given 6 hours — but a message arrives
saying the owner is actually returning in 10 minutes. The player has 10 minutes to fix and clean the
house (electrical wires, a broken pipeline, an unplugged fridge, piled-up furniture, a dusty room, and a
dirty washroom) in any order. Along the way there's an optional moral choice — a chest with an antique
diamond that can be taken or left. The ending changes based on how much got done and whether the diamond
was taken: full pay, docked pay, no pay, or caught red-handed.

## Team & Responsibilities

**I am Member 1 (Soham)** — I'm building the core systems:
- Game manager and 10-minute countdown timer
- Player movement and interaction
- Electrical wire puzzle (timed connection, wrong wire = circuit blast = game over)
- Pipeline drag-and-drop puzzle
- Refrigerator placement + plug-in logic
- Diamond choice logic and the four-branch ending system
- GitHub repo setup and branch management

**Member 2 is working on:**
- Dusting + spider web clearing task (mop mechanic)
- Furniture separation task (drag pieces out of the pile, place correctly)
- Washroom cleaning task (scrubber, mirror wipe, light check)
- On-screen task instructions (bottom-center) and the timer UI

**Member 3 is working on:**
- Gathering and crediting free assets (sprites, sound effects, music)
- Start screen
- End screens (one for each of the four outcomes)
- Playtesting and bug reporting

## Folder Structure

```
res://
  scenes/          one .tscn per task/screen (mirrors scripts/)
  scripts/
    game_manager.gd        (Soham)
    player_controller.gd   (Soham)
    wire_puzzle.gd         (Soham)
    pipe_puzzle.gd         (Soham)
    fridge_task.gd         (Soham)
    diamond_choice.gd      (Soham)
    ending_manager.gd      (Soham)
    dusting_task.gd        (Member 2)
    furniture_task.gd      (Member 2)
    washroom_task.gd       (Member 2)
  ui/
    instruction_label.gd   (Member 2)
    timer_display.gd       (Member 2)
    start_screen.gd         (Member 3)
    ending_screen.gd         (Member 3)
  assets/
    sprites/
    audio/
    fonts/
  README.md
```

## Sync Rules
- Each person works in their own branch (`feature/<name>-<task>`), never directly on `main`
- `git pull origin main` before starting any new work session
- Commit small, commit often — no single end-of-week dump (penalized under event rules)
- Merge into `main` only once a task is tested and working
- Since each task lives in its own file, conflicts should be rare — if two people need to edit the
  same file, talk first before pushing
