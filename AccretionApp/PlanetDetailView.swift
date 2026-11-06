//
//  PlanetDetailView.swift
//  AccretionApp
//
//  Physical details for one planet, shown in the inspector when it is clicked in a row.
//

import SwiftUI

struct PlanetDetailView: View {
    let planet: Planet
    let number: Int
    let host: PlanetHost
    let system: StarSystem
    var onClose: () -> Void = {}

    var body: some View {
        let kind = planet.kind
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(kind.color).frame(width: 14, height: 14)
                Text("Planet \(number)").font(.headline)
                Text(kind.name).foregroundStyle(.secondary)
                Spacer()
                Button("Close", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.cancelAction)
            }
            Text(String(format: "Seed %llu", system.seed))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if !badges.isEmpty {
                Text(badges.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let range = planet.beltRange {
                beltDetails(range)
            } else {
                planetDetails
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A belt merges several planetoids, so it gets totals and averages instead of a body.
    private func beltDetails(_ range: ClosedRange<Double>) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
            section("Orbit")
            row("Orbits", system.stars(of: host).map(\.designation).joined(separator: " + "))
            row("Extent", String(format: "%.3f – %.3f AU", range.lowerBound, range.upperBound))
            row("Mean distance", String(format: "%.3f AU", planet.a))
            row("Mean eccentricity", String(format: "%.3f", planet.e))
            row("Year at mean distance", String(format: "%.2f days", planet.orbitalPeriod))

            section("Belt")
            row("Planetoids merged", "\(planet.beltBodyCount)")
            row("Total mass", String(format: "%.4f Earth masses", earthMasses))
            row("Typical temperature", celsius(planet.surfaceTemp))
        }
        .font(.callout.monospacedDigit())
    }

    /// Why a rocky planet can or can't support life as we know it: the first failed test.
    private var habitabilityVerdict: String {
        let atmospheres = planet.surfacePressure / Const.earthSurfPresInMillibars
        let celsius = planet.surfaceTemp - Const.kelvinCelsiusDifference
        if system.isPotentiallyHabitable(planet, in: host) { return "Potentially habitable" }
        if system.hasIonizingHost(host) {
            return planet.isPotentiallyHabitable(systemAge: system.age)
                ? "Temperate, but bathed in X-rays and particles" : "Bathed in X-rays and particles"
        }
        if !Habitability.massRange.contains(earthMasses) {
            return earthMasses < Habitability.massRange.lowerBound
                ? "Too small to hold an atmosphere" : "Too massive (likely a mini-Neptune)"
        }
        if planet.greenhouseEffect && planet.surfacePressure > 0 { return "Runaway greenhouse" }
        if atmospheres < Habitability.pressureRange.lowerBound { return "Atmosphere too thin" }
        if !planet.hasLiquidWater {
            return celsius < 0 ? "Frozen, no liquid water" : celsius > 100 ? "Too hot for liquid water" : "No surface water"
        }
        if !Habitability.temperatureRange.contains(planet.surfaceTemp) {
            return celsius < 0 ? "Too cold" : "Too hot for most Earth life"
        }
        if atmospheres > Habitability.pressureRange.upperBound { return "Atmosphere too dense" }
        return String(format: "System too young (%.0f Myr)", system.age / 1.0e6)
    }

    private var planetDetails: some View {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                if planet.isRocky {
                    section("Habitability")
                    row("Verdict", habitabilityVerdict)
                    row("Earth Similarity", String(format: "%.2f (Earth = 1)", planet.earthSimilarity))
                    row("Liquid water", planet.hasLiquidWater ? "Yes" : "No")
                }

                section("Orbit")
                row("Orbits", system.stars(of: host).map(\.designation).joined(separator: " + "))
                row("Distance", String(format: "%.3f AU", planet.a))
                row("Eccentricity", String(format: "%.3f", planet.e))
                row("Year", String(format: "%.2f days", planet.orbitalPeriod))
                row("Day", String(format: "%.2f hours", planet.day))
                row("Axial tilt", "\(planet.axialTilt)°")

                section("Body")
                row("Mass", String(format: "%.3f Earth masses", earthMasses))
                row("Radius", String(format: "%.0f km (%.2f Earth)", planet.radius,
                                     planet.radius / Const.earthRadiusInKM))
                row("Density", String(format: "%.2f g/cm³", planet.density))
                row("Escape velocity", String(format: "%.2f km/s", planet.escapeVelocity / Const.cmPerKM))
                row("Lightest gas retained", String(format: "%.1f (molecular weight)", planet.moleculeWeight))
                row("Albedo", String(format: "%.3f", planet.albedo))

                if !planet.isGasGiant {
                    section("Surface")
                    row("Gravity", String(format: "%.2f g", planet.surfaceGrav))
                    row("Pressure", String(format: "%.3f atm", planet.surfacePressure / 1000.0))
                    row("Temperature", celsius(planet.surfaceTemp))
                    row("Water boils at", planet.surfacePressure > 0 ? celsius(planet.boilPoint) : "—")
                    row("Hydrosphere", percent(planet.hydrosphere))
                    row("Cloud cover", percent(planet.cloudCover))
                    row("Ice cover", percent(planet.iceCover))

                    if !planet.moons.isEmpty {
                        section("Moons")
                        ForEach(Array(planet.moons.enumerated()), id: \.offset) { idx, moon in
                            row("Moon \(idx + 1)", String(format: "%.2f Earth masses", moon.mass * Const.earthMassesPerSolarMass))
                        }
                    }
                }
            }
            .font(.callout.monospacedDigit())
    }

    private var earthMasses: Double { planet.mass * Const.earthMassesPerSolarMass }

    private var badges: [String] {
        var result: [String] = []
        if system.isPotentiallyHabitable(planet, in: host) { result.append("Potentially habitable") }
        if host.habitableZone.contains(planet.a) { result.append("In habitable zone") }
        if planet.greenhouseEffect && planet.surfacePressure > 0 { result.append("Runaway greenhouse") }
        if planet.resonantPeriod { result.append("Spin–orbit resonance") }
        return result
    }

    private func celsius(_ kelvin: Double) -> String {
        String(format: "%.1f °C", kelvin - Const.kelvinCelsiusDifference)
    }

    private func percent(_ fraction: Double) -> String {
        String(format: "%.1f%%", fraction * 100)
    }

    private func section(_ title: String) -> some View {
        GridRow {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
                .padding(.top, 4)
                .gridCellColumns(2)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
    }
}
