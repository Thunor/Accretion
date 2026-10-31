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
}

struct DustBand {
    var inner: Double
    var outer: Double
    var dustPresent: Bool
    var gasPresent: Bool
}

/// Main-sequence spectral classes.
enum SpectralClass: String, CaseIterable {
    case O, B, A, F, G, K, M

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
        case .M: 0.08...0.476
        }
    }

    /// Share (%) of main-sequence stars in the solar neighbourhood (LeDrew 2001).
    /// O and B stars are rare enough that most batches of 1000 contain none or one.
    var weight: Double {
        switch self {
        case .O: 0.00003
        case .B: 0.13
        case .A: 0.6
        case .F: 3.0
        case .G: 7.6
        case .K: 12.1
        case .M: 76.45
        }
    }

    /// Fraction of primaries with at least one companion (Duchêne & Kraus 2013).
    var multiplicity: Double {
        switch self {
        case .O: 0.75
        case .B: 0.70
        case .A: 0.60
        case .F: 0.50
        case .G: 0.46
        case .K: 0.40
        case .M: 0.27
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
        }
    }

    init(temperature: Double) {
        self = Self.allCases.first { temperature >= $0.temperatureRange.lowerBound } ?? .M
    }
}

struct Star {
    var mass: Double                    // solar masses
    var luminosity: Double              // relative to the sun
    var radius: Double                  // solar radii
    var temperature: Double             // K
    var spectralClass: SpectralClass
    var subclass: Int                   // 0 (hottest) ... 9

    var designation: String { "\(spectralClass.rawValue)\(subclass)V" }
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
