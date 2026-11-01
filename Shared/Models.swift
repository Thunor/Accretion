//
//  Models.swift
//  Accretion
//
//  Ported from STRUCTS.H (planets) and ACCRETE.C (dust bands).
//

import Foundation

struct Planet {
    var a = 0.0                     // semi-major axis (AU)
    var e = 0.0                     // eccentricity
    var mass = 0.0                  // solar masses
    var isGasGiant = false
    var orbitZone = 0
    var radius = 0.0                // equatorial radius (km)
    var density = 0.0               // g/cc
    var orbitalPeriod = 0.0         // days
    var day = 0.0                   // hours
    var resonantPeriod = false
    var axialTilt = 0               // degrees
    var escapeVelocity = 0.0        // cm/sec
    var surfaceAccel = 0.0          // cm/sec2
    var surfaceGrav = 0.0           // Earth gravities
    var rmsVelocity = 0.0           // cm/sec
    var moleculeWeight = 0.0        // smallest molecular weight retained
    var volatileGasInventory = 0.0
    var surfacePressure = 0.0       // millibars
    var greenhouseEffect = false    // runaway greenhouse effect?
    var boilPoint = 0.0             // boiling point of water (K)
    var albedo = 0.0
    var surfaceTemp = 0.0           // K
    var hydrosphere = 0.0           // fraction of surface covered
    var cloudCover = 0.0            // fraction of surface covered
    var iceCover = 0.0              // fraction of surface covered
    var moons: [Planet] = []
    /// Set for a planetoid belt: the span (AU) of the small bodies merged into it.
    var beltRange: ClosedRange<Double>?
    var beltBodyCount = 0

    var isBelt: Bool { beltRange != nil }
}

struct DustBand {
    var inner: Double
    var outer: Double
    var dustPresent: Bool
    var gasPresent: Bool
}

/// Spectral classes: main-sequence stars O–M, brown dwarfs L, T and Y, then the stellar
/// remnants (neutron stars, pulsars and black holes), which have no spectral type.
enum SpectralClass: String, CaseIterable {
    case O, B, A, F, G, K, M, L, T, Y
    case whiteDwarf = "D"
    case neutronStar = "NS", pulsar = "PSR", blackHole = "BH"

    static let mainSequence: [SpectralClass] = [.O, .B, .A, .F, .G, .K, .M]
    /// Classes assigned from temperature.
    static let byTemperature: [SpectralClass] = mainSequence + [.L, .T, .Y]
    static let remnants: [SpectralClass] = [.neutronStar, .pulsar, .blackHole]

    /// L, T and Y: mostly brown dwarfs, though the very lowest-mass stars are early L.
    /// These types have no luminosity class in their designation.
    var isUltracool: Bool { self == .L || self == .T || self == .Y }

    /// Neutron stars, pulsars and black holes: no habitable zone, original planets lost.
    /// White dwarfs are remnants too, but keep their outer planets and glow like small stars.
    var isRemnant: Bool { Self.remnants.contains(self) }

    /// Display name for objects not classed by temperature.
    var remnantName: String? {
        switch self {
        case .whiteDwarf: "white dwarf"
        case .neutronStar: "neutron star"
        case .pulsar: "pulsar"
        case .blackHole: "black hole"
        default: nil
        }
    }

    /// Effective-temperature range (K) of the class.
    var temperatureRange: ClosedRange<Double> {
        switch self {
        case .O: 30_000...50_000
        case .B: 10_000...30_000
        case .A: 7_500...10_000
        case .F: 6_000...7_500
        case .G: 5_200...6_000
        case .K: 3_700...5_200
        case .M: 2_300...3_700
        case .L: 1_300...2_300
        case .T: 500...1_300
        case .Y: 200...500
        // Remnants aren't classed by temperature; these only bound what the model produces.
        case .whiteDwarf: 3.0e3...1.5e5
        case .neutronStar, .pulsar: 1.0e3...1.0e6
        case .blackHole: 0...0
        }
    }

    /// Main-sequence mass range (solar masses) a primary of this class is drawn from.
    /// The edges are where the generator's mass–luminosity and mass–radius relations
    /// cross the class's temperature boundaries, so a drawn star keeps its class.
    var massRange: ClosedRange<Double> {
        switch self {
        case .O: 17.1...60
        case .B: 2.33...17.1
        case .A: 1.47...2.33
        case .F: 1.057...1.47
        case .G: 0.839...1.057
        case .K: 0.476...0.839
        // Includes the faintest stars, which are really early L (see `mainSequenceStar`).
        case .M: Const.hydrogenBurningLimit...0.476
        // A brown dwarf's class depends on its age as well as its mass.
        case .L, .T, .Y: Const.deuteriumBurningLimit...Const.hydrogenBurningLimit
        // Measured neutron-star masses cluster near 1.4 M☉ (Özel & Freire 2016);
        // stellar black holes start around 5 M☉ (Özel et al. 2010; Gaia BH3 is 33 M☉).
        case .neutronStar, .pulsar: 1.1...2.2
        case .blackHole: 5...40
        // Peaked near 0.6 M☉ (Kepler et al. 2007), up to the Chandrasekhar limit.
        case .whiteDwarf: 0.17...1.35
        }
    }

    /// Share (%) of main-sequence stars in the solar neighbourhood (LeDrew 2001).
    /// O and B stars are rare enough that most batches of 1000 contain none or one.
    /// Brown dwarfs are drawn as a group (`Const.brownDwarfWeight`) and classed by cooling.
    var weight: Double {
        switch self {
        case .O: 0.00003
        case .B: 0.13
        case .A: 0.6
        case .F: 3.0
        case .G: 7.6
        case .K: 12.1
        case .M: 76.45
        // Drawn as groups instead: `Const.brownDwarfWeight`, `.whiteDwarfWeight`,
        // `.neutronStarWeight`, `.blackHoleWeight`.
        case .L, .T, .Y, .whiteDwarf, .neutronStar, .pulsar, .blackHole: 0
        }
    }

    /// Fraction of primaries with at least one companion. M from Winters et al. 2019,
    /// FGK from Raghavan et al. 2010, A–O from Moe & Di Stefano 2017 (as summarised by
    /// Offner et al. 2023): nearly every O star has a companion.
    var multiplicity: Double {
        switch self {
        case .O: 0.90
        case .B: 0.80
        case .A: 0.60
        case .F: 0.50
        case .G: 0.46
        case .K: 0.40
        case .M: 0.27
        // About a fifth of brown dwarfs are binaries (Burgasser et al. 2007; Fontanive et al. 2018).
        case .L, .T, .Y: 0.20
        // Supernova kicks unbind most binaries, so most remnants are single.
        case .neutronStar, .pulsar, .blackHole: 0.10
        // About a quarter of nearby white dwarfs have a companion (Holberg et al. 2016).
        case .whiteDwarf: 0.25
        }
    }

    /// Share of multiple systems that are triples rather than binaries (quadruples and
    /// higher are folded in). From the same surveys: about a fifth to a quarter for
    /// M–K dwarfs, rising steeply for massive stars.
    var tripleFraction: Double {
        switch self {
        case .O: 0.70
        case .B: 0.50
        case .A: 0.35
        case .F, .G, .K: 0.25
        case .M: 0.22
        case .L, .T, .Y, .whiteDwarf: 0.10
        case .neutronStar, .pulsar, .blackHole: 0
        }
    }

    /// Log-normal distribution of companion periods, log10(days): (mean, sigma).
    /// FGK from Raghavan et al. 2010; massive stars favour much tighter pairs (Sana et al. 2012),
    /// M dwarfs peak near 20 AU (Winters et al. 2019).
    var logPeriodDistribution: (mean: Double, sigma: Double) {
        switch self {
        case .O: (2.5, 1.8)
        case .B: (3.0, 2.0)
        case .A: (4.0, 2.3)
        case .F, .G, .K: (5.03, 2.28)
        case .M: (4.7, 2.0)
        // Brown-dwarf pairs are tight, peaking near 4 AU (Burgasser et al. 2007).
        case .L, .T, .Y: (4.0, 0.6)
        // Surviving remnant binaries span X-ray binaries to wide Gaia pairs.
        case .neutronStar, .pulsar, .blackHole: (4.0, 2.0)
        // Orbits widen as the progenitor loses mass, leaving mostly wide pairs (Sirius, Procyon).
        case .whiteDwarf: (5.0, 2.3)
        }
    }

    /// Class for an effective temperature. Classes follow temperature for stars and brown
    /// dwarfs alike, so young, hot brown dwarfs are late M, as observed.
    init(temperature: Double) {
        self = Self.byTemperature.first { temperature >= $0.temperatureRange.lowerBound } ?? .Y
    }
}

struct Star {
    var mass: Double                    // solar masses
    var luminosity: Double              // relative to the sun
    var radius: Double                  // solar radii
    var temperature: Double             // K
    var spectralClass: SpectralClass
    var subclass: Int                   // 0 (hottest) ... 9
    /// Pulsars only: rotational energy lost to the pulsar wind (relative to the sun's luminosity).
    var spinDownLuminosity = 0.0
    var isMillisecondPulsar = false

    /// Below the hydrogen-burning limit; set from mass, not spectral class.
    var isBrownDwarf: Bool { mass < Const.hydrogenBurningLimit }

    var isRemnant: Bool { spectralClass.isRemnant }
    var isWhiteDwarf: Bool { spectralClass == .whiteDwarf }

    /// What heats a planet: starlight, plus the share of a pulsar's wind a planet absorbs.
    var heatingLuminosity: Double {
        luminosity + Const.pulsarWindHeatingEfficiency * spinDownLuminosity
    }

    /// "G2V" for main-sequence stars; L, T, Y types and brown dwarfs have no luminosity
    /// class, e.g. "T6"; remnants are "NS", "PSR" or "BH". White dwarfs are "DA" (hydrogen
    /// lines) or, below 5000 K where lines vanish, "DC", with temperature index 50400 / T.
    var designation: String {
        if isWhiteDwarf {
            let index = min(max(Int((50_400 / temperature).rounded()), 1), 15)
            return (temperature >= 5_000 ? "DA" : "DC") + "\(index)"
        }
        if isRemnant { return spectralClass.rawValue }
        return "\(spectralClass.rawValue)\(subclass)" + (isBrownDwarf || spectralClass.isUltracool ? "" : "V")
    }
}

/// A companion star. Its orbit is around the primary, or, for the outer star of a
/// hierarchical triple, around the barycenter of the inner pair.
struct Companion {
    var star: Star
    var a: Double                       // semi-major axis (AU)
    var e: Double                       // eccentricity
    var period: Double                  // days
    var orbitsInnerPair: Bool

    var periastron: Double { a * (1.0 - e) }
    var apastron: Double { a * (1.0 + e) }
}

/// Where a host's planets orbit in a multiple-star system.
enum PlanetOrbitType {
    case single                         // lone star
    case circumstellar                  // S-type: around one star, inside its companion's orbit
    case circumbinary                   // P-type: around the close inner pair
}

/// A star (or close pair) and the planets that formed around it.
struct PlanetHost {
    var starIndices: [Int]              // into `StarSystem.stars`: 0 primary, 1 and 2 companions
    var orbitType: PlanetOrbitType
    var stableInnerLimit: Double?       // P-type: no stable orbits inside this (AU)
    var stableOuterLimit: Double?       // S-type / triple: no stable orbits outside this (AU)
    var mass: Double                    // solar masses (both stars if circumbinary)
    var luminosity: Double              // relative to the sun
    var ecosphereRadius: Double         // AU
    var greenhouseRadius: Double        // AU
    var planets: [Planet]
}

struct StarSystem {
    var seed: UInt64
    var primary: Star
    var companions: [Companion]
    var mainSequenceLife: Double        // years (of the primary, the shortest-lived star)
    var age: Double                     // years
    /// The primary's (or close pair's) planets first, then any companion with room for its own.
    var hosts: [PlanetHost]

    var stars: [Star] { [primary] + companions.map(\.star) }

    func stars(of host: PlanetHost) -> [Star] { host.starIndices.map { stars[$0] } }

    /// The host a star belongs to, if it has a planetary zone.
    func hostIndex(ofStar index: Int) -> Int? {
        hosts.firstIndex { $0.starIndices.contains(index) }
    }

    // The primary host, which every system has.
    var primaryHost: PlanetHost { hosts[0] }
    var orbitType: PlanetOrbitType { primaryHost.orbitType }
    var planets: [Planet] { primaryHost.planets }
    var hostStars: [Star] { stars(of: primaryHost) }
}

/// Small seedable RNG so a system can be regenerated from its seed.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
