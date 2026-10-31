# Accretion

A Swift port of Matt Burdick's *accrete*, the star-system generator based on Stephen H. Dole's
1969 RAND paper "Formation of Planetary Systems by Aggregation: a Computer Simulation" and
Martyn Fogg's planetary-environment equations. It has been extended with all main-sequence
star classes, binary and triple stars, and dynamically stable planet placement.

The project has two targets that share one generator:

| Target | Kind | Purpose |
|---|---|---|
| `Accretion` | Command-line tool | Generates one system and writes the classic text report |
| `AccretionApp` | macOS SwiftUI app | Generates 1, 10, 100 or 1000 systems and draws them |

## Project layout

| Path | Contents |
|---|---|
| `Shared/` | Generator, compiled into both targets |
| `Shared/StarSystemGenerator.swift` | Top-level `generate()`, RNG helpers (from `MAIN.C` / `UTILS.C`) |
| `Shared/Stars.swift` | Star physics, companion orbits, stability limits |
| `Shared/Accrete.swift` | Dole's dust accretion and planetesimal coalescence (`ACCRETE.C`) |
| `Shared/Enviro.swift` | Fogg's planetary environment equations (`ENVIRO.C`) |
| `Shared/Models.swift` | `Planet`, `Star`, `Companion`, `SpectralClass`, `StarSystem`, `SplitMix64` |
| `Shared/Constants.swift` | Physical constants (`CONST.H`) |
| `Shared/Display.swift` | Text report (`DISPLAY.C`) |
| `Accretion/main.swift` | CLI entry point |
| `AccretionApp/` | SwiftUI app: `ContentView`, `SystemRow`, `PlanetKind`, `SystemCatalog` |

The `Shared` folder is a synchronized folder with membership in both targets. New generator files
added there are picked up by the CLI and the app automatically.

## Command-line tool

```
Accretion [-v] [-s <seed>] [-o <file>]
  -v  print accretion progress (the original's VERBOSE output)
  -s  seed, to regenerate a specific system
  -o  output file (default: New.System in the current directory)
```

The report lists the seed, every star (designation, mass, luminosity, radius, temperature),
each companion's orbit, where planets may orbit, and every planet's physical properties.
A seed always regenerates the same system, as long as the generator code is unchanged.

## The app

Select the **AccretionApp** scheme and run. Pick 1, 10, 100 or 1000 in the toolbar and press
**Generate** (⌘G). Systems are generated in parallel off the main actor, and the bottom bar shows
how long the batch took. Ten systems are generated at launch.

Each row shows one system:

- **Left column:** the star the planets orbit, colored by temperature (red M through blue O). If the
  planets orbit a close pair, both stars are drawn. Hover for mass, radius and temperature.
- **Distance axis:** logarithmic, 0.01 to 1000 AU, with labels pinned at the top. A log axis is
  needed because bodies range from about 0.01 AU (red dwarfs) to hundreds of AU.
- **Planets:** colored by type and sized by radius on a square-root scale so gas giants don't
  swamp the row.
- **Planetoid belts:** drawn as a scatter of small dots.
- **Habitable zone:** a green line from its inner to its outer edge.
- **Stability limits:** orange dashed marks where companion stars make orbits unstable.
- **Companion stars:** placed at their separation, with a bar from closest (periastron) to farthest
  (apastron) approach and a label such as `M4V 8.1 AU`. Companions beyond 1000 AU are pinned to
  the right edge; the label shows the real distance.
- **Caption:** star designations, configuration (single, S-type binary, circumbinary, triple),
  host mass and luminosity, body count and seed. The seed can be passed to the CLI with `-s`.

Star sizes use a cube-root scale (`28 × R^⅓` points, capped at 60). Radii span about 0.1 to 14 solar
radii, so a linear scale would make red dwarfs invisible or O stars overflow the row. Stars stay
in size order.

### Planet types

The generator doesn't label planets, so the app classifies them from computed values
(`AccretionApp/PlanetKind.swift`), checked in this order:

| Type | Rule |
|---|---|
| Gas giant | Gas giant of 25 Earth masses or more |
| Ice giant | Gas giant under 25 Earth masses |
| Planetoid belt | Rocky body under 0.01 Earth masses |
| Airless rock | No atmosphere |
| Hothouse | Runaway greenhouse effect |
| Ice world | More than half the surface is ice |
| Ocean | 95% or more of the surface is water |
| Earthlike | Some water, 0.1–5 atmospheres, 0–50 °C |
| Desert | Everything else |

The generator never produces belts itself; very small rocky bodies are drawn as belts. The
thresholds are constants in `PlanetKind.swift`.

### Habitable zone

The inner edge is the generator's runaway-greenhouse radius (0.93 × √L AU). The outer edge is
Kasting's 1.37 AU for a Sun-like star, scaled by √L. The 1.37 figure is a choice made for the
display; the original code has no outer edge.

## Generator

### Stars

Each system starts with a primary star. A spectral class is picked by weight, then a mass is
drawn log-uniformly within that class's range. Everything else follows from the mass:

| Quantity | Relation |
|---|---|
| Luminosity | 0.23·M^2.3 below 0.43 M☉; M^4 to 2 M☉; 1.4·M^3.5 to 20 M☉; flattens as M^2.5 above 20 M☉ |
| Radius | M^0.8 below 1 M☉; M^0.65 above |
| Temperature | 5778 K × (L / R²)^¼ |
| Class and subclass | From temperature, e.g. the Sun is G2V |

The original's single luminosity formula goes negative above about 10 solar masses, so it was
replaced. The flatter slope above 20 M☉ and the M^0.65 radius keep O stars realistic: a 40 M☉ star
comes out at about 11 R☉ and 40,000 K, and 60 M☉ at about 45,000 K (O2V).

Class ranges (`Shared/Models.swift`):

| Class | Temperature (K) | Mass range (M☉) | Frequency | With companions |
|---|---|---|---|---|
| O | 30,000–50,000 | 17.1–60 | 0.00003% | 75% |
| B | 10,000–30,000 | 2.33–17.1 | 0.13% | 70% |
| A | 7,500–10,000 | 1.47–2.33 | 0.6% | 60% |
| F | 6,000–7,500 | 1.057–1.47 | 3.0% | 50% |
| G | 5,200–6,000 | 0.839–1.057 | 7.6% | 46% |
| K | 3,700–5,200 | 0.476–0.839 | 12.1% | 40% |
| M | 2,300–3,700 | 0.08–0.476 | 76.45% | 27% |

- **Frequencies** are solar-neighbourhood shares of main-sequence stars (LeDrew 2001). A batch
  of 1000 usually has no O stars and about one B star.
- **Mass ranges** are where the mass–luminosity and mass–radius relations cross each class's
  temperature boundary, so a drawn star always keeps its class.
- **Companion rates** are from Duchêne & Kraus (2013).

The primary is the most massive star, so its main-sequence lifetime (10¹⁰ × M/L years) sets the
system's age. Short-lived stars get an age between 10% and 100% of their lifetime.

### Multiple stars

- **Companions:** a primary gets a companion with its class's probability above. A quarter of
  multiple systems are hierarchical triples, where a third star orbits the inner pair.
- **Companion mass:** drawn from a flat mass ratio, q = 0.1 to 1 of the primary, with a 0.08 M☉ floor.
- **Separations:** drawn from log-normal period distributions, converted to separations with
  Kepler's third law:

  | Primary | log₁₀ period (days), mean ± σ | Source |
  |---|---|---|
  | O | 2.5 ± 1.8 | Massive stars favour tight pairs (Sana et al. 2012) |
  | B | 3.0 ± 2.0 | |
  | A | 4.0 ± 2.3 | |
  | F, G, K | 5.03 ± 2.28 | Raghavan et al. 2010 |
  | M | 4.7 ± 2.0 | Peak near 20 AU (Winters et al. 2019) |

- **Eccentricity:** pairs under 12 days are tidally circularized (e = 0). Otherwise e is uniform
  up to 0.6 for periods under 1000 days, and up to 0.8 beyond.
- **No contact:** pairs closer than 3 × (R₁ + R₂) at periastron are rejected.
- **Triples:** the outer orbit must pass the Mardling & Aarseth (2001) stability test,
  periastron > 2.8 (1 + q)^0.4 (1 + e)^0.4 (1 − e)^−0.2 × inner separation.

### Planet placement

Planets only form where orbits are dynamically stable, using Holman & Wiegert (1999):

- **S-type (circumstellar):** planets orbit the primary inside the companion's orbit, out to
  a_crit = (0.464 − 0.380μ − 0.631e + 0.586μe + 0.150e² − 0.198μe²) × a_bin.
  This is used when that limit leaves room for planets (more than twice the innermost orbit).
- **P-type (circumbinary):** otherwise planets orbit the whole close pair, beyond
  a_crit = (1.60 + 5.10e − 2.22e² + 4.12μ − 4.27eμ − 5.09μ² + 4.61e²μ²) × a_bin.
  The pair's combined mass and luminosity are used for the disk and planet environments.
- **Triples:** the third star also trims the outer edge.

The dust disk is cleared inside a P-type limit and cut off outside an S-type limit, and
protoplanets are only injected in the remaining stable band. If no band is left, the system has
no planets. Planets don't form around distant companions.

**Innermost orbit:** the smaller of Dole's 0.3·M^⅓ AU and 0.5·√L AU. Sun-like stars keep about
0.3 AU. Red dwarfs get close-in planets as observed for TRAPPIST-1 (0.011–0.06 AU) and Proxima b
(about 0.05 AU). Because the limit depends on brightness, it also moves inward slightly for
K dwarfs below about 0.75 M☉, so there's no jump at the K/M boundary.

### Changes from the original C code

- New mass–luminosity relation and star physics for O through M (above).
- Primary class and mass drawn by realistic frequencies instead of a uniform 0.6–1.3 M☉.
- Binary and triple stars with stability-limited planet zones.
- Innermost planet orbit scales with luminosity.
- Gas escape (RMS velocity) scales the exosphere temperature with the star's luminosity; the
  original assumed a Sun-like star. Sun-like results change only slightly.
- Ages for short-lived stars stay within their lifetime.
- A seedable SplitMix64 RNG, so any system can be regenerated from its seed.

Because the star-picking and RNG order changed, seeds produce different systems than in earlier
versions of this project.

## Validation

Statistics from CLI runs over many seeds (Release build):

| Check | Result |
|---|---|
| Class mix, 2000 seeds | 76.1% M, 11.9% K, 8.0% G, 3.4% F, 0.6% A, 0.1% B, 0 O |
| Layouts, 1000 seeds | 303 S-type, 101 circumbinary, 93 triples, 5 with no stable planets |
| Companion separation, 1000 seeds | Median 33 AU; 25%–75% from 4 to 430 AU; 0.02 to 25,000 AU overall |
| O stars | O9V at 18 M☉ / 31,000 K to O2V at 60 M☉ / 45,000 K |
| Innermost planet around M dwarfs | 0.014 AU minimum, 0.044 AU median |
| Innermost planet around G dwarfs | 0.29 AU (unchanged) |
| M dwarfs with a body in the habitable zone | 83% (0% before the inner-limit change) |

Worked example, seed 162 (circumbinary triple):

- **Inner pair:** two B7V stars 0.24 AU apart. Circumbinary orbits are stable beyond
  2.45 × 0.24 ≈ 0.58 AU.
- **Third star:** a K3V at 500 AU with e = 0.8. It trims the stable zone to 26 AU.
- **Triple stability:** periastron is about 100 AU against a minimum of about 1.2 AU, so the
  triple is stable.

The 83% habitable-zone figure is higher than real estimates because this model packs planets
densely around every star.

## Performance

Measured with the original single-star generator, before multiple stars were added: a Release
build, seeds 1–10, 50 runs each, timed from launch to exit.

| Seed | Planets | Mean (ms) | Min (ms) | Max (ms) |
|---|---|---|---|---|
| 1 | 11 | 8.16 | 6.73 | 9.20 |
| 2 | 11 | 7.99 | 7.31 | 9.55 |
| 3 | 13 | 8.10 | 7.30 | 14.34 |
| 4 | 12 | 7.85 | 6.93 | 8.66 |
| 5 | 15 | 7.89 | 7.31 | 9.07 |
| 6 | 11 | 7.68 | 7.02 | 8.14 |
| 7 | 12 | 7.71 | 6.80 | 8.66 |
| 8 | 13 | 7.71 | 7.02 | 8.61 |
| 9 | 12 | 7.77 | 7.06 | 8.51 |
| 10 | 13 | 7.80 | 6.73 | 8.69 |

- **Total:** about 79 ms for 10 systems, about 8 ms each.
- **Startup dominates:** launching an empty program takes about 2.9 ms, and loading the Swift
  runtime adds a few more, so the generator itself takes a millisecond or two at most.
- **Planet count doesn't matter:** run time doesn't track the number of planets.
- **First launch:** a newly built binary's first launch took 0.67 s once while macOS checked it.

After adding multiple stars, 1000 CLI runs took about 10 s (about 10 ms each, still mostly
startup). The app showed about 0.22 s for 10 systems in a Debug build; Release is much faster.

## Brown dwarfs

The generator doesn't produce brown dwarfs. A few have planets or planetary-mass companions:

- **2M1207 b** (imaged directly, 2004): about 5 Jupiter masses at about 40 AU around a brown dwarf of
  about 25 Jupiter masses. It probably formed like a binary star rather than in a disk.
- **OGLE-2012-BLG-0358L b** (microlensing): about 2 Jupiter masses at about 0.9 AU around a brown
  dwarf of about 0.02 M☉.
- **Disks:** ALMA has imaged dusty disks around young brown dwarfs, so small rocky planets are
  plausible, though none like Earth have been found.

Brown dwarfs never fuse hydrogen steadily and cool as they age, so their temperature and
brightness depend on age as well as mass. Adding them would need new L, T and Y classes with an
age-based cooling model rather than the main-sequence relations used here.

## Known limitations

- Planets only form around the primary or a close pair, never around distant companions.
- Starlight from a distant companion isn't added to an S-type planet's heating.
- Moons are not generated (a stub in the original).
- The Xcode preview for `ContentView` crashes inside SwiftUI before any app code runs. It looks
  like a preview problem; the app itself runs fine.

## Change history

1. Ported the C generator to Swift as a command-line tool.
2. Measured run time for 10 systems (see Performance).
3. Added the SwiftUI app target and moved the generator into `Shared/`.
4. Added all main-sequence classes (O–M), binary and triple stars, and stability-limited
   planet placement.
5. Corrected O-star luminosity and radius; fixed the legend labels.
6. Relaxed the innermost planet orbit for red dwarfs; switched to realistic class frequencies
   with matching mass ranges.
