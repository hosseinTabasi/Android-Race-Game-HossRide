# Palette tokens

HossRide, Hossein Tabasi, 2026.

These hex values are specification tokens. They are derived from the
described look: wet asphalt, sodium street lighting, ember. They are
not colorimetric measurements from a device screen, a photograph of
Tehran, or a captured frame of a build. Treat them as starting locks
for materials and for the specification HTML. Adjust in engine only
with the author's leave, and keep the three roles distinct.

## Roles

| Role | Token | Hex | Use |
| --- | --- | --- | --- |
| Wet asphalt | `--asphalt` | `#121214` | Ground, unlit mass, night page background |
| Asphalt lift | `--asphalt-lift` | `#1A1A1E` | Panels, raised road, card faces |
| Fog mass | `--fog` | `#2A2A30` | Distant unlit volume |
| Sodium | `--sodium` | `#E0A040` | Street light, headings, rain tint on night |
| Sodium deep | `--sodium-deep` | `#D4A017` | Deeper amber, light-theme headings, print |
| Ember | `--ember` | `#C23B22` | Pull quotes, cigarette coal, heat |
| Paper | `--paper` | `#E8E4DC` | Body text on night ground |
| Paper dim | `--paper-dim` | `#B8B4AC` | Secondary text on night ground |

## Reading aid (HTML only)

The game is nocturnal. A light theme exists only on the specification
page, so the document can be read in daylight.

| Role | Token | Hex |
| --- | --- | --- |
| Day ground | `--bg` (light) | `#EFECE6` |
| Day text | `--fg` (light) | `#161618` |
| Day rain stroke | `--rain-stroke` (light) | `rgba(18, 18, 20, 0.22)` |

Night rain stroke is sodium at low alpha:
`rgba(224, 160, 64, 0.28)`.

## Constraints on use

- Sodium illuminates. It is not heat. Do not colour the cigarette coal
  with `--sodium`.
- Ember is heat. It is not street light. Do not wash the road with
  `--ember`.
- Asphalt stays near-black. Lifting it toward grey turns permanent
  night into dusk. Dusk is out of specification.
