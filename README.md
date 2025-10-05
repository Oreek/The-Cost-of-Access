# PRISMIUM_OS: The Cost of Access (LÖVE2D)

A terminal-style text-adventure game where commands get progressively destroyed (sacrificed). made for DayDream Delhi btw.

The lore of the game says that:
"You are a new employee in the PRISMIUM CORPS company and today is your first day on their system. the thing is - the past owner of the system forgot to remove his failed project which is an AI - ENTITY-67. it had way too many emotions so it got locked up but wasn't completely disposed of. now you're handling the consequences where you either sacrifice your job to save the AI or sacrifice the AI to get a promotiiion in your company. " 

## How to run locally (Windows)

Prereq: Install [LÖVE 11.x](https://love2d.org)

Clone the Repository: 
```git clone https://github.com/Oreek/The-Cost-of-Access.git```

- Option A: Drag the `The-Cost-of-Access` folder onto `love.exe`.
- Option B: Run from terminal:

```pwsh
# Replace the path to love.exe if installed elsewhere
& "C:\\Program Files\\LOVE\\love.exe" "d:\\user\\path\\to\\game_folder"
```

## Controls

- Type commands; press Enter to submit
- Up/Down: command history
- Esc: quit

## Commands

- ls — list files (if sacrificed, you must remember names)
- cat <file> — show file contents
  - If sacrificed, you only see previews in `ls`
- rename <old> <new> — rename files (used to unlock/bypass)
- rm <file> — delete files
- help — list available commands
- exit — quit
- profile set name=UNKNOWN — identity sacrifice step
- Endings: `purge entity67`, `release entity67`, `merge entity67`

## Progression summary

1. Level 1: Rename `report1.txt.locked` -> `report1.txt`, read it, then `rm system_tutorial.txt`.
2. Level 2: Read both `corrupt_fragment1.log` and `corrupt_fragment2.log`, then sacrifice `ls` or `cat` via `rm command:<name>`.
  - If you sacrificed `ls`, you cannot list files anymore. Continue by typing known actions directly (e.g., `rename firewall.cfg firewall.old`).
  - If you sacrificed `cat`, you can still list filenames to discover targets.
3. Level 3: `rename firewall.cfg firewall.old` to disable firewall, then sacrifice `rename` or `rm`.
4. Level 4: `profile set name=UNKNOWN`.
5. Final: Execute one of: `purge entity67`, `release entity67`, or `merge entity67`.

## Save data

Progress is saved in LÖVE's save directory as `save.lua`. Delete it to restart fresh.

## Notes

- Minimal synthesized audio is included (hum + key clicks); volume is low by design.
- sfx is coded in `audio.lua`
- Background music is provided by `Muhammad Adi`

