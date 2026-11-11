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
    var diskScale = 1.0

    init(seed: UInt64? = nil, verbose: Bool = false) {
        let s = seed ?? UInt64.random(in: .min ... .max)
        self.seed = s
        self.rng = SplitMix64(seed: s)
        self.verbose = verbose
    }

    func generate() -> StarSystem {
        // The primary is the most massive, shortest-lived object, so it caps the age. Ages are
        // uniform up to 10 Gyr (a constant star-formation history), which also sets how far
        // each brown dwarf has cooled.
        let (primaryMass, remnantType) = randomPrimaryDraw()
        let isBrownDwarf = primaryMass < Const.hydrogenBurningLimit
        let primary: Star
        if remnantType == .whiteDwarf {
            // The white dwarf has cooled for up to 9 Gyr after a ~1 Gyr progenitor life.
            mainSeqLife = .infinity
            let coolingAge = randomNumber(0.0, 1.0) * (Const.maximumSystemAge - Const.whiteDwarfProgenitorLife)
            age = coolingAge + Const.whiteDwarfProgenitorLife
            primary = whiteDwarf(mass: primaryMass, coolingAge: coolingAge)
        } else if let remnantType {
            // A remnant's age runs from its birth in a supernova, uniform from 0 to 10 Gyr,
            // so the youngest are still pulsars.
            mainSeqLife = .infinity
            age = randomNumber(0.0, 1.0) * Const.maximumSystemAge
            primary = remnant(remnantType, mass: primaryMass, age: age)
        } else {
            mainSeqLife = isBrownDwarf ? .infinity : 1.0e10 * (primaryMass / luminosity(primaryMass))
            age = randomNumber(0.01, 1.0) * min(mainSeqLife, Const.maximumSystemAge)
            primary = star(mass: primaryMass, age: age)
        }
        let companions = randomCompanions(for: primary, age: age)

        let allStars = [primary] + companions.map(\.star)
        let hosts = planetHostLayouts(primary: primary, companions: companions)
            .map { limitRemnantDisks($0, stars: $0.starIndices.map { allStars[$0] }) }
            .map(makeHost)
        return StarSystem(seed: seed,
                          primary: primary,
                          companions: companions,
                          mainSequenceLife: mainSeqLife,
                          age: age,
                          hosts: hosts)
    }

    /// Remnants lose their original planets in the supernova. A neutron star occasionally
    /// grows new ones from a fallback disk within ~1 AU; a black hole gets none.
    func limitRemnantDisks(_ layout: HostLayout, stars: [Star]) -> HostLayout {
        var limited = layout
        if stars.contains(where: \.isWhiteDwarf) {
            // Inner planets were engulfed during the giant phases; outer ones survive.
            limited.diskRange = Const.whiteDwarfClearedRadius...Double.infinity
            return limited
        }
        guard stars.contains(where: \.isRemnant) else { return layout }
        let hasDisk = !stars.contains(where: { $0.spectralClass == .blackHole })
            && randomNumber(0.0, 1.0) < Const.neutronStarPlanetChance
        limited.diskRange = hasDisk ? Const.fallbackDiskRange : 0...0
        return limited
    }

    /// Accretes and finishes the planets of one host. The generator's stellar state is
    /// switched to that host first, since the accretion and environment code reads it.
    func makeHost(_ layout: HostLayout) -> PlanetHost {
        stellarMassRatio = layout.mass
        stellarLuminosityRatio = layout.luminosity
        rEcosphere = sqrt(stellarLuminosityRatio)
        rGreenhouse = rEcosphere * Const.greenhouseEffectConst
        diskScale = diskScale(mass: stellarMassRatio, luminosity: stellarLuminosityRatio)

        // Clear the disk inside a circumbinary stability limit and truncate it outside
        // a companion's, so planets only form on stable orbits.
        let disk = layout.diskRange ?? 0.0...Double.infinity
        let innerLimit = max(layout.innerLimit ?? 0.0, disk.lowerBound)
        let outerLimit = min(layout.outerLimit ?? .infinity, disk.upperBound)
        let bodies = distributePlanetaryMasses(
            innerDust: innerLimit,
            outerDust: min(stellarDustLimit(stellarMassRatio), outerLimit),
            innerBound: max(innermostPlanet(stellarMassRatio, luminosity: stellarLuminosityRatio), innerLimit),
            outerBound: min(outermostPlanet(stellarMassRatio), outerLimit))

        let finished = mergeBelts(bodies).map { planet -> Planet in
            var p = planet
            computeEnvironment(&p)
            p.moons = distributeMoonMasses(for: p, stellarMass: stellarMassRatio)
            return p
        }
        return PlanetHost(starIndices: layout.starIndices,
                          orbitType: layout.type,
                          stableInnerLimit: layout.innerLimit,
                          stableOuterLimit: layout.outerLimit,
                          mass: stellarMassRatio,
                          luminosity: stellarLuminosityRatio,
                          ecosphereRadius: rEcosphere,
                          greenhouseRadius: rGreenhouse,
                          planets: finished)
    }

    /// Dole's accretion leaves runs of small neighbouring lumps where dust is thin. Each run
    /// of planetoids (rocky, under `Const.beltMassLimit`) becomes one belt with their total
    /// mass at their mass-weighted distance.
    func mergeBelts(_ bodies: [Planet]) -> [Planet] {
        func isPlanetoid(_ p: Planet) -> Bool {
            !p.isGasGiant && p.mass * Const.earthMassesPerSolarMass < Const.beltMassLimit
        }
        var result: [Planet] = []
        var run: [Planet] = []
        func flushRun() {
            guard let first = run.first, let last = run.last else { return }
            let mass = run.reduce(0.0) { $0 + $1.mass }
            var belt = first
            belt.mass = mass
            belt.a = run.reduce(0.0) { $0 + $1.a * $1.mass } / mass
            belt.e = run.reduce(0.0) { $0 + $1.e * $1.mass } / mass
            belt.beltRange = first.a...last.a
            belt.beltBodyCount = run.count
            result.append(belt)
            run = []
        }
        for body in bodies.sorted(by: { $0.a < $1.a }) {
            if isPlanetoid(body) {
                run.append(body)
            } else {
                flushRun()
                result.append(body)
            }
        }
        flushRun()
        return result
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
