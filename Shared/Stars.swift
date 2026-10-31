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
        let lum = luminosity(mass)
        // Mass–radius relation; R ∝ M^0.8 below one solar mass, M^0.65 above.
        let radius = mass < 1.0 ? pow(mass, 0.8) : pow(mass, 0.65)
        let temperature = 5778.0 * pow(lum / (radius * radius), 0.25)
        let spectralClass = SpectralClass(temperature: temperature)
        let range = spectralClass.temperatureRange
        let fraction = (range.upperBound - temperature) / (range.upperBound - range.lowerBound)
        let subclass = min(max(Int(fraction * 10.0), 0), 9)
        return Star(mass: mass, luminosity: lum, radius: radius, temperature: temperature,
                    spectralClass: spectralClass, subclass: subclass)
    }

    /// Picks a spectral class by weight, then a mass log-uniformly within it.
    func randomPrimary() -> Star {
        let total = SpectralClass.allCases.reduce(0.0) { $0 + $1.weight }
        var pick = randomNumber(0.0, total)
        var chosen = SpectralClass.M
        for spectralClass in SpectralClass.allCases {
            pick -= spectralClass.weight
            if pick <= 0.0 { chosen = spectralClass; break }
        }
        let range = chosen.massRange
        let mass = exp(randomNumber(log(range.lowerBound), log(range.upperBound)))
        return mainSequenceStar(mass: mass)
    }

    /// Companion mass from a flat mass-ratio distribution, q = 0.1 ... 1.
    func randomCompanionStar(primaryMass: Double) -> Star {
        mainSequenceStar(mass: max(primaryMass * randomNumber(0.1, 1.0), 0.08))
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
    func randomCompanions(for primary: Star) -> [Companion] {
        guard randomNumber(0.0, 1.0) < primary.spectralClass.multiplicity else { return [] }

        let partner = randomCompanionStar(primaryMass: primary.mass)
        let innerMass = primary.mass + partner.mass
        let minimum = contactLimit(primary, partner)
        guard let inner = randomOrbit(totalMass: innerMass, spectralClass: primary.spectralClass,
                                      isAcceptable: { a, e in a * (1.0 - e) > minimum }) else { return [] }
        var companions = [Companion(star: partner, a: inner.a, e: inner.e, period: inner.period,
                                    orbitsInnerPair: false)]

        guard randomNumber(0.0, 1.0) < Const.tripleFraction else { return companions }

        // Outer star: must satisfy the Mardling & Aarseth (2001) stability criterion.
        let third = randomCompanionStar(primaryMass: primary.mass)
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
                               luminosity: primary.luminosity, innerLimit: nil, outerLimit: nil)]
        }

        func hasRoom(_ star: Star, outerLimit: Double) -> Bool {
            outerLimit > 2.0 * innermostPlanet(star.mass, luminosity: star.luminosity)
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
                              luminosity: star.luminosity, innerLimit: nil, outerLimit: outer)
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
                                      luminosity: primary.luminosity + partner.star.luminosity,
                                      innerLimit: pLimit, outerLimit: tertiaryLimit(hostMass: pairMass)))
        }

        // The outer star of a triple, perturbed by the inner pair as a whole.
        if let outer = tertiary {
            let limit = sTypeCriticalRatio(mu: pairMass / (pairMass + outer.star.mass), e: outer.e) * outer.a
            if hasRoom(outer.star, outerLimit: limit) {
                layouts.append(HostLayout(starIndices: [2], type: .circumstellar, mass: outer.star.mass,
                                          luminosity: outer.star.luminosity, innerLimit: nil, outerLimit: limit))
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
}
