//
//  Accrete.swift
//  Accretion
//
//  Ported from ACCRETE.C.
//  Dole, Stephen H. "Formation of Planetary Systems by Aggregation:
//  a Computer Simulation", October 1969, Rand Corporation Paper P-4226.
//

import Foundation

extension StarSystemGenerator {

    func setInitialConditions(innerDust: Double, outerDust: Double) {
        dustBands = [DustBand(inner: innerDust, outer: outerDust, dustPresent: true, gasPresent: true)]
        planets = []
        dustLeft = true
        cloudEccentricity = 0.2
    }

    func stellarDustLimit(_ stellarMass: Double) -> Double { 200.0 * pow(stellarMass, 1.0 / 3.0) }
    /// Dole's 0.3·M^⅓ AU, but never farther out than 0.5·√L AU. The luminosity term only bites
    /// below ~0.75 solar masses, letting red dwarfs host close-in planets in and around their
    /// habitable zones as observed (TRAPPIST-1, Proxima Centauri).
    func innermostPlanet(_ stellarMass: Double, luminosity: Double) -> Double {
        min(0.3 * pow(stellarMass, 1.0 / 3.0), 0.5 * sqrt(luminosity))
    }
    func outermostPlanet(_ stellarMass: Double) -> Double { 50.0 * pow(stellarMass, 1.0 / 3.0) }

    func innerEffectLimit(_ a: Double, _ e: Double, _ mass: Double) -> Double {
        a * (1.0 - e) * (1.0 - mass) / (1.0 + cloudEccentricity)
    }

    /// As in the original, this uses the current `reducedMass`, not `mass`.
    func outerEffectLimit(_ a: Double, _ e: Double, _ mass: Double) -> Double {
        a * (1.0 + e) * (1.0 + reducedMass) / (1.0 - cloudEccentricity)
    }

    func dustAvailable(_ insideRange: Double, _ outsideRange: Double) -> Bool {
        var i = 0
        while i < dustBands.count && dustBands[i].outer < insideRange { i += 1 }
        var dustHere = i < dustBands.count ? dustBands[i].dustPresent : false
        while i < dustBands.count && dustBands[i].inner < outsideRange {
            dustHere = dustHere || dustBands[i].dustPresent
            i += 1
        }
        return dustHere
    }

    func updateDustLanes(lo: Double, hi: Double, mass: Double, critMass: Double,
                         bodyInnerBound: Double, bodyOuterBound: Double) {
        dustLeft = false
        let gas = !(mass > critMass)

        // Split bands at the swept region [lo, hi] and clear dust (and maybe gas) inside it.
        var i = 0
        while i < dustBands.count {
            let band = dustBands[i]
            let sweptGas = band.gasPresent ? gas : false

            if band.inner < lo && band.outer > hi {
                dustBands[i].outer = lo
                dustBands.insert(contentsOf: [
                    DustBand(inner: lo, outer: hi, dustPresent: false, gasPresent: sweptGas),
                    DustBand(inner: hi, outer: band.outer, dustPresent: band.dustPresent, gasPresent: band.gasPresent)
                ], at: i + 1)
                i += 3
            } else if band.inner < hi && band.outer > hi {
                dustBands.insert(DustBand(inner: hi, outer: band.outer,
                                          dustPresent: band.dustPresent, gasPresent: band.gasPresent), at: i + 1)
                dustBands[i].outer = hi
                dustBands[i].gasPresent = sweptGas
                dustBands[i].dustPresent = false
                i += 2
            } else if band.inner < lo && band.outer > lo {
                dustBands.insert(DustBand(inner: lo, outer: band.outer,
                                          dustPresent: false, gasPresent: sweptGas), at: i + 1)
                dustBands[i].outer = lo
                i += 2
            } else if band.inner >= lo && band.outer <= hi {
                dustBands[i].gasPresent = sweptGas
                dustBands[i].dustPresent = false
                i += 1
            } else {
                // Outside the swept region. (Also covers edge-equality cases
                // that would hang the original C loop.)
                i += 1
            }
        }

        // Check for remaining dust and merge adjacent identical bands.
        i = 0
        while i < dustBands.count {
            let band = dustBands[i]
            if band.dustPresent && band.outer >= bodyInnerBound && band.inner <= bodyOuterBound {
                dustLeft = true
            }
            if i + 1 < dustBands.count {
                let next = dustBands[i + 1]
                if band.dustPresent == next.dustPresent && band.gasPresent == next.gasPresent {
                    dustBands[i].outer = next.outer
                    dustBands.remove(at: i + 1)
                }
            }
            i += 1
        }
    }

    func collectDust(lastMass: Double, a: Double, e: Double, critMass: Double) -> Double {
        reducedMass = pow(lastMass / (1.0 + lastMass), 1.0 / 4.0)
        rInner = max(innerEffectLimit(a, e, reducedMass), 0.0)
        rOuter = outerEffectLimit(a, e, reducedMass)

        var collected = 0.0
        for band in dustBands {
            let tempDensity = band.dustPresent ? dustDensity : 0.0
            let massDensity: Double
            if lastMass < critMass || !band.gasPresent {
                massDensity = tempDensity
            } else {
                massDensity = Const.gasDustRatio * tempDensity
                    / (1.0 + sqrt(critMass / lastMass) * (Const.gasDustRatio - 1.0))
            }

            if band.outer <= rInner || band.inner >= rOuter { continue }

            let bandwidth = rOuter - rInner
            let temp1 = max(rOuter - band.outer, 0.0)
            let temp2 = max(band.inner - rInner, 0.0)
            let width = bandwidth - temp1 - temp2
            let temp = 4.0 * Double.pi * pow(a, 2.0) * reducedMass
                * (1.0 - e * (temp1 - temp2) / bandwidth)
            collected += temp * width * massDensity
        }
        return collected
    }

    /// Mass (solar masses) at which a planet begins to accrete gas as well as dust.
    func criticalLimit(_ orbitalRadius: Double, _ eccentricity: Double, _ luminosity: Double) -> Double {
        let perihelion = orbitalRadius - orbitalRadius * eccentricity
        return Const.critMassB * pow(perihelion * sqrt(luminosity), -0.75)
    }

    func accreteDust(_ seedMass: inout Double, a: Double, e: Double, critMass: Double,
                     bodyInnerBound: Double, bodyOuterBound: Double) {
        var newMass = seedMass
        var tempMass: Double
        var iterations = 0
        repeat {
            tempMass = newMass
            newMass = collectDust(lastMass: newMass, a: a, e: e, critMass: critMass)
            iterations += 1
        } while !((newMass - tempMass) < (0.0001 * tempMass)) && iterations < 10_000
        seedMass += newMass
        updateDustLanes(lo: rInner, hi: rOuter, mass: seedMass, critMass: critMass,
                        bodyInnerBound: bodyInnerBound, bodyOuterBound: bodyOuterBound)
    }

    func coalescePlanetesimals(a: Double, e: Double, mass: Double, critMass: Double,
                               bodyInnerBound: Double, bodyOuterBound: Double) {
        var e = e
        for i in planets.indices {
            let node = planets[i]
            let temp = node.a - a
            let dist1: Double
            let dist2: Double
            if temp > 0.0 {
                dist1 = (a * (1.0 + e) * (1.0 + reducedMass)) - a          // x aphelion
                reducedMass = pow(node.mass / (1.0 + node.mass), 1.0 / 4.0)
                dist2 = node.a - (node.a * (1.0 - node.e) * (1.0 - reducedMass))
            } else {
                dist1 = a - (a * (1.0 - e) * (1.0 - reducedMass))          // x perihelion
                reducedMass = pow(node.mass / (1.0 + node.mass), 1.0 / 4.0)
                dist2 = (node.a * (1.0 + node.e) * (1.0 + reducedMass)) - node.a
            }

            if abs(temp) <= abs(dist1) || abs(temp) <= abs(dist2) {
                trace("Collision between two planetesimals!")
                let a3 = (node.mass + mass) / ((node.mass / node.a) + (mass / a))
                var t = node.mass * sqrt(node.a) * sqrt(1.0 - pow(node.e, 2.0))
                t += mass * sqrt(a) * sqrt(sqrt(1.0 - pow(e, 2.0)))
                t /= (node.mass + mass) * sqrt(a3)
                t = 1.0 - pow(t, 2.0)
                if t < 0.0 || t >= 1.0 { t = 0.0 }
                e = sqrt(t)

                var newMass = node.mass + mass
                // The original passes the stellar luminosity as the critical mass here.
                accreteDust(&newMass, a: a3, e: e, critMass: stellarLuminosityRatio,
                            bodyInnerBound: bodyInnerBound, bodyOuterBound: bodyOuterBound)
                planets[i].a = a3
                planets[i].e = e
                planets[i].mass = newMass
                return
            }
        }

        // No collision: insert a new planet, keeping the list sorted by distance.
        var planet = Planet()
        planet.a = a
        planet.e = e
        planet.mass = mass
        planet.isGasGiant = mass >= critMass
        let index = planets.firstIndex { $0.a >= a } ?? planets.endIndex
        planets.insert(planet, at: index)
    }

    /// Protoplanets are injected between `innerBound` and `outerBound` (AU); companion
    /// stars narrow both the dust disk and that range to the dynamically stable band.
    func distributePlanetaryMasses(innerDust: Double, outerDust: Double,
                                   innerBound: Double, outerBound: Double) -> [Planet] {
        setInitialConditions(innerDust: innerDust, outerDust: outerDust)
        guard innerBound < outerBound else { return [] }

        while dustLeft {
            let a = randomNumber(innerBound, outerBound)
            let e = randomEccentricity()
            var mass = Const.protoplanetMass
            trace(String(format: "Checking %f AU.", a))

            if dustAvailable(innerEffectLimit(a, e, mass), outerEffectLimit(a, e, mass)) {
                trace(".. Injecting protoplanet.")
                dustDensity = Const.dustDensityCoeff * pow(stellarMassRatio, 0.3)
                    * exp(-Const.alpha * pow(a, 1.0 / Const.n))
                let critMass = criticalLimit(a, e, stellarLuminosityRatio)
                accreteDust(&mass, a: a, e: e, critMass: critMass,
                            bodyInnerBound: innerBound, bodyOuterBound: outerBound)
                if mass != 0.0 && mass != Const.protoplanetMass {
                    coalescePlanetesimals(a: a, e: e, mass: mass, critMass: critMass,
                                          bodyInnerBound: innerBound, bodyOuterBound: outerBound)
                } else {
                    trace(".. failed due to large neighbor.")
                }
            } else {
                trace(".. failed.")
            }
        }
        return planets
    }

    /// Generates a set of moons for a given planet.
    func distributeMoonMasses(for planet: Planet, stellarMass: Double) -> [Planet] {
        guard !planet.isGasGiant, planet.mass > 0 else { return [] }
        
        let numMoons = Int(randomNumber(0, 4))
        if numMoons == 0 { return [] }
        
        // Hill sphere: R_H = a * (m / 3M)^(1/3)
        let hillSphere = planet.a * pow(planet.mass / (3.0 * stellarMass), 1.0/3.0)
        let maxMoonA = max(hillSphere * 0.5, 0.0001)
        
        var moons: [Planet] = []
        for _ in 0..<numMoons {
            var moon = Planet()
            moon.a = randomNumber(0.0001, maxMoonA)
            moon.mass = planet.mass * randomNumber(1e-5, 1e-3)
            moon.isGasGiant = false
            
            let originalRatio = self.stellarMassRatio
            self.stellarMassRatio = planet.mass
            computeEnvironment(&moon)
            self.stellarMassRatio = originalRatio
            
            moons.append(moon)
        }
        
        return moons.sorted(by: { $0.a < $1.a })
    }
}
