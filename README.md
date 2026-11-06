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
| `Shared/Habitability.swift` | Earth Similarity Index and the potentially-habitable test |
| `Accretion/main.swift` | CLI entry point |
| `AccretionApp/` | SwiftUI app: `ContentView`, `SystemRow`, `PlanetDetailView`, `PlanetKind`, `SystemCatalog` |

The `Shared` folder is a synchronized folder with membership in both targets. New generator files
added there are picked up by the CLI and the app automatically.

## Command-line tool

```
Accretion [-v] [-s <seed>] [-o <file>]
  -v  print accretion progress (the original's VERBOSE output)
  -s  seed, to regenerate a specific system
  -o  output file (default: New.System in the current directory)
```

The report lists the seed, every star (designation, mass, luminosity, radius, temperature) and
each companion's orbit. Then, for each star (or close pair) with planets, a "PLANETS OF …"
section gives its stable zone, habitable ecosphere and every planet's physical properties.
A seed always regenerates the same system, as long as the generator code is unchanged.

## The app

Select the **AccretionApp** scheme and run. Pick 1, 10, 100 or 1000 in the toolbar and press
**Generate** (⌘G). Systems are generated in parallel off the main actor, and the bottom bar shows
how long the batch took. Ten systems are generated at launch.

Each row shows one system:

- **Left column:** the star the planets orbit, colored by temperature (red M through blue O). If the
  planets orbit a close pair, both stars are drawn. Hover for mass, radius and temperature.
- **Distance axis:** logarithmic, 0.001 to 1000 AU, with labels pinned at the top. A log axis is
  needed because bodies range from about 0.01 AU (red dwarfs) to hundreds of AU.
- **Planets:** colored by type and sized by radius on a square-root scale so gas giants don't
  swamp the row.
- **Planetoid belts:** drawn as a scatter of small dots spanning the belt's extent.
- **Habitable zone:** a green line from its inner to its outer edge.
- **Stability limits:** orange dashed marks where companion stars make orbits unstable.
- **Companion stars:** placed at their separation, with a bar from closest (periastron) to farthest
  (apastron) approach and a label such as `M4V 8.1 AU`. Companions beyond 1000 AU are pinned to
  the right edge; the label shows the real distance.
- **Caption:** star designations, configuration (single, S-type binary, circumbinary, triple),
  host mass and luminosity, body count and seed. The seed can be passed to the CLI with `-s`.

### Companion stars' planets

Companions with their own planets show them collapsed in a short strip next to the star: tiny dots
in planet-type colors, spread over that star's own range of distances.

- **Expand a companion:** click the companion or its strip. Its planets, habitable zone and
  stability limit take over the row, measured from that star. The caption starts with
  "Planets of M4V" (or whichever star is in focus).
- **Collapse the primary:** the primary (or close pair) moves to its separation on the axis,
  with its planets collapsed into a strip.
- **From the third star of a triple:** the inner pair appears as one group at the outer orbit.
  Clicking it returns to the primary.
- **Return:** click the star in the left column, or the primary's strip.

The change crossfades over a quarter of a second, and each row keeps its own focus. Planet selection and
the details panel work the same for every star, and the panel's "Orbits" row names the star.

### Planet details

Click any planet or planetoid belt to open its details in an inspector panel on the right of the
window. The selected body gets a white ring in its row. Clicking another body switches the panel
to it, and the panel stays open while you scroll. Close it with the × button or Escape;
generating a new batch also closes it.

Clicks are matched against the same layout used for drawing (`OrbitTrack.frame(of:in:)`), and
small bodies get a hit area at least 14 points across so they stay easy to click. If bodies
overlap, the one nearest the click wins.

The panel shows:

| Section | Values |
|---|---|
| Header | Planet number, type, seed, and badges for "In habitable zone", "Runaway greenhouse" and "Spin–orbit resonance" |
| Orbit | Host star(s), distance, eccentricity, year, day, axial tilt |
| Body | Mass, radius (km and Earth radii), density, escape velocity, lightest gas retained, albedo |
| Surface | Gravity, pressure, temperature, water boiling point, hydrosphere, cloud and ice cover (rocky bodies only) |

An inspector was chosen over a popover. A macOS popover closes whenever the app loses focus,
and an inspector also lets you compare planets while scrolling.

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
| Planetoid belt | Formed by the generator (see Planetoid belts below) |
| Airless rock | No atmosphere |
| Hothouse | Runaway greenhouse effect |
| Ice world | More than half the surface is ice |
| Ocean | 95% or more of the surface is water |
| Earthlike | Some water, 0.1–5 atmospheres, 0–50 °C |
| Desert | Everything else |

The giant threshold is a constant in `PlanetKind.swift`.

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
| O | 30,000–50,000 | 17.1–60 | 0.00003% | 90% |
| B | 10,000–30,000 | 2.33–17.1 | 0.13% | 80% |
| A | 7,500–10,000 | 1.47–2.33 | 0.6% | 60% |
| F | 6,000–7,500 | 1.057–1.47 | 3.0% | 50% |
| G | 5,200–6,000 | 0.839–1.057 | 7.6% | 46% |
| K | 3,700–5,200 | 0.476–0.839 | 12.1% | 40% |
| M | 2,300–3,700 | 0.075–0.476 | 76.45% | 27% |
| L | 1,300–2,300 | Brown dwarfs and the faintest stars | see Brown dwarfs | 20% |
| T | 500–1,300 | Brown dwarfs | see Brown dwarfs | 20% |
| Y | below 500 | Brown dwarfs | see Brown dwarfs | 20% |

- **Frequencies** are solar-neighbourhood shares of main-sequence stars (LeDrew 2001). A batch
  of 1000 usually has no O stars and about one B star.
- **Mass ranges** are where the mass–luminosity and mass–radius relations cross each class's
  temperature boundary, so a drawn star always keeps its class.
- **Companion rates:** M from Winters et al. (2019), FGK from Raghavan et al. (2010), and A–O from
  Moe & Di Stefano (2017) as summarised by Offner et al. (2023).

The primary is the most massive star, so its main-sequence lifetime (10¹⁰ × M/L years) caps the
system's age. Ages are uniform between 1% and 100% of the smaller of that lifetime and 10 Gyr, a
constant star-formation history. Age doesn't affect planets, but it sets how far brown dwarfs
have cooled (see Brown dwarfs).

M dwarfs here include the lowest-mass stars, down to 0.075 M☉, which come out as early L
dwarfs.

### Multiple stars

- **Companions:** a primary gets a companion with its class's probability above. Some multiple
  systems are hierarchical triples, where a third star orbits the inner pair. The triple share
  rises with mass: 22% (M), 25% (F, G, K), 35% (A), 50% (B), 70% (O). Quadruples and higher are
  folded into triples.
- **How it compares with real life:** 30% of generated systems have more than one star, and 49%
  of all generated stars are in a multiple system. That matches the solar neighbourhood. The
  common "about half of stars are in multiples" figure counts stars, not systems; because 76% of
  primaries are red dwarfs, which are mostly single, only about a third of systems are multiple.
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
protoplanets are only injected in the remaining stable band. If no band is left, that star gets
no planets.

### Planetoid belts

Dole's accretion leaves runs of small neighbouring lumps where the dust is thin, especially close
to red dwarfs. After accretion, each run of neighbouring planetoids (rocky bodies under
`Const.beltMassLimit`, 0.01 Earth masses) is merged into one belt (`mergeBelts` in
`Shared/StarSystemGenerator.swift`). The belt has the planetoids' total mass and mass-weighted
distance, and records its extent and how many bodies it merged. Larger planets are untouched.

| Primary | Belts per system before | After |
|---|---|---|
| M | 8.4 | 2.0 |
| K | 2.3 | 1.2 |
| G | 1.4 | 0.6 |
| F | 1.2 | 0.8 |

A belt merges about 4 planetoids on average. Raising `Const.beltMassLimit` gives wider, rarer belts;
lowering it turns more planetoids into tiny airless rocks.

### Planets around companion stars

Every star that has room gets its own planetary system (`planetHostLayouts` in `Shared/Stars.swift`).
Each one is a `PlanetHost` in `StarSystem.hosts`, and the primary's (or close pair's) system is always first.

| Star | Disturbed by | Outer stability limit |
|---|---|---|
| Primary of a wide pair | Partner (and any third star) | S-type, μ = partner's share of the pair's mass |
| Partner of a wide pair | Primary (and any third star) | S-type, μ = primary's share of the pair's mass |
| Close pair, planets around both | Third star, if any | P-type inner limit, plus an S-type outer limit from the third star |
| Third star of a triple | The inner pair as one mass | S-type, μ = pair mass / total mass, using the outer orbit |

A companion only gets a planetary system when its stable zone extends past twice its innermost
planet orbit, the same test used to choose between S-type and P-type. Each system is accreted
separately, with that star's own mass, luminosity and habitable zone. Light from the other stars
isn't added.

Seed 1008 is an example: three M dwarfs, with a 77 AU inner pair (e = 0.15) and a third star at 866 AU
(e = 0.54). The primary is stable inside 17.7 AU, its partner inside 17.1 AU, and the third star
inside 73.3 AU.

Over 2000 seeds, 544 of the 611 multiple-star systems have more than one planetary system: 402 with two and 142
with three. The rest are mostly close pairs whose planets orbit both stars.

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

## Habitability

Every rocky planet (not gas giants or belts) gets two measures (`Shared/Habitability.swift`).

**Earth Similarity Index (ESI)** (Schulze-Makuch et al. 2011): 0 to 1, where Earth is 1. It
combines how close the radius, density, escape velocity and surface temperature are to Earth's,
weighted 0.57, 1.07, 0.70 and 5.58. Temperature counts most.

**Potentially habitable**, meaning it could support life as we know it. The planet must pass all
of these:

| Test | Requirement |
|---|---|
| Liquid water | Surface water in the environment model, which only keeps it between freezing and boiling at the surface pressure |
| No runaway greenhouse | |
| Temperature | 0–50 °C, the range most Earth life tolerates |
| Pressure | 0.1–10 atmospheres |
| Mass | 0.1–10 Earth masses: enough to keep an atmosphere, not a mini-Neptune |
| Age | System at least 0.5 Gyr old; Earth had life within about 0.7 Gyr |

"Potentially habitable" means the conditions allow Earth-like life, not that life is present.

### In the app

- **Sort:** the toolbar's **Sort** menu switches between *Generated* order and *Habitability*.
  Habitability puts systems with a potentially habitable planet first, ordered by ESI, then the
  rest by their best ESI. Each system is scored by its best planet around any of its stars.
- **Rows:** potentially habitable planets have a green ring, and the caption names the best one,
  for example "habitable: planet 3 (ESI 0.99)", adding the star's name if it orbits a companion.
- **Status bar:** shows how many systems in the batch have a potentially habitable planet.
- **Details panel:** rocky planets get a Habitability section with a verdict, the ESI and whether
  there's liquid water. A failing planet's verdict names the first test it fails, such as "Frozen,
  no liquid water", "Too small to hold an atmosphere" or "Runaway greenhouse".
- **CLI:** the report prints each rocky planet's ESI and flags "POTENTIALLY HABITABLE".

### Results (4000 seeds)

| Measure | Result |
|---|---|
| Potentially habitable planets | 194, in 178 systems (4.5% of all systems) |
| By host star | 130 G, 42 K, 22 F; none around M dwarfs, brown dwarfs, or A and hotter |
| Sun-like systems with one | 178 of 756 F, G and K systems, about a quarter |
| Rocky planets with liquid water | 430 of 45,653 |
| Why rocky planets fail | 43,286 frozen, 1,023 too hot, 914 dry or airless |
| ESI of rocky planets | 280 at 0.9 or above, 393 at 0.8–0.9, 2,718 at 0.6–0.8 |

The quarter of Sun-like systems falls within Kepler-based estimates of Earth-like planets in the
habitable zones of Sun-like stars (about 0.2–0.6 per star). A typical example is seed 10: a G3V
star with a planet at 1.07 AU of 2.1 Earth masses, 14.6 °C, 92% ocean and 4.4 atmospheres (ESI 0.96).
Another run produced a near twin of Earth around a G9V star: 0.99 Earth masses, 1.00 Earth
radii, 0.99 g, 1.3 atmospheres, 10.7 °C and 93.5% ocean (ESI 0.99).

**Red dwarfs get no habitable planets, which is a model limitation.** All 277 rocky bodies in
M-dwarf habitable zones are under 0.1 Earth masses, averaging 0.022 (about the Moon). Dole's
dust-disk density was calibrated for the Sun and starves red dwarfs' inner disks. Real red dwarfs
such as TRAPPIST-1 and Proxima Centauri have Earth-mass planets in their habitable zones.

## Brown dwarfs

Brown dwarfs are objects between about 13 and 78 Jupiter masses (0.013–0.075 M☉) that never fuse
hydrogen. They cool and fade for their whole lives, so a brown dwarf starts as an L, cools
through T, and the oldest, lightest ones become Y. Their class depends on age as well as mass.
So the L/T/Y amounts aren't set directly; they come from how many brown dwarfs form, of what mass
and when. This is the approach used to model the 20-parsec census (Kirkpatrick et al. 2021).

### How they are generated

| Step | Model | Source |
|---|---|---|
| How many | 22 brown dwarfs drawn per 100 stars, about 1 for every 4.5 stars | Kirkpatrick et al. 2019, 2021 |
| Mass | dN/dM ∝ M^−0.6 between 0.013 and 0.075 M☉ | Kirkpatrick et al. 2021 |
| Age | Uniform up to 10 Gyr (constant star formation), shared by the whole system | |
| Temperature | 1550 K × (t / 1 Gyr)^−0.32 × (M / 0.05 M☉)^0.83, capped at 2700 K | Burrows et al. 2001 |
| Luminosity | 4×10⁻⁵ L☉ × (t / 1 Gyr)^−1.3 × (M / 0.05 M☉)^2.64 | Burrows et al. 2001 |
| Radius | From L = R²T⁴; comes out about 0.09–0.14 R☉, roughly Jupiter's size | |
| Class | L 1300–2300 K, T 500–1300 K, Y below 500 K; hotter young ones are late M | |
| Companions | 20% are binaries, with near-equal masses (q = 0.5–1) and pairs peaking near 4 AU; 10% of those are triples | Burgasser et al. 2007; Fontanive et al. 2018 |

Brown dwarfs are also companions: a low-mass star's companion is a brown dwarf whenever the drawn
mass ratio puts it under 0.075 M☉. Brown-dwarf designations have no luminosity class ("T6",
not "T6V").

**The lowest-mass stars are L dwarfs too.** Below 0.1 M☉ the main-sequence formulas blend toward
the faintest star at the hydrogen-burning limit: 2075 K and 0.086 R☉, type L2 (Dieterich et al.
2014). Early L dwarfs are therefore a mix of the faintest stars and young brown dwarfs, as in the
real census.

### Results (4000 seeds)

| Measure | Result |
|---|---|
| Stars per brown dwarf | 3.7 |
| L / T / Y split | 27% L, 53% T, 20% Y |
| L dwarfs that are stars | 256 of 370 |
| Brown dwarfs hot enough to be late M | 17 (young and massive) |
| Lightest star | 0.075 M☉, L2, 0.086 R☉, 2075 K |
| Example brown dwarfs | Y8: 13 Jupiter masses, 247 K, 0.136 R☉; T4: 45 Jupiter masses, 979 K, 0.092 R☉ |
| Systems with more than one star | 26%, down from 30% because single brown dwarfs are now included |

As in the census, T dwarfs are the most common type. The census's Y count is still incomplete,
since Y dwarfs are very faint. Exact L/T/Y shares depend on the mass-function slope and age
spread, both constants in `Shared/Constants.swift`.

### Planets

Brown dwarfs get planets from the same accretion model. Their disks are thin and their light is
faint: luminosities of 10⁻⁷ to 10⁻⁴ L☉ put habitable zones at about 0.001–0.01 AU. The results
are mostly wide planetoid belts close in and small rocky bodies farther out, with no gas giants.
This fits the low disk masses seen around young brown dwarfs. A few real brown dwarfs have planets
or planetary-mass companions:

- **2M1207 b** (imaged directly, 2004): about 5 Jupiter masses at about 40 AU around a brown dwarf of
  about 25 Jupiter masses. It probably formed like a binary star rather than in a disk.
- **OGLE-2012-BLG-0358L b** (microlensing): about 2 Jupiter masses at about 0.9 AU around a brown
  dwarf of about 0.02 M☉.
- **Disks:** ALMA has imaged dusty disks around young brown dwarfs, so small rocky planets are
  plausible, though none like Earth have been found.

### In the app

- **Colors:** L dwarfs are deep red, T dwarfs magenta (sodium and potassium absorb the
  yellow-green), and Y dwarfs dim purple.
- **Legend and hover:** the legend includes L, T and Y, and hovering a brown dwarf shows its mass
  in Jupiter masses.
- **Axis:** now runs from 0.001 AU so brown dwarfs' close-in zones fit.
- **Belts:** drawn as faint translucent bands beneath the habitable zone, so wide debris zones
  don't hide it.

## Stellar remnants

Remnants are what stars leave behind. White dwarfs are common nearby; neutron stars and black
holes lie farther away (none within about 10 parsecs), so their odds come from Galaxy-wide
estimates.

| Object | Estimate | Model | Generated rate (20M seeds) |
|---|---|---|---|
| White dwarf | About 7 per 100 main-sequence stars nearby | 7 per 100 stars | 5.4% of systems, 1 in 19 |
| Neutron star | ~10⁹ for ~10¹¹ stars in the Galaxy | 1.0 per 100 stars | 0.77%, 1 in 130 |
| Black hole | ~10⁸ stellar-mass | 0.1 per 100 stars | 0.078%, 1 in 1288 |
| Young pulsar | ~10⁶ active | Neutron stars younger than 10 Myr | 1 in 135,000 |
| Millisecond pulsar | ~10⁵ | 1 in 10⁴ older neutron stars | 1 in 1.3 million |

Sources: Henry et al. (2018), Hollands et al. (2018), Timmes, Woosley & Weaver (1996),
Olejak et al. (2020), Faucher-Giguère & Kaspi (2006).

### White dwarfs

| Property | Model |
|---|---|
| Mass | Normal around 0.6 M☉ (σ 0.13), 0.17–1.35 M☉ (Kepler et al. 2007) |
| Radius | Nauenberg (1972): 0.0114 R☉ × √((M/1.44)^−⅔ − (M/1.44)^⅔); heavier is smaller, 4500–15,700 km |
| Cooling | Mestel's law, L ≈ M × (8.8 Myr / t)^1.4 L☉, floored at 3500 K, the coolest observed |
| Age | Cooling age spread up to 9 Gyr, plus a ~1 Gyr progenitor life |
| Class | DA (hydrogen lines) at 5000 K and hotter, DC below; number = 50,400 / T, so 10,000 K is DA5 |
| Companions | 25% (Holberg et al. 2016); up to 2 M☉ relative to the progenitor, and still on the main sequence, like Sirius A beside Sirius B |
| Planets | Lost inside 3 AU, engulfed when the star swelled into a giant (Mustill & Villaver 2012); outer planets survive |

Results from 4000 white dwarfs: temperatures 3500–47,000 K (median 5160 K), 54% DA and 46% DC,
89% with surviving planets. Their own planets are frozen. About 5% of white-dwarf systems have a
potentially habitable planet, all around companion F, G or K stars; seed 475 has an ESI 0.99 planet
around a G6V beside a DA5.

### Neutron stars, pulsars and black holes

| Property | Neutron star / pulsar | Black hole |
|---|---|---|
| Mass | Normal around 1.4 M☉, limited to 1.1–2.2 (Özel & Freire 2016) | Exponential tail above 6.3 M☉ with scale 1.57 (Özel et al. 2010), up to 40 |
| Size | 12 km radius | Event horizon 2.95 km per M☉, e.g. 19.9 km for 6.74 M☉ |
| Temperature | Cools from 10⁶ K: about 1.6×10⁵ K at 10 Myr, 10⁴ K at 10 Gyr (rough curve) | None of its own |
| Luminosity | From size and temperature: 10⁻⁴ to 10⁻⁹ L☉, mostly X-rays when young | Dark (a 10⁻¹² floor keeps the maths finite) |
| Companions | 10% (supernova kicks unbind most pairs); the companion is at most 1 M☉, a long-lived star that outlived the remnant's progenitor | Same |
| Planets | 0.5% grow a new system from a fallback disk within 0.1–1 AU, like PSR B1257+12 (planets at 0.19–0.46 AU, the first exoplanets found, in 1992) | None |

**Pulsars.** A pulsar is a neutron star still spinning fast enough to beam. Young ones spin
down within about 10 Myr; remnant ages are spread over 10 Gyr since the supernova, so about 1
neutron star in 1000 is a young pulsar. Millisecond pulsars are old neutron stars spun back up by
a companion. They hold their power for billions of years, and PSR B1257+12, the host of the
first known exoplanets, is one.

**Pulsar heating.** A pulsar's wind, powered by its spin-down, can outshine its surface by far:

| Pulsar | Spin-down power |
|---|---|
| Young | 10³⁸ erg/s ÷ (1 + t / 1000 yr)², about 10³² erg/s at 1 Myr and 10³⁰ at 10 Myr |
| Millisecond | About 10³⁴ erg/s, spread over a decade |

Planets absorb `Const.pulsarWindHeatingEfficiency` (10%) of it as heat, on top of the surface
glow. That share is the uncertain part, since much of the wind is particles and gamma rays
(Patruno & Kama 2017 explore similar factors).

| Case | Result |
|---|---|
| Young pulsars with planets (5–6 Myr old) | Winds fade to about 10⁻³ L☉; planets warm from about −268 °C to −170 to −230 °C |
| Millisecond pulsar at PSR B1257+12's power (2×10³⁴ erg/s) | Planets near 0.7 AU reach about 17 °C with liquid water; inner ones are 50–110 °C |

**No life around them.** Planets around neutron stars and pulsars are never counted as
potentially habitable, however temperate. They sit in a constant stream of X-rays, gamma rays
and charged particles, and only an atmosphere far thicker than Earth's could shield a surface
(Patruno & Kama 2017). Their verdict reads "Temperate, but bathed in X-rays and particles".

### In the app

- **White dwarfs:** small dots colored by temperature.
- **Neutron stars:** blue-white dots.
- **Pulsars:** cyan dots with two beams; hovering shows the wind power and whether it's a
  millisecond pulsar.
- **Black holes:** black discs in an orange glow; their caption reads "dark".
- **Habitable zones:** drawn for white dwarfs and wind-heated pulsars, not for quiet neutron
  stars or black holes. The fallback-disk bounds aren't drawn as stability limits.
- **Legend:** includes D, NS, PSR and BH.

The app has no way to enter a seed, so pulsars only appear by chance: young ones about once in
135 batches of 1000, millisecond pulsars about once in 1300.

Seeds to try with the CLI (`-s`):

| Seed | Object |
|---|---|
| 13 | White dwarf DA9 |
| 475 | White dwarf with a habitable planet around its companion |
| 86 | Neutron star |
| 345 | Neutron star with a companion |
| 14284 | Neutron star with planets |
| 3300 | Black hole |
| 54294 | Young pulsar |
| 117304 | Millisecond pulsar, wind 0.62 L☉ |
| 17131837 | Young pulsar with planets |

## Known limitations

- Main-sequence stars never get white-dwarf companions; white dwarfs only appear as primaries.
- White dwarfs are all DA or DC; helium-atmosphere (DB) and metal-polluted (DZ) types aren't distinguished.
- Pulsar-wind heating efficiency is a single, uncertain constant.

- Red-dwarf disks are too thin in the inner regions, so their habitable zones only hold Moon-mass
  bodies (see Habitability).
- Habitability ignores things the model doesn't track: tidal locking, flares from red dwarfs,
  magnetic fields, and light from companion stars.

- Sun-like and heavier stars never get brown-dwarf companions: the mass ratio's 0.1 floor keeps
  their companions above 0.075 M☉. Close brown-dwarf companions to such stars are rare in reality
  (the "brown-dwarf desert"), but wide ones exist.
- A brown dwarf's habitable zone is fixed at its current brightness; in reality it moves inward
  as the brown dwarf cools.

- Starlight from other stars isn't added to a planet's heating; each planetary system only sees its own star(s).
- Seen from the third star, a wide inner pair is drawn as one group at the outer orbit, so the
  partner's planets are reached through the primary.
- A row's focus resets to the primary if the row scrolls far out of view and is rebuilt.
- Moons are not generated (a stub in the original).
- Xcode previews crash for this project (`ContentView` and a test preview of `PlanetDetailView`)
  with a null-pointer crash inside the preview runtime. It looks like a preview problem; the app
  itself runs fine.
- Companion stars and host stars can't be clicked for details yet; only planets and belts can.

## Change history

1. Ported the C generator to Swift as a command-line tool.
2. Measured run time for 10 systems (see Performance).
3. Added the SwiftUI app target and moved the generator into `Shared/`.
4. Added all main-sequence classes (O–M), binary and triple stars, and stability-limited
   planet placement.
5. Corrected O-star luminosity and radius; fixed the legend labels.
6. Relaxed the innermost planet orbit for red dwarfs; switched to realistic class frequencies
   with matching mass ranges.
7. Click a planet or belt to see its details in an inspector panel.
8. Planets around the second and third stars when spacing allows; click a companion to expand its
   planets and collapse the primary's. The CLI report lists each star's planets.
9. Merged neighbouring planetoids into single belts (about 4× fewer belts around red dwarfs);
   updated O/B multiplicity and made triple rates depend on class.
10. Added brown dwarfs (L, T, Y), with amounts set by a mass function, age spread and cooling
    model; the faintest stars are now early L; the axis now reaches 0.001 AU; belts are drawn as bands.
11. Added habitability: Earth Similarity Index, a potentially-habitable test, sorting by
    habitability, green rings, a verdict in the details panel, and ESI in the CLI report.
12. Added neutron stars, pulsars and black holes at Galaxy-wide rates, with remnant physics,
    rare fallback-disk planets around neutron stars, and their own drawings in the app.
13. Added white dwarfs (mass–radius relation, Mestel cooling, DA/DC classes, engulfed inner
    planets), millisecond pulsars, and pulsar-wind heating of planets; radiation rules out
    habitability around neutron stars.
14. Fixed a build error in `PlanetDetailView`: the moons list now uses `ForEach` instead of a
    `for` loop inside the view builder.
