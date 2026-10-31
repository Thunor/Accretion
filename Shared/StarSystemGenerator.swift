//
//  StarSystemGenerator.swift
//  Accretion
//
//  Ported from MAIN.C and UTILS.C. The C globals live here as properties.
//

import Foundation

final class StarSystemGenerator {
    let seed: UInt64
    var verbose: Bool
    var rng: SplitMix64

    // Star
    var stellarMassRatio = 0.0
    var stellarLuminosityRatio = 0.0
    var mainSeqLife = 0.0
    var age = 0.0
    var rEcosphere = 0.0
    var rGreenhouse = 0.0
    let radiansPerRotation = 2.0 * Double.pi

    // Accretion state
    var dustBands: [DustBand] = []
    var planets: [Planet] = []
    var dustLeft = false
    var rInner = 0.0
    var rOuter = 0.0
    var reducedMass = 0.0
    var dustDensity = 0.0
    var cloudEccentricity = 0.2

    init(seed: UInt64? = nil, verbose: Bool = false) {
        let s = seed ?? UInt64.random(in: .min ... .max)
        self.seed = s
        self.rng = SplitMix64(seed: s)
        self.verbose = verbose
    }

    func generate() -> StarSystem {
        let primary = randomPrimary()
        let companions = randomCompanions(for: primary)
        let layout = planetLayout(primary: primary, companions: companions)
        stellarMassRatio = layout.hostMass
        stellarLuminosityRatio = layout.hostLuminosity

        // Clear the disk inside a circumbinary stability limit and truncate it outside
        // a companion's, so planets only form on stable orbits.
        let innerLimit = layout.innerLimit ?? 0.0
        let outerLimit = layout.outerLimit ?? .infinity
        let bodies = distributePlanetaryMasses(
            innerDust: innerLimit,
            outerDust: min(stellarDustLimit(stellarMassRatio), outerLimit),
            innerBound: max(innermostPlanet(stellarMassRatio, luminosity: stellarLuminosityRatio), innerLimit),
            outerBound: min(outermostPlanet(stellarMassRatio), outerLimit))

        // The primary is the most massive, shortest-lived star, so it sets the age.
        mainSeqLife = 1.0e10 * (primary.mass / primary.luminosity)
        age = mainSeqLife >= 6.0e9 ? randomNumber(1.0e9, 6.0e9)
            : randomNumber(min(1.0e9, 0.1 * mainSeqLife), mainSeqLife)
        rEcosphere = sqrt(stellarLuminosityRatio)
        rGreenhouse = rEcosphere * Const.greenhouseEffectConst

        let finished = bodies.map { planet -> Planet in
            var p = planet
            computeEnvironment(&p)
            return p
        }

        return StarSystem(seed: seed,
                          primary: primary,
                          companions: companions,
                          orbitType: layout.type,
                          stableInnerLimit: layout.innerLimit,
                          stableOuterLimit: layout.outerLimit,
                          stellarMass: stellarMassRatio,
                          stellarLuminosity: stellarLuminosityRatio,
                          mainSequenceLife: mainSeqLife,
                          age: age,
                          ecosphereRadius: rEcosphere,
                          greenhouseRadius: rGreenhouse,
                          planets: finished)
    }

    func computeEnvironment(_ p: inout Planet) {
        p.orbitZone = orbitalZone(p.a)
        if p.isGasGiant {
            p.density = empiricalDensity(p.mass, p.a, p.isGasGiant)
            p.radius = volumeRadius(p.mass, p.density)
        } else {
            p.radius = kothariRadius(p.mass, p.a, p.isGasGiant, p.orbitZone)
            p.density = volumeDensity(p.mass, p.radius)
        }
        p.orbitalPeriod = period(p.a, p.mass, stellarMassRatio)
        let (day, resonant) = dayLength(p.mass, p.radius, p.orbitalPeriod, p.e, p.isGasGiant)
        p.day = day
        p.resonantPeriod = resonant
        p.axialTilt = inclination(p.a)
        p.escapeVelocity = escapeVel(p.mass, p.radius)
        p.surfaceAccel = acceleration(p.mass, p.radius)
        p.rmsVelocity = rmsVel(MolecularWeight.molecularNitrogen, p.a)
        p.moleculeWeight = moleculeLimit(p.a, p.mass, p.radius)

        if p.isGasGiant {
            p.surfaceGrav = Const.incrediblyLargeNumber
            p.greenhouseEffect = false
            p.volatileGasInventory = Const.incrediblyLargeNumber
            p.surfacePressure = Const.incrediblyLargeNumber
            p.boilPoint = Const.incrediblyLargeNumber
            p.hydrosphere = Const.incrediblyLargeNumber
            p.albedo = about(Const.gasGiantAlbedo, 0.1)
            p.surfaceTemp = Const.incrediblyLargeNumber
        } else {
            p.surfaceGrav = gravity(p.surfaceAccel)
            p.greenhouseEffect = greenhouse(p.orbitZone, p.a, rGreenhouse)
            p.volatileGasInventory = volInventory(p.mass, p.escapeVelocity, p.rmsVelocity,
                                                  stellarMassRatio, p.orbitZone, p.greenhouseEffect)
            p.surfacePressure = pressure(p.volatileGasInventory, p.radius, p.surfaceGrav)
            p.boilPoint = p.surfacePressure == 0.0 ? 0.0 : boilingPoint(p.surfacePressure)
            iterateSurfaceTemp(&p)
        }
    }

    // MARK: - UTILS.C

    /// Random real number between the inner and outer bounds.
    func randomNumber(_ inner: Double, _ outer: Double) -> Double {
        Double.random(in: 0.0...1.0, using: &rng) * (outer - inner) + inner
    }

    /// A value within a certain variation of the exact value given.
    func about(_ value: Double, _ variation: Double) -> Double {
        value + value * randomNumber(-variation, variation)
    }

    func randomEccentricity() -> Double {
        1.0 - pow(randomNumber(0.0, 1.0), Const.eccentricityCoeff)
    }

    func trace(_ message: @autoclosure () -> String) {
        if verbose { print(message()) }
    }
}
