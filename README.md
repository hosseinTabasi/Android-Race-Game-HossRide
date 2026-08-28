# Hossein Rides

A motorcycle traffic runner set on a Tehran expressway. You ride Hossein's
bike through real Iranian traffic — Prides, Paykans, Samands, 206s, buses —
earning credits by the kilometre and spending them in the garage. Milad Tower
sits on the skyline the whole way. It rains. It gets dark. Sometimes Hossein
lights a cigarette and smokes it while riding.

Built in **Godot 4** (4.3 or newer), targeting Android.

---

## Current state

Everything below is written and wired together. **Nothing has been compiled or
play-tested yet** — this machine has no Godot install, no Android SDK, and only
JDK 8, so the first run is on you. Expect to spend a session fixing small
things; that is normal for a project this size on its first launch.

| System | State |
|---|---|
| Procedural Iranian traffic (13 vehicle types) | built |
| Motorcycle + rider, 5 bikes | built |
| Endless chunked expressway | built |
| Milad Tower, Alborz backdrop, roadside city | built |
| Day/night cycle + rain + wet roads | built |
| Credits by distance, multiplier from near misses | built |
| Garage: buy bikes, paint, 4 upgrade tracks | built |
| Radio system | built — **you supply the music**, see `assets/music/README.md` |
| Sound set (engine, horns, crash, rain, UI, voice) | synthesised, in `assets/sfx/` |
| Android export | configured below, not yet run |

---

## Running it

### 1. Install Godot 4

Download the **standard** build (not .NET) from <https://godotengine.org/download/windows/>.
It's a single `.exe`, about 120 MB, no installer.

### 2. Open the project

Launch Godot → **Import** → select `C:\android_game\hossein_rides\project.godot`
→ **Import & Edit**.

Press **F5** to run on desktop. Steer with the arrow keys, `Down` to brake,
`M` to skip a track, `C` to make Hossein light up.

### 3. Regenerate the sound set (optional)

Already generated. To rebuild or tweak:

```bash
python tools/generate_audio.py
```

Requires `numpy`. `--only voice` regenerates just the voice bank.

---

## Building the APK

### Prerequisites

1. **JDK 17** — the Android build needs it; the JDK 8 on this machine will not
   work. Get Temurin 17 from <https://adoptium.net/>.
2. **Android SDK.** Easiest path is Android Studio
   (<https://developer.android.com/studio>), which installs the SDK,
   build-tools and platform-tools together.
3. **Godot Android export templates** — in Godot:
   *Editor → Manage Export Templates → Download and Install*.

### Configure Godot

*Editor → Editor Settings → Export → Android*, set:

- **Android SDK Path** — usually `C:\Users\husse\AppData\Local\Android\Sdk`
- **Java SDK Path** — your JDK 17 folder

Then *Project → Install Android Build Template*.

### Debug keystore

Godot needs a keystore to sign debug builds:

```bash
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
```

Point *Editor Settings → Export → Android → Debug Keystore* at the result.

### Export

*Project → Export → Add → Android*. The preset in `export_presets.cfg` is
already configured (package name, orientation, permissions, arm64 target).
Then **Export Project** to get the `.apk`, or plug in a phone with USB
debugging on and hit the small Android icon in the top-right of the editor to
deploy and run directly.

---

## How it plays

- **Steering** — tilt the phone, or drag anywhere on screen. Both are live at
  once. It's lean-based, not lane-snapped: you can put the bike anywhere on
  the road, which is the whole point of riding a motorcycle through traffic.
- **Throttle** — automatic. Hold anywhere to brake.
- **Credits** — earned per kilometre, multiplied by how close you pass cars.
  A clean, careful run earns; a fast, reckless one earns several times more.
  Passing within 1.3 m counts as a near miss and pushes the multiplier up to
  5x. It decays constantly, so you have to keep taking risks to hold it.
- **Difficulty** — the speed ceiling climbs with distance, up to +14 m/s over
  the base bike. Traffic doesn't get denser; you get faster, which is harder.

---

## Project layout

```
project.godot              engine config, input map, autoloads
scenes/Main.tscn           the only scene — world, HUD, and menus in one tree

scripts/
  main.gd                  flow: menu -> run -> summary -> garage
  world.gd                 chunk recycling, camera rig, Milad parallax
  player.gd                the rider: lean steering, speed, crash

  systems/
    game.gd                [autoload] credits, distance, save file
    radio.gd               [autoload] the music station
    sfx.gd                 [autoload] engine, horns, voice, rain
    traffic_manager.gd     spawning, driving, near-miss and collision
    weather.gd             day/night cycle, rain, wetness
    cigarette.gd           the smoke break
    bike_catalog.gd        5 motorcycles + paints + upgrade pricing
    car_catalog.gd         13 Tehran vehicles as lofted section profiles

  build/
    vehicle_builder.gd     lofts car bodies from profiles
    bike_builder.gd        builds the motorcycle and rider rig
    road_builder.gd        one reusable chunk of expressway
    city_builder.gd        Milad Tower, roadside blocks, Alborz ridge
    material_library.gd    shared materials + global wetness

  ui/                      hud, menu, summary, garage

assets/
  music/                   EMPTY — put your tracks here
  sfx/                     synthesised sound set (20 clips)

tools/generate_audio.py    regenerates the sound set
```

---

## Two things to know about the content

**The music.** The radio plays whatever you put in `assets/music/`. The game
ships with nothing. See `assets/music/README.md` for why, and for how to add
your own tracks.

**The cars.** The vehicles are original approximations — hand-written body
profiles tuned to evoke the Tehran street mix, so a Paykan reads boxy and
upright and a 206 reads short and round-tailed. They are stylised lookalikes,
not licensed or dimensionally accurate models. Fine for a personal project; if
you ever ship this commercially with the real marque names in the UI, get
advice on trademark first. Renaming them is a one-line change per entry in
`car_catalog.gd`.

---

## Where to go next

Roughly in order of what would most improve it:

1. **Play it and tune the feel.** Steering authority, the speed ramp, and
   traffic density are the three numbers that decide whether it's fun. They're
   all exported or near the top of their files.
2. **Real 3D models.** The procedural geometry is deliberately structured so
   models can replace it: swap `VehicleBuilder.build()` for a loaded `.glb` per
   body id and nothing else changes. This is the single biggest visual upgrade
   available, and it's an asset problem, not a code one.
3. **Real Persian voice recordings.** Drop them into `assets/sfx/voice/` with
   the same filenames. The synthesised placeholders have the right rhythm and
   vowel colour but carry no actual words.
4. **More road variety** — overpasses, tunnels, the Modarres/Hemmat
   interchanges, a Milad flyby section.
5. **Traffic behaviours** — cars cutting you off, doors opening, a motorbike
   rival to race.
