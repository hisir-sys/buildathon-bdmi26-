# The Cleaner

A first-person, timed cleaning-and-repair game built in **Godot 4.7.2** with **GDScript**, made for a Buildathon.

## Story

Lucas works for a wealthy homeowner who leaves him a simple job: clean and fix up the house, no rush — he's got 6 hours. Lucas gets to work.

Then a message comes in. The owner isn't gone for 6 hours after all — she's on her way back **right now**, and will be home in **10 minutes**.

Lucas has 10 minutes to get as much done as he can before the front door opens.

Along the way, Lucas finds a locked chest holding an **antique diamond**. Nobody's watching. Nobody would know.

What Lucas does next — and how much of the house actually got fixed — decides how the night ends.

## Objective

You have **10 minutes**. Fix and clean whatever you can, in any order you like:

- Reconnect the **electrical wiring** — pick the right wire before the circuit blows
- Repair the **broken pipeline** — drag the segments back into place
- Carry the **fridge** to its pink spot on the left wall, then flip the wall switch to power it on
- Clear the **piled-up furniture** (sofa, table, chairs and the cabinet) onto their pink spots
- **Dust** the room and clear the spider webs
- Scrub the **washroom** clean

Along the way, decide: **take the diamond, or leave it.**

A desk with a locked chest sits in the back-left corner, hidden behind the cabinet. Move the cabinet, search the apartment for the key while cleaning, and unlock the chest. The game freezes and you choose: **STEAL THE DIAMOND** or **LEAVE THE DIAMOND**.

## Controls

| Input | Action |
|---|---|
| **WASD** | Move |
| **Mouse** | Look around |
| **E** | Interact with dust, spider webs, furniture, wiring, pipes, fridge, and bathroom fixtures |
| **Space** | Open/close the bathroom door (only while looking at it) |
| **Escape** | Release or recapture the mouse cursor |

## Flow

`start_menu` (THE FINAL CONTRACT: Start / Load / Quit) -> `cutscene_intro` -> `main_room` -> `ending_screen`.

## Endings

The game ends when the **timer runs out** or **every task is finished**, and the ending depends on whether the diamond was taken:

| | Diamond left | Diamond taken |
|---|---|---|
| **Timer ran out** | Ending 1: Total Failure | Ending 2: The Greed Trap |
| **All tasks done** | Ending 3: Mission Accomplished | Ending 4: The Shadow Victory |

## Running the Game

1. Extract/clone this folder.
2. Open `project.godot` in **Godot 4.7.2**.
3. Press **F5** to run.

## Project Structure

```
res://
├── scenes/          # .tscn files, one folder per major scene/task
├── scripts/         # .gd files, mirrors scenes/
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
├── ui/               # menus, HUD, prompts, pause screen
└── README.md
```

