//
//  Display.swift
//  Accretion
//
//  Ported from DISPLAY.C.
//

import Foundation

extension StarSystem {
    /// Same text report the C version wrote to "New.System".
    func report() -> String {
        var out = ""
        func line(_ format: String, _ args: CVarArg...) {
            out += String(format: format, arguments: args) + "\n"
        }

        line("                         SYSTEM  CHARACTERISTICS")
        line("Seed: %llu", seed)
        func describe(_ label: String, _ s: Star) {
            if s.isWhiteDwarf {
                line("%@: %@, white dwarf of %.2f solar masses, radius %.0f km, %.0f K, %.3g solar luminosities",
                     label, s.designation, s.mass, s.radius * Const.solarRadiusInKM, s.temperature, s.luminosity)
                return
            }
            if let name = s.spectralClass.remnantName {
                let radius = s.radius * Const.solarRadiusInKM
                if s.spectralClass == .blackHole {
                    line("%@: %@, %@ of %.2f solar masses, event horizon radius %.1f km",
                         label, s.designation, name, s.mass, radius)
                } else {
                    let kind = s.isMillisecondPulsar ? "millisecond pulsar" : name
                    line("%@: %@, %@ of %.2f solar masses, radius %.0f km, %.3g K, %.3g solar luminosities",
                         label, s.designation, kind, s.mass, radius, s.temperature, s.luminosity)
                    if s.spinDownLuminosity > 0 {
                        line("   Pulsar wind %.3g solar luminosities (%.3g erg/s); planets absorb %.0f%% as heat",
                             s.spinDownLuminosity, s.spinDownLuminosity * Const.solarLuminosityInErgs,
                             Const.pulsarWindHeatingEfficiency * 100)
                    }
                }
                return
            }
            line("%@: %@, %.3f solar masses, %.4g solar luminosities, %.3f solar radii, %.0f K%@",
                 label, s.designation, s.mass, s.luminosity, s.radius, s.temperature,
                 s.isBrownDwarf ? String(format: ", brown dwarf of %.0f Jupiter masses",
                                         s.mass * Const.jupiterMassesPerSolarMass) : "")
        }
        describe("Primary star", primary)
        for (index, c) in companions.enumerated() {
            describe("Companion #\(index + 1)", c.star)
            line("   Orbits %@: a = %.4g AU, e = %.3f, period = %.4g days",
                 c.orbitsInnerPair ? "the inner pair" : "the primary", c.a, c.e, c.period)
        }
        if primary.isWhiteDwarf {
            line("Total main sequence lifetime: ended (white dwarf, cooling for %.3f million yrs)",
                 (age - Const.whiteDwarfProgenitorLife) / 1.0e6)
        } else if primary.isRemnant {
            line("Total main sequence lifetime: none (stellar remnant; age is time since the supernova)")
        } else if primary.isBrownDwarf {
            line("Total main sequence lifetime: none (brown dwarf, cools forever)")
        } else {
            line("Total main sequence lifetime (in million yrs): %10.3f", mainSequenceLife / 1.0e6)
        }
        line("Current age of stellar system (in million yrs): %10.3f", age / 1.0e6)

        for host in hosts {
            let names = stars(of: host).map(\.designation).joined(separator: " + ")
            line("")
            switch host.orbitType {
            case .single:
                line("PLANETS OF %@", names)
            case .circumstellar:
                line("PLANETS OF %@ (S-type), stable inside %.3g AU", names, host.stableOuterLimit ?? 0)
            case .circumbinary:
                line("PLANETS OF %@ (P-type), stable beyond %.3g AU", names, host.stableInnerLimit ?? 0)
                if let outer = host.stableOuterLimit { line("   and inside %.3g AU", outer) }
            }
            line("Mass of central star(s) (in solar masses): %4.2f", host.mass)
            line("Luminosity of central star(s) (relative to the sun): %5.4g", host.luminosity)
            line("Radius of habitable ecosphere (AU): %3.3f", host.ecosphereRadius)
            if host.planets.isEmpty { line("No planets formed.") }
            reportPlanets(host, line: line)
        }
        return out
    }

    private func reportPlanets(_ host: PlanetHost, line: (String, CVarArg...) -> Void) {
        for (index, p) in host.planets.enumerated() {
            line("Planet #%ld:", index + 1)
            if let range = p.beltRange {
                if p.beltBodyCount == 1 {
                    line("Lone planetoid at %.3f AU, mass %.4f Earth masses",
                         range.lowerBound, p.mass * Const.earthMassesPerSolarMass)
                } else {
                    line("Planetoid belt of %ld bodies, %.3f to %.3f AU, total mass %.4f Earth masses",
                         p.beltBodyCount, range.lowerBound, range.upperBound,
                         p.mass * Const.earthMassesPerSolarMass)
                }
                continue
            }
            if p.isGasGiant { line("Gas giant...") }
            if p.isRocky {
                line("   Earth Similarity Index: %4.2f%@", p.earthSimilarity,
                     isPotentiallyHabitable(p, in: host) ? "     POTENTIALLY HABITABLE" : "")
            }
            if p.resonantPeriod { line("In resonant period with primary.") }
            line("   Distance from its star(s) (in A.U.): %7.3f", p.a)
            line("   Eccentricity of orbit: %5.3f", p.e)
            line("   Mass (in Earth masses): %7.3f", p.mass * Const.earthMassesPerSolarMass)
            line("   Equatorial radius (in Km): %10.1f", p.radius)
            line("   Density (in g/cc): %6.3f", p.density)
            line("   Escape Velocity (in km/sec): %5.2f", p.escapeVelocity / Const.cmPerKM)
            line("   Smallest molecular weight retained: %5.2f", p.moleculeWeight)
            line("   Surface acceleration (in cm/sec2): %6.2f", p.surfaceAccel)
            if !p.isGasGiant {
                line("   Surface Gravity (in Earth gees): %5.2f", p.surfaceGrav)
                line("   Boiling point of water (celcius): %4.1f", p.boilPoint - Const.kelvinCelsiusDifference)
                let runaway = p.greenhouseEffect && p.surfacePressure > 0.0
                line("   Surface Pressure (in atmospheres): %5.3f"
                     + (runaway ? "     RUNAWAY GREENHOUSE EFFECT" : ""),
                     p.surfacePressure / 1000.0)
                line("   Surface temperature (Celcius): %4.2f", p.surfaceTemp - Const.kelvinCelsiusDifference)
                line("   Hydrosphere percentage: %6.2f", p.hydrosphere * 100.0)
                line("   Cloud cover percentage: %6.2f", p.cloudCover * 100.0)
                line("   Ice cover percentage: %6.2f", p.iceCover * 100.0)
            }
            line("   Axial tilt (in degrees): %ld", p.axialTilt)
            line("   Planetary albedo: %4.3f", p.albedo)
            line("   Length of year (in days): %7.2f", p.orbitalPeriod)
            line("   Length of day (in hours): %7.2f", p.day)
        }
    }
}
