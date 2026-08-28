# Android pipeline

HossRide ships on Android. This note expands section 13 of the
specification. It does not name an engine. It does not invent a Gradle
application id, a plugin version, a minimum SDK integer, or a package
name. Those identifiers belong to an implementation tree that is not in
this repository.

## Target

A modern Android device. 64-bit. Physical hardware is preferred for
acceptance, because sodium night, rain, and the lopsided mix need a
real display and a real speaker. An emulator can prove install. It
cannot prove the climate.

Desktop play inside an editor is not the ship.

## What this repository does not contain

No project module, no store listing claim, no keystore, no unsigned
package, no signed package. `.apk` and `.aab` files, and any keystore
or signing key, are ignored by `.gitignore` on purpose.

## Generic steps

1. Choose a toolchain that can honour the five standing constraints
   (specification section 14) and emit an Android package. The
   specification is engine-agnostic on purpose.
2. Install a current Android SDK, platform tools (`adb`), and the
   build tools required by that toolchain. Pin versions in the
   implementation tree, not here.
3. Choose a reverse-DNS application identifier and keep it stable.
   Do not publish that identifier in this documentation as if it were
   already assigned.
4. Compile against a current Android API. This note does not pin the
   number. Raise the target when the toolchain requires it. Do not
   lower it to admit a device that cannot hold night, rain, and three
   smoke jobs at once.
5. Produce a release artefact by the toolchain's release path
   (an Android App Bundle or a package). A debug install is for the
   author. It is not the artefact that section 13 calls a ship.
6. Sign with a private key that never enters version control. Store
   the keystore outside the repository. Do not attach it to issues.
7. Install on a device:

   ```
   adb install -r <release-package>
   ```

   Or install from the bundle tool of record for that toolchain. The
   command above is a pattern. The file name is not supplied.
8. Launch. Confirm the acceptance list below. Uninstall when done:

   ```
   adb uninstall <application-identifier>
   ```

## Acceptance on device

All of the following must hold. Failure of one is failure of the ship.

- Filtration governs. Objects, lights, voices, and particle jobs
  outside the live set do not run.
- The rider does not translate through the world. The world moves.
  Relative velocity is the motion quantity.
- Night does not break. Rain does not lift.
- Thirteen street vehicles. Lofted profiles. 42 percent white paint
  over the traffic population.
- Three smoke systems: machine trail, rider exhale, cigarette ember.
  Separate lifetimes, lighting, and budgets.
- Lightning is a dedicated light, not only a full-screen flash.
- Milad Tower follows the locked geometry and enlarges toward Amirabad.
- Audio is synthesised. Engine and rain dominate. Interface is quiet.
- No collectibles on the road.
- Arrival at Amirabad closes the ride. It is not a score chase.

## Signing and secrets

Keystores, `.jks`, `.keystore`, `.key`, `.pem`, and
`local.properties` stay off the remote. If a secret is committed by
mistake, rotate the key. Do not rewrite history as a substitute for
rotation.

## Store listing

This documentation tree describes an original Android title by
Hossein Tabasi. It does not claim a public store listing. A later
listing, if it exists, is a distribution fact. It is not part of this
specification.
