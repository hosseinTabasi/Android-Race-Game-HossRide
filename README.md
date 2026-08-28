# HossRide

Android race game.

**Author:** Hossein Tabasi ([hosseinTabasi](https://github.com/hosseinTabasi)), 2026.
**Licence:** MIT.
**Platform:** Android race game.
**Status:** specification-complete original title.

HossRide is a night ride through Tehran. Rain does not lift. Day does not
come. The rider is a body on a machine, held still in the world, while the
city moves. Thirteen street vehicles pass by lofted silhouette. Sodium
lamps colour the wet asphalt. Milad Tower stands by a locked geometry.
The destination is Amirabad. Arrival ends the work. There is nothing to
collect.

## Design question

Can an endless rider be built when filtration, not speed, is the
governing quantity?

Velocity exists. The world moves. Traffic approaches. Rain falls. None of
those speeds decide whether a system may run. Admission into a live set
decides. Draw, emit, mix, and spawn are downstream of that filter.
Relative velocity is then the only motion quantity that members of the
live set are allowed to use. The rider does not travel. The world does.

## Repository layout

```
HossRide/
├── LICENSE                 MIT, Hossein Tabasi, 2026
├── CITATION.cff            citation metadata
├── CONTRIBUTING.md         errata only
├── README.md               this file
├── .gitignore              Android, Unity, Godot, secrets, packages
└── docs/
    ├── index.html          entry page (links to the specification)
    ├── master-prompt.html  canonical specification (open in a browser)
    ├── DESIGN.md           palette, type, numbering, treadmill
    ├── ANDROID.md          generic build, sign, and install notes
    └── PALETTE.md          specification colour tokens
```

This tree does not contain engine source, screenshots, or a shipped
package. The specification is the instrument that can produce the game
again.

## How to read the specification

Open `docs/master-prompt.html` locally in a browser. A `file://` path is
enough. The page is self-contained (HTML, CSS, and a rain canvas).

Google Fonts load Oswald, IBM Plex Sans, and IBM Plex Mono when the
machine has a network. If the network is absent, the page remains
readable on system condensed, sans, and mono faces.

The rain canvas reads CSS theme tokens, follows night and day themes,
and does not run when `prefers-reduced-motion: reduce` is set. Print
style hides the canvas.

Read the fourteen sections in order. Numbering is dependency order, not
decoration. See `docs/DESIGN.md`.

## How to rebuild from the fourteen sections

Do not start at the Android package. Start at the governor.

1. Hold sections 01 and 02. Filtration is prior to every call. No later
   system is allowed to update by speed and cull afterwards.
2. Build the treadmill (03). Immobilise the rider. Move the world.
   Express motion only as relative velocity.
3. Admit thirteen Tehran street vehicles (04) through that filter. Use
   lofted profiles. Hold the 42 percent white paint share as a
   population parameter. Do not invent public names for the thirteen
   if the author has not published them.
4. Place the machine, the rider, and the cigarette (05 to 07) as three
   smoke jobs. Do not collapse ember, exhale, and wind-carried trail
   into one emitter.
5. Lock climate (08). Night is permanent. Rain is permanent. Then place
   lightning on a dedicated light and lock Milad Tower geometry (09).
6. Synthesise audio (10). Mix so that engine and rain dominate. Keep
   interface sound quiet. Do not invent frequencies this document does
   not give.
7. Refuse collectibles (11). Close on arrival at Amirabad (12), not on
   a score chase.
8. Ship on Android (13). Audit against the five standing constraints
   (14).

Exact engine commands are not given. The specification does not name
Unity, Godot, or a native stack as a requirement. Any toolchain that
can honour the five constraints and emit an Android package is in
scope. See `docs/ANDROID.md`.

## Android notes

The ship target is a modern Android device. This repository does not
pin an API level, a Gradle identifier, an application id, or an engine
version. Those values belong to an implementation tree that is not
present here.

Build, sign, and install as a ordinary Android release. Keep keystores
out of version control. Confirm on hardware: night, rain, filtration,
treadmill, three smokes, dedicated lightning, lopsided mix, no
collectibles, arrival at Amirabad.

HossRide is an original Android title by the author. This documentation
tree does not claim a store listing.

## Limitations

The specification is the source of truth. Binary and source of a shipped
package are not in this documentation tree. No performance figures are
reported. No vehicle names are listed. No screenshots are supplied. Hex
values in `docs/PALETTE.md` are specification tokens derived from the
described look. They are not measured from a captured frame.

## Citation

See `CITATION.cff`. Author: Hossein Tabasi, 2026, Tehran, Android.
