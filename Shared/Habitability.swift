//
//  Habitability.swift
//  Accretion
//
//  How Earth-like a planet is, and whether it could support life as we know it.
//

import Foundation

enum Habitability {
    // Earth Similarity Index (Schulze-Makuch et al. 2011): Earth's values and each
    // property's weight. Temperature dominates, then density, escape velocity and radius.
    static let earthRadius = 6378.0                 // km
    static let earthDensity = 5.51                  // g/cc
    static let earthEscapeVelocity = 11.19          // km/s
    static let earthSurfaceTemperature = 288.0      // K
    static let weights = (radius: 0.57, density: 1.07, escapeVelocity: 0.70, temperature: 5.58)

    // "Life as we know it" needs liquid surface water and conditions most Earth life tolerates.
    static let temperatureRange = 273.0...323.0     // K: 0–50 °C
    static let pressureRange = 0.1...10.0           // atmospheres
    static let massRange = 0.1...10.0               // Earth masses: keeps an atmosphere, not a mini-Neptune
    /// Earth had life within ~0.7 Gyr of forming; younger systems are given no chance yet.
    static let minimumAge = 5.0e8                   // years

    /// ESI factor for one property: 1 when equal to Earth's, falling toward 0.
    static func similarity(_ value: Double, _ earth: Double, weight: Double) -> Double {
        pow(1.0 - abs(value - earth) / (value + earth), weight / 4.0)
    }
}

extension Planet {
    /// A solid surface: not a gas giant or a planetoid belt.
    var isRocky: Bool { !isGasGiant && !isBelt }

    /// Earth Similarity Index, 0 ... 1 (Earth is 1). Zero for gas giants and belts.
    var earthSimilarity: Double {
        guard isRocky, radius > 0, density > 0 else { return 0 }
        let w = Habitability.weights
        return Habitability.similarity(radius, Habitability.earthRadius, weight: w.radius)
            * Habitability.similarity(density, Habitability.earthDensity, weight: w.density)
            * Habitability.similarity(escapeVelocity / Const.cmPerKM, Habitability.earthEscapeVelocity,
                                      weight: w.escapeVelocity)
            * Habitability.similarity(surfaceTemp, Habitability.earthSurfaceTemperature,
                                      weight: w.temperature)
    }

    /// The environment model only leaves water on the surface when it is between
    /// freezing and boiling at the surface pressure.
    var hasLiquidWater: Bool {
        isRocky && hydrosphere > 0 && !(greenhouseEffect && surfacePressure > 0)
    }

    /// Liquid water plus temperature, pressure and mass that Earth-like life tolerates,
    /// in a system old enough for life to have started.
    func isPotentiallyHabitable(systemAge: Double) -> Bool {
        hasLiquidWater
            && Habitability.temperatureRange.contains(surfaceTemp)
            && Habitability.pressureRange.contains(surfacePressure / Const.earthSurfPresInMillibars)
            && Habitability.massRange.contains(mass * Const.earthMassesPerSolarMass)
            && systemAge >= Habitability.minimumAge
    }
}

/// The most promising planet in a system.
struct HabitabilityCandidate {
    let host: Int
    let index: Int
    let earthSimilarity: Double
    let isPotentiallyHabitable: Bool

    /// Sort key: potentially habitable planets first, then by Earth similarity.
    var score: Double { (isPotentiallyHabitable ? 1.0 : 0.0) + earthSimilarity }
}

extension StarSystem {
    /// Planets around neutron stars and pulsars (or black holes) sit in a constant stream of
    /// X-rays, gamma rays and charged particles; only an atmosphere far thicker than Earth's
    /// could shield a surface (Patruno & Kama 2017), so they aren't habitable as we know it.
    func hasIonizingHost(_ host: PlanetHost) -> Bool {
        stars(of: host).contains(where: \.isRemnant)
    }

    func isPotentiallyHabitable(_ planet: Planet, in host: PlanetHost) -> Bool {
        !hasIonizingHost(host) && planet.isPotentiallyHabitable(systemAge: age)
    }

    /// The best planet around any of the system's stars, if it has a rocky planet.
    var bestHabitabilityCandidate: HabitabilityCandidate? {
        var best: HabitabilityCandidate?
        for (hostIndex, host) in hosts.enumerated() {
            for (index, planet) in host.planets.enumerated() where planet.isRocky {
                let candidate = HabitabilityCandidate(host: hostIndex, index: index,
                                                      earthSimilarity: planet.earthSimilarity,
                                                      isPotentiallyHabitable: isPotentiallyHabitable(planet, in: host))
                if candidate.score > best?.score ?? -1 { best = candidate }
            }
        }
        return best
    }
}
