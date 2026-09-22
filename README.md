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
- Get the **fridge** back where it belongs and plugged in
- Clear the **piled-up furniture**
- **Dust** the room and clear the spider webs
- Scrub the **washroom** clean

Along the way, decide: **take the diamond, or leave it.**

## Controls

| Input | Action |
|---|---|
| **WASD** | Move |
| **Mouse** | Look around |
| **E** | Interact with dust, spider webs, furniture, wiring, pipes, fridge, and bathroom fixtures |
| **Space** | Open/close the bathroom door (only while looking at it) |
| **Escape** | Release or recapture the mouse cursor |

## Endings

How the night ends depends on two things: **how much of the house got fixed**, and **whether the diamond was taken**.

- **Full Pay** — the house is in order, and the diamond stayed put.
- **Docked Pay** — some tasks were left unfinished.
- **No Pay** — most of the house is still a mess when the owner walks in.
- **Caught Red-Handed** — the diamond went missing, and it gets noticed.

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

