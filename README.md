# Infinite Racer

An endless, procedurally generated 3D racing game built with **Godot 4.3+**.
Every level has a different track, a different theme and different opponents, and
there is **no last level** — the game keeps generating new circuits forever.

100 cars · unlimited tracks · unlimited levels · AI opponents · full progression.

---

## Quick start

1. Install **Godot 4.3** or newer (the standard, non-.NET build).
2. Open Godot, click **Import**, and select the `project.godot` file in this folder.
3. Press **F5** to play.

No external downloads or assets are required — everything is generated in code.

### Controls

| Action | Keys |
|---|---|
| Accelerate | Up / W |
| Brake / Reverse | Down / S |
| Steer | Left, Right / A, D |
| Handbrake (drift) | Space |
| Reset car to last checkpoint | R |
| Change camera | C |
| Pause | Esc |

Gamepads are mapped too (right/left triggers to accelerate/brake, left stick to
steer, A/Y/B/Start).

---

## What is in the game

- **100 distinct cars**, each built from primitive meshes with its own shape,
  colour, spoiler, wheel size and performance stats (top speed, power, grip,
  handling, mass). Car 0 is a steady all-rounder; higher indexes lean towards
  supercars.
- **Unlimited tracks.** Each level derives a seed from its number, so Level 1,
  Level 2, … Level 10,000 each get a unique closed circuit with its own theme
  (Coast, Desert, Night, Snow, Jungle, Volcano, Canyon, Meadow).
- **Unlimited levels.** There is no cap. Difficulty scales with level number:
  the road narrows, laps increase and the number and speed of opponents grows.
- **AI opponents** that follow the racing line, slow for corners and hold
  individual lane offsets.
- **Full race loop**: start gantry, ordered checkpoints, lap counting, live
  position, minimap, timer, speedometer, results panel with a star rating.
- **Progression that persists**: unlocked levels, best times, stars and your
  selected car are saved to `user://infinite_racer_save.json`.
- **Menus**: Continue, Level Select (grows as you unlock), Car Select (all 100),
  and an in-race pause menu.

---

## Project layout

```
project.godot            Project config (autoloads GameState, sets main scene)
icon.svg                 App icon
scenes/
  Main.tscn              The only scene; boots Main.gd
scripts/
  Main.gd                Screen switcher (menu <-> race)
  GameState.gd           Autoload: input map, progress, save/load
  Menu.gd                Main menu, level select, car select
  RaceManager.gd         Builds a race, checkpoints, laps, camera, results
  TrackGenerator.gd      Procedural track + scenery + colliders
  CarFactory.gd          Builds 100 cars + stats
  CarController.gd       Player vehicle (VehicleBody3D)
  AIDriver.gd            Opponent cars (kinematic racing line)
  HUD.gd                 HUD, results panel, pause panel
  Minimap.gd             Track + racer dots
```

---

## How it works

**Tracks** (`TrackGenerator.gd`) are built from a seeded `Curve3D`: a closed
loop of jittered control points with Catmull-Rom style handles. A road ribbon,
two guardrail walls, a ground plane, scenery and a start gantry are generated
from that curve. The road and walls get matching `ConcavePolygonShape3D`
colliders, and checkpoints are placed evenly along the curve.

**Cars** (`CarFactory.gd`) are assembled from boxes and cylinders. The player car
uses Godot's built-in `VehicleBody3D` with four `VehicleWheel3D`s (all-wheel
drive, front-wheel steering). Engine force is scaled by mass so acceleration is
consistent across cars.

**Levels** map to a seed in `RaceManager.gd`
(`seed = level * 2654435761 mod 2^31-1`), a theme index and a difficulty value.
Nothing is stored per level, so levels are unlimited.

---

## Extending it

- **Add real 3D models**: replace the body in `CarFactory.build_car()` with a
  loaded `.glb`/`.obj` and keep returning the same `wheels`, `stats` and
  `collision_*` keys.
- **Add track themes**: append to `TrackGenerator.THEMES`.
- **Change difficulty curve**: edit the `difficulty` line in
  `RaceManager._build_world()`.
- **Add modes** (time trial, elimination): drive them from `RaceManager`.

---

## Licensing

The project code is released under the **MIT License** — see `LICENSES.md`.

Important: **no third-party art, models, sounds or fonts are bundled.** All
visuals are generated procedurally at runtime, so there are no asset-licence
obligations to track. If you later add external assets (models, textures,
audio), check each one's licence separately before a commercial release — MIT
code does not imply MIT assets.

---

## Honest notes on scope

- This is a **complete, playable and extensible game foundation**, not a
  finished AAA title. The cars are clean procedural designs, not hand-modelled
  art; tracks are procedurally generated, not hand-authored.
- The code was validated with a headless Godot 4.3 build (script parsing plus a
  live headless race — track generation, driving, checkpoints, laps, results and
  saving all confirmed working). Rendering, lighting and feel could not be
  checked without a display, so expect to fine-tune visuals and handling in the
  editor.
- Opponent cars are kinematic (they follow the racing line and do not collide
  with you) — this keeps racing stable and cheap. Making them physical is a
  straightforward next step.

---

## Hindi (हिंदी)

क्विक स्टार्ट (हिंदी)

1. Godot 4.3 या नया वर्ज़न इंस्टॉल करें।
2. Godot खोलें, Import पर क्लिक करें, और इस फ़ोल्डर में मौजूद project.godot फ़ाइल चुनें।
3. खेलने के लिए F5 दबाएं।

कंट्रोल्स
गाड़ी चलाने के लिए एरो कीज़ या W A S D, हैंडब्रेक के लिए Space, कार को रीसेट करने के लिए R, कैमरा बदलने के लिए C, और पॉज़ करने के लिए Esc दबाएं।

हर लेवल का ट्रैक और विरोधी अलग-अलग हैं। अगला लेवल अनलॉक करने के लिए एक लेवल पूरा करें, और आगे बढ़ते रहें - इसमें कोई आखिरी लेवल नहीं है।
