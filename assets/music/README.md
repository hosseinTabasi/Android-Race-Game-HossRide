# Radio music

This folder is empty on purpose. **The game ships with no music.**

The radio system in `scripts/systems/radio.gd` is fully built — continuous
playback across runs, shuffle, crossfade-safe track changes, a now-playing
strip on the HUD, and ducking under crashes. It just needs files to play.

## Adding tracks

Drop `.ogg` or `.mp3` files into this folder before you export the build, and
they ship inside the APK.

Better for a phone: put them in the app's own music folder on the device
instead, so you can change the playlist without rebuilding. Godot's `user://`
path on Android resolves to:

```
/Android/data/com.hosseinrides.game/files/music/
```

The radio scans that directory first, then this one, and merges both. It
rescans on launch, and you can force a rescan from code with `Radio.rescan()`.

## Naming

Titles come from the filename, because there is no reliable ID3 reader here.
Use this convention and the HUD shows both fields correctly:

```
Artist - Title.mp3
```

Leading track numbers are stripped automatically, so `03 - Artist - Title.mp3`
also works. Underscores become spaces. A file with no ` - ` separator shows its
whole filename as the title.

## On the Morteza Pashaei soundtrack

You asked for his albums to play as the station. I did not download them, and
the project deliberately ships without them: his catalogue is commercial
copyrighted music, and pulling it off the web would be piracy — not something
I'll do for you, even for a personal build.

What I built instead is the whole system around it. If you own his albums —
bought from a store, or ripped from CDs you own — copy those files into this
folder or the device folder above, and the game behaves exactly as you
described: his music playing continuously over the ride, like a radio station,
with track names on screen.

If you want to distribute the game to anyone else, you need a licence for
whatever music is in it. For a public release, the practical options are
production-music libraries, or commissioning a Persian-language artist
directly — a few tracks of original Iranian pop would fit the game and be
genuinely yours to ship.
