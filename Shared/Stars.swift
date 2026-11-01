//
//  Stars.swift
//  Accretion
//
//  Main-sequence stars, companion orbits and the dynamical stability limits
//  that decide where planets may form in multiple-star systems.
//

import Foundation

extension StarSystemGenerator {

    // MARK: - Stars

    /// A main-sequence star of the given mass.
    func mainSequenceStar(mass: Double) -> Star {
        var lum = luminosity(mass)
        // Mass–radius relation; R ∝ M^0.8 below one solar mass, M^0.65 above.
        var radius = mass < 1.0 ? pow(mass, 0.8) : pow(mass, 0.65)
        // The power laws are too bright and large at the very bottom. Below 0.1 M☉ blend
        // toward the faintest star at the hydrogen-burning limit: 2075 K, 0.086 R☉, type L2
        // (Dieterich et al. 2014), so the lowest-mass stars are early L dwarfs.
        if mass < 0.1 {
            let f = max(mass - Const.hydrogenBurningLimit, 0) / (0.1 - Const.hydrogenBurningLimit)
            let edgeRadius = 0.086
            let edgeLuminosity = pow(edgeRadius, 2.0) * pow(2075.0 / 5778.0, 4.0)
            lum = exp(log(edgeLuminosity) + f * (log(luminosity(0.1)) - log(edgeLuminosity)))
            radius = edgeRadius + f * (pow(0.1, 0.8) - edgeRadius)
        }
        let temperature = 5778.0 * pow(lum / (radius * radius), 0.25)
        return Star(mass: mass, luminosity: lum, radius: radius, temperature: temperature,
                    spectralClass: SpectralClass(temperature: temperature),
                    subclass: subclass(temperature))
    }

    /// 0 at the hot edge of the temperature's class, 9 at the cool edge.
    func subclass(_ temperature: Double) -> Int {
        let range = SpectralClass(temperature: temperature).temperatureRange
        let fraction = (range.upperBound - temperature) / (range.upperBound - range.lowerBound)
        return min(max(Int(fraction * 10.0), 0), 9)
    }

    /// A brown dwarf of the given mass and age (years). Brown dwarfs never stabilise; they
    /// cool and fade forever, so temperature and luminosity follow the Burrows et al. (2001)
    /// fits, and the radius follows from L = R²T⁴.
    func brownDwarf(mass: Double, age: Double) -> Star {
        let gigayears = max(age, 1.0e7) / 1.0e9
        let massRatio = mass / 0.05
        // The fits overshoot for the youngest, heaviest objects; real ones top out near 2700 K.
        let temperature = min(1550.0 * pow(gigayears, -0.32) * pow(massRatio, 0.83), 2700.0)
        let lum = 4.0e-5 * pow(gigayears, -1.3) * pow(massRatio, 2.64)
        let radius = sqrt(lum) / pow(temperature / 5778.0, 2.0)
        return Star(mass: mass, luminosity: lum, radius: radius, temperature: temperature,
                    spectralClass: SpectralClass(temperature: temperature),
                    subclass: subclass(temperature))
    }

    /// A star or brown dwarf, depending on whether it can burn hydrogen.
    func star(mass: Double, age: Double) -> Star {
        mass < Const.hydrogenBurningLimit ? brownDwarf(mass: mass, age: age) : mainSequenceStar(mass: mass)
    }

    /// The primary's mass, and its remnant type if it is a neutron star or black hole.
    /// A group is picked by weight (main-sequence classes, brown dwarfs, neutron stars,
    /// black holes), then a mass from that group's distribution.
    func randomPrimaryDraw() -> (mass: Double, remnant: SpectralClass?) {
        let total = SpectralClass.allCases.reduce(0.0) { $0 + $1.weight } + Const.brownDwarfWeight
            + Const.whiteDwarfWeight + Const.neutronStarWeight + Const.blackHoleWeight
        var pick = randomNumber(0.0, total)
        for spectralClass in SpectralClass.mainSequence {
            pick -= spectralClass.weight
            if pick <= 0.0 {
                let range = spectralClass.massRange
                return (exp(randomNumber(log(range.lowerBound), log(range.upperBound))), nil)
            }
        }
        pick -= Const.whiteDwarfWeight
        if pick <= 0.0 {
            // White-dwarf masses: sharply peaked near 0.6 M☉.
            let range = SpectralClass.whiteDwarf.massRange
            return (min(max(0.6 + 0.13 * gaussian(), range.lowerBound), range.upperBound), .whiteDwarf)
        }
        pick -= Const.neutronStarWeight
        if pick <= 0.0 {
            // Neutron-star masses: roughly normal around 1.4 M☉.
            let range = SpectralClass.neutronStar.massRange
            return (min(max(1.4 + 0.15 * gaussian(), range.lowerBound), range.upperBound), .neutronStar)
        }
        pick -= Const.blackHoleWeight
        if pick <= 0.0 {
            // Black-hole masses: an exponential tail above ~6.3 M☉ (Özel et al. 2010).
            let range = SpectralClass.blackHole.massRange
            let mass = 6.32 - 1.57 * log(max(randomNumber(0.0, 1.0), 1e-12))
            return (min(mass, range.upperBound), .blackHole)
        }
        // Brown dwarfs: inverse transform sampling of dN/dM ∝ M^-α between the burning limits.
        let k = 1.0 - Const.brownDwarfMassFunctionSlope
        let lo = pow(Const.deuteriumBurningLimit, k), hi = pow(Const.hydrogenBurningLimit, k)
        return (pow(randomNumber(lo, hi), 1.0 / k), nil)
    }

    /// A neutron star (a pulsar while younger than `Const.pulsarLifetime`) or a black hole.
    /// Neutron stars cool from ~10⁶ K; this rough cooling curve gives ~10⁴ K after 10 Gyr.
    /// Black holes emit nothing of their own.
    func remnant(_ type: SpectralClass, mass: Double, age: Double) -> Star {
        if type == .blackHole {
            let radius = Const.schwarzschildRadiusPerSolarMass * mass / Const.solarRadiusInKM
            return Star(mass: mass, luminosity: Const.minimumLuminosity, radius: radius,
                        temperature: 0, spectralClass: .blackHole, subclass: 0)
        }
        let temperature = 1.0e6 * pow(max(age, 1.0e5) / 1.0e5, -0.4)
        let radius = Const.neutronStarRadius / Const.solarRadiusInKM
        let lum = max(radius * radius * pow(temperature / 5778.0, 4.0), Const.minimumLuminosity)
        var star = Star(mass: mass, luminosity: lum, radius: radius, temperature: temperature,
                        spectralClass: .neutronStar, subclass: 0)
        if age < Const.pulsarLifetime {
            // Young pulsar: magnetic-dipole spin-down from its birth spin.
            star.spectralClass = .pulsar
            let spinDown = Const.pulsarInitialSpinDown / pow(1.0 + age / Const.pulsarSpinDownTimescale, 2.0)
            star.spinDownLuminosity = spinDown / Const.solarLuminosityInErgs
        } else if randomNumber(0.0, 1.0) < Const.millisecondPulsarFraction {
            // Old neutron star spun back up by a companion: a millisecond pulsar, spread
            // over about a decade around 10³⁴ erg/s.
            star.spectralClass = .pulsar
            star.isMillisecondPulsar = true
            let spinDown = Const.millisecondPulsarSpinDown * pow(10.0, 0.5 * gaussian())
            star.spinDownLuminosity = spinDown / Const.solarLuminosityInErgs
        }
        return star
    }

    /// A white dwarf of the given mass, cooled for `coolingAge` years.
    /// Radius from Nauenberg's (1972) mass–radius relation; luminosity from Mestel's
    /// cooling law, L ≈ M (8.8 Myr / t)^1.4 L☉, for a carbon core.
    func whiteDwarf(mass: Double, coolingAge: Double) -> Star {
        let x = mass / Const.chandrasekharMass
        let radius = 0.0114 * sqrt(max(pow(x, -2.0 / 3.0) - pow(x, 2.0 / 3.0), 1e-4))
        var lum = mass * pow(8.8e6 / max(coolingAge, 1.0e6), 1.4)
        var temperature = 5778.0 * pow(lum / (radius * radius), 0.25)
        // Mestel's law over-cools light, helium-core white dwarfs; the coolest observed in the
        // disk are ~3500–4000 K, so floor the temperature there.
        if temperature < Const.whiteDwarfMinimumTemperature {
            temperature = Const.whiteDwarfMinimumTemperature
            lum = radius * radius * pow(temperature / 5778.0, 4.0)
        }
        return Star(mass: mass, luminosity: lum, radius: radius, temperature: temperature,
                    spectralClass: .whiteDwarf, subclass: 0)
    }

    /// Companion mass from a flat mass-ratio distribution, q = 0.1 ... 1, so low-mass stars
    /// can have brown-dwarf companions. Brown-dwarf pairs favour near-equal masses (q = 0.5 ... 1).
    func randomCompanionStar(primary: Star, age: Double) -> Star {
        let q = primary.isBrownDwarf ? randomNumber(0.5, 1.0) : randomNumber(0.1, 1.0)
        var mass = max(primary.mass * q, Const.deuteriumBurningLimit)
        // A remnant's companion has outlived the remnant's massive progenitor, so it is a
        // long-lived low-mass star, as in low-mass X-ray binaries and the Gaia black holes.
        if primary.isRemnant { mass = min(mass, 1.0) }
        if primary.isWhiteDwarf {
            // Relative to the ~2 M☉ progenitor, and still on the main sequence at this age,
            // like Sirius A and Procyon A beside their white dwarfs.
            mass = max(2.0 * q, Const.deuteriumBurningLimit)
            while mass >= Const.hydrogenBurningLimit, 1.0e10 * mass / luminosity(mass) < age {
                mass *= 0.9
            }
        }
        return star(mass: mass, age: age)
    }

    // MARK: - Companion orbits

    /// Standard normal deviate (Box–Muller).
    func gaussian() -> Double {
        let u1 = max(randomNumber(0.0, 1.0), 1e-12)
        let u2 = randomNumber(0.0, 1.0)
        return sqrt(-2.0 * log(u1)) * cos(2.0 * Double.pi * u2)
    }

    /// Draws an orbit from the class's log-normal period distribution until it is
    /// accepted. Pairs tighter than 12 days are tidally circularized.
    func randomOrbit(totalMass: Double, spectralClass: SpectralClass,
                     isAcceptable: (_ a: Double, _ e: Double) -> Bool) -> (a: Double, e: Double, period: Double)? {
        let (mean, sigma) = spectralClass.logPeriodDistribution
        for _ in 0..<200 {
            let logPeriod = min(max(mean + sigma * gaussian(), 0.0), 9.0)
            let days = pow(10.0, logPeriod)
            let years = days / Const.daysInAYear
            let a = pow(totalMass * years * years, 1.0 / 3.0)
            let e = days < 12.0 ? 0.0 : randomNumber(0.0, days < 1000.0 ? 0.6 : 0.8)
            if isAcceptable(a, e) { return (a, e, days) }
        }
        return nil
    }

    /// Stars closer than this at periastron would be in contact (AU).
    func contactLimit(_ s1: Star, _ s2: Star) -> Double {
        3.0 * (s1.radius + s2.radius) * Const.solarRadiusInAU
    }

    /// Companions of the primary: none, a binary partner, or a binary partner plus an
    /// outer star orbiting the pair (a hierarchical triple).
    func randomCompanions(for primary: Star, age: Double) -> [Companion] {
        guard randomNumber(0.0, 1.0) < primary.spectralClass.multiplicity else { return [] }

        let partner = randomCompanionStar(primary: primary, age: age)
        let innerMass = primary.mass + partner.mass
        let minimum = contactLimit(primary, partner)
        guard let inner = randomOrbit(totalMass: innerMass, spectralClass: primary.spectralClass,
                                      isAcceptable: { a, e in a * (1.0 - e) > minimum }) else { return [] }
        var companions = [Companion(star: partner, a: inner.a, e: inner.e, period: inner.period,
                                    orbitsInnerPair: false)]

        guard randomNumber(0.0, 1.0) < primary.spectralClass.tripleFraction else { return companions }

        // Outer star: must satisfy the Mardling & Aarseth (2001) stability criterion.
        let third = randomCompanionStar(primary: primary, age: age)
        let qOut = third.mass / innerMass
        if let outer = randomOrbit(totalMass: innerMass + third.mass, spectralClass: primary.spectralClass,
                                   isAcceptable: { a, e in
                                       a * (1.0 - e) > tripleStabilityLimit(innerA: inner.a, qOut: qOut, eOut: e)
                                   }) {
            companions.append(Companion(star: third, a: outer.a, e: outer.e, period: outer.period,
                                        orbitsInnerPair: true))
        }
        return companions
    }

    // MARK: - Stability

    /// Holman & Wiegert (1999): largest stable planetary orbit around one star of a binary,
    /// as a fraction of the binary separation. μ is the companion's share of the total mass.
    func sTypeCriticalRatio(mu: Double, e: Double) -> Double {
        let mu = min(max(mu, 0.1), 0.9), e = min(e, 0.8)
        return 0.464 - 0.380 * mu - 0.631 * e + 0.586 * mu * e + 0.150 * e * e - 0.198 * mu * e * e
    }

    /// Holman & Wiegert (1999): smallest stable circumbinary orbit, as a fraction of the
    /// binary separation.
    func pTypeCriticalRatio(mu: Double, e: Double) -> Double {
        let mu = min(max(mu, 0.1), 0.5), e = min(e, 0.8)
        return 1.60 + 5.10 * e - 2.22 * e * e + 4.12 * mu - 4.27 * e * mu
            - 5.09 * mu * mu + 4.61 * e * e * mu * mu
    }

    /// Mardling & Aarseth (2001): smallest stable outer periastron of a hierarchical triple.
    func tripleStabilityLimit(innerA: Double, qOut: Double, eOut: Double) -> Double {
        2.8 * pow(1.0 + qOut, 0.4) * pow(1.0 + eOut, 0.4) * pow(1.0 - eOut, -0.2) * innerA
    }

    /// Decides which stars can host planets and the stable band around each. The primary
    /// (or close pair) always comes first; companions are added only when the other stars
    /// leave them a zone wider than twice their innermost planet orbit.
    func planetHostLayouts(primary: Star, companions: [Companion]) -> [HostLayout] {
        guard let partner = companions.first else {
            return [HostLayout(starIndices: [0], type: .single, mass: primary.mass,
                               luminosity: primary.heatingLuminosity, innerLimit: nil, outerLimit: nil)]
        }

        func hasRoom(_ star: Star, outerLimit: Double) -> Bool {
            outerLimit > 2.0 * innermostPlanet(star.mass, luminosity: star.heatingLuminosity)
        }

        let pairMass = primary.mass + partner.star.mass
        let tertiary = companions.dropFirst().first
        // A tertiary orbits the pair's barycenter; treat it as perturbing a host from there.
        func tertiaryLimit(hostMass: Double) -> Double? {
            guard let outer = tertiary else { return nil }
            return sTypeCriticalRatio(mu: outer.star.mass / (hostMass + outer.star.mass), e: outer.e) * outer.a
        }
        // One star of the inner pair, perturbed by the other (and by any tertiary).
        func circumstellar(_ index: Int, _ star: Star, perturberMass: Double) -> HostLayout {
            let sLimit = sTypeCriticalRatio(mu: perturberMass / pairMass, e: partner.e) * partner.a
            let outer = [sLimit, tertiaryLimit(hostMass: star.mass)].compactMap { $0 }.min()
            return HostLayout(starIndices: [index], type: .circumstellar, mass: star.mass,
                              luminosity: star.heatingLuminosity, innerLimit: nil, outerLimit: outer)
        }

        var layouts: [HostLayout] = []
        let primaryZone = circumstellar(0, primary, perturberMass: partner.star.mass)
        if hasRoom(primary, outerLimit: primaryZone.outerLimit ?? .infinity) {
            // Wide pair: each star may keep its own planets.
            layouts.append(primaryZone)
            let partnerZone = circumstellar(1, partner.star, perturberMass: primary.mass)
            if hasRoom(partner.star, outerLimit: partnerZone.outerLimit ?? .infinity) {
                layouts.append(partnerZone)
            }
        } else {
            // Close pair: planets orbit both stars.
            let pLimit = pTypeCriticalRatio(mu: partner.star.mass / pairMass, e: partner.e) * partner.a
            layouts.append(HostLayout(starIndices: [0, 1], type: .circumbinary, mass: pairMass,
                                      luminosity: primary.heatingLuminosity + partner.star.heatingLuminosity,
                                      innerLimit: pLimit, outerLimit: tertiaryLimit(hostMass: pairMass)))
        }

        // The outer star of a triple, perturbed by the inner pair as a whole.
        if let outer = tertiary {
            let limit = sTypeCriticalRatio(mu: pairMass / (pairMass + outer.star.mass), e: outer.e) * outer.a
            if hasRoom(outer.star, outerLimit: limit) {
                layouts.append(HostLayout(starIndices: [2], type: .circumstellar, mass: outer.star.mass,
                                          luminosity: outer.star.heatingLuminosity, innerLimit: nil, outerLimit: limit))
            }
        }
        return layouts
    }
}

/// A star (or close pair) that may host planets, and its band of stable orbits.
struct HostLayout {
    var starIndices: [Int]
    var type: PlanetOrbitType
    var mass: Double
    var luminosity: Double
    var innerLimit: Double?
    var outerLimit: Double?
    /// Where a disk exists at all, independent of stability; nil means the usual disk.
    /// Remnants have a small fallback disk or none.
    var diskRange: ClosedRange<Double>?
}
