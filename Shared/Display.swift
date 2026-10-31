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
            line("%@: %@, %.2f solar masses, %.4g solar luminosities, %.2f solar radii, %.0f K",
                 label, s.designation, s.mass, s.luminosity, s.radius, s.temperature)
        }
        describe("Primary star", primary)
        for (index, c) in companions.enumerated() {
            describe("Companion #\(index + 1)", c.star)
            line("   Orbits %@: a = %.4g AU, e = %.3f, period = %.4g days",
                 c.orbitsInnerPair ? "the inner pair" : "the primary", c.a, c.e, c.period)
        }
        switch orbitType {
        case .single:
            break
        case .circumstellar:
            line("Planets orbit the primary (S-type), stable inside %.3g AU", stableOuterLimit ?? 0)
        case .circumbinary:
            line("Planets orbit the inner pair (P-type), stable beyond %.3g AU", stableInnerLimit ?? 0)
            if let outer = stableOuterLimit { line("   and inside %.3g AU", outer) }
        }
        line("Mass of central star(s) (in solar masses): %4.2f", stellarMass)
        line("Luminosity of central star(s) (relative to the sun): %5.2f", stellarLuminosity)
        line("Total main sequence lifetime (in million yrs): %10.3f", mainSequenceLife / 1.0e6)
        line("Current age of stellar system (in million yrs): %10.3f", age / 1.0e6)
        line("Radius of habitable ecosphere (AU): %3.3f", ecosphereRadius)

        for (index, p) in planets.enumerated() {
            line("Planet #%ld:", index + 1)
            if p.isGasGiant { line("Gas giant...") }
            if p.resonantPeriod { line("In resonant period with primary.") }
            line("   Distance from primary star (in A.U.): %7.3f", p.a)
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
        return out
    }
}
