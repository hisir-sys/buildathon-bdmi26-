# THE CLEANER

## Full Human Narration of the Story

### Opening Narration

> "Tonight's job looks simple."
>
> "A private room. A short cleaning shift. A few things to repair, a few things to clean, and enough time to finish before the owner returns."
>
> "But this is not just a cleaning job."
>
> "You're here because something inside this room matters."
>
> "There are files and assets that cannot be left behind."
>
> "Your cover is the uniform. Your tools are the excuse."
>
> "Clean the room. Search carefully. Take only what you need."
>
> "And whatever happens..."
>
> "Do not get caught."

### During the Mission

> "Keep moving."
>
> "Every unfinished task increases the chance that someone notices."
>
> "Use the right equipment for the right job."
>
> "The electrical kit is for electrical work."
>
> "The mop is for ordinary cleaning."
>
> "The bathroom scrubber is for bathroom surfaces."
>
> "The room has to look clean when you're finished."
>
> "But remember why you're really here."
>
> "The assets are the real objective."

### Ending 1 — Mission Failed

> "The operation has failed."
>
> "You did not complete the cleaning task, and you did not recover any of the assets you were sent to collect."
>
> "The room is still unfinished."
>
> "The opportunity is gone."
>
> "You failed both parts of the mission."
>
> "The operation is over."

### Ending 2 — Cleaner Success, Spy Mission Failed

> "The room is clean."
>
> "Every assigned cleaning task has been completed."
>
> "To anyone watching, you did exactly what you were supposed to do."
>
> "But that was only the cover."
>
> "You failed to recover the assets and files you came here for."
>
> "The cleaning job was a success."
>
> "The real mission was not."

### Ending 3 — Mission Accomplished

> "Everything is in place."
>
> "The room is clean."
>
> "Every assigned task is complete."
>
> "The required assets have been recovered."
>
> "No one caught you."
>
> "The cover held."
>
> "The evidence is secured, the room looks untouched, and the operation is complete."
>
> "You came in as a cleaner."
>
> "You leave as an operative."
>
> "Mission accomplished."

---

# Complete Game Flowchart

```text
                    +------------------+
                    |    START MENU    |
                    +--------+---------+
                             |
                           START
                             |
                             v
                 +-----------------------+
                 |   NIGHT SHIFT BEGINS  |
                 |   Timer starts        |
                 +-----------+-----------+
                             |
                             v
                 +-----------------------+
                 |    EXPLORE ROOM       |
                 |  Find tasks & assets  |
                 +-----------+-----------+
                             |
              +--------------+--------------+
              |              |              |
              v              v              v
        +-----------+  +-----------+  +-----------+
        |  NORMAL   |  |ELECTRICAL |  | BATHROOM  |
        | CLEANING  |  |   TASKS   |  |   TASKS   |
        |   MOP     |  |ELECTRICAL |  | SCRUBBER  |
        |           |  |    KIT    |  |           |
        +-----+-----+  +-----+-----+  +-----+-----+
              |              |              |
              +--------------+--------------+
                             |
                             v
                  +----------------------+
                  |   COLLECT ASSETS     |
                  |   / REQUIRED ITEMS   |
                  +----------+-----------+
                             |
                             v
                  +----------------------+
                  |   AVOID DETECTION    |
                  |   Keep suspicion low |
                  +----------+-----------+
                             |
                             v
                  +----------------------+
                  |   COMPLETE SHIFT     |
                  +----------+-----------+
                             |
                             v
                  +----------------------+
                  |   CHECK RESULTS      |
                  +----------+-----------+
                             |
          +------------------+------------------+
          |                  |                  |
          v                  v                  v
   Tasks incomplete    Tasks complete     Tasks complete
   + no assets         + no assets        + all assets
          |                  |                  |
          v                  v                  v
   +--------------+   +--------------+   +----------------+
   | MISSION      |   | CLEANER      |   | MISSION        |
   | FAILED       |   | SUCCESS /    |   | ACCOMPLISHED   |
   |              |   | SPY FAILED   |   |                |
   +--------------+   +--------------+   +----------------+
```

---

# Tasks

The mission contains **9 fixed tasks**:

1. **Dusting** — clean the required dusty areas.
2. **Rewire Panel** — complete the electrical repair using the electrical equipment.
3. **Fridge** — complete the fridge-related cleaning/interaction.
4. **Furniture** — clean/arrange the required furniture.
5. **Washroom** — clean the bathroom using the bathroom scrubber.
6. **Lock-Pick Drawer** — access the required drawer and recover its contents.
7. **Straighten Picture** — return the picture to the correct position.
8. **Scrub Spill** — clean the spill using the normal cleaning equipment.
9. **Old Stain** — remove the old stain using the appropriate cleaning equipment.

---

# Equipment

There are **3 useful equipment types**:

### 1. Electrical Kit
Used only for electrical and wiring-related interactions.

### 2. Mop / Normal Cleaning Tool
Used for normal cleaning such as dust, spills, stains, floors, and general cleaning areas.

### 3. Bathroom Scrubber
Used specifically for bathroom and washroom cleaning interactions.

```text
ELECTRICAL TASK  ->  ELECTRICAL KIT
NORMAL CLEANING  ->  MOP
BATHROOM TASK    ->  BATHROOM SCRUBBER
```

The wrong equipment cannot complete an interaction.

---

# Suspicion System

Suspicion represents how much attention the player is attracting during the mission.

The player must keep suspicion under control while:

- Cleaning the room
- Exploring
- Searching for assets
- Completing the mission

The successful stealth condition is:

```text
LOW / NO DETECTION
        +
ALL TASKS COMPLETE
        +
ALL REQUIRED ASSETS COLLECTED
        =
MISSION ACCOMPLISHED
```

Getting through the mission without being caught is an important part of the final success condition.

---

# Complete Mission Summary

```text
ENTER AS A CLEANER
        |
        v
CLEAN THE ROOM
        |
        v
USE THE CORRECT EQUIPMENT
        |
        v
COMPLETE ALL 9 TASKS
        |
        v
SEARCH FOR THE HIDDEN ASSETS
        |
        v
COLLECT THE REQUIRED ITEMS
        |
        v
KEEP SUSPICION LOW
        |
        v
FINISH THE SHIFT
        |
        v
       END
```

There are exactly **three endings**:

```text
ENDING 1
Mission Failed
= Tasks not completed + assets not collected

ENDING 2
Cleaner Success / Spy Mission Failed
= Tasks completed + assets not collected

ENDING 3
Mission Accomplished
= Tasks completed + all assets collected + not caught
```

---

# Final Mission Brief

> **Your cover is simple.**
>
> **Your real objective is not.**
>
> Enter quietly.
>
> Clean everything that needs cleaning.
>
> Use the right tool for every job.
>
> Find what you came for.
>
> Recover the required assets.
>
> Keep suspicion low.
>
> Leave the room looking clean.
>
> And make sure the owner never realizes what really happened here.
>
> **You are the Cleaner.**
>
> **Complete the job. Recover the assets. Do not get caught.**
