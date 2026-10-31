//
//  PlanetKind.swift
//  AccretionApp
//
//  Visual classification of generated bodies and stars.
//

import SwiftUI

/// Broad planet types, derived from the physical values the generator computes.
enum PlanetKind: CaseIterable {
    case belt, rock, hothouse, desert, terrestrial, ocean, ice, iceGiant, gasGiant

    /// Rocky bodies lighter than this (Earth masses) are drawn as planetoid belts.
    static let beltMassLimit = 0.01
    /// Gas giants lighter than this (Earth masses) are drawn as ice giants.
    static let iceGiantMassLimit = 25.0

    init(_ p: Planet) {
        let earthMasses = p.mass * Const.earthMassesPerSolarMass
        let atmospheres = p.surfacePressure / Const.earthSurfPresInMillibars

        if p.isGasGiant {
            self = earthMasses < Self.iceGiantMassLimit ? .iceGiant : .gasGiant
        } else if earthMasses < Self.beltMassLimit {
            self = .belt
        } else if p.surfacePressure <= 0.0 {
            self = .rock
        } else if p.greenhouseEffect {
            self = .hothouse
        } else if p.iceCover > 0.5 {
            self = .ice
        } else if p.hydrosphere >= 0.95 {
            self = .ocean
        } else if p.hydrosphere > 0.05, (0.1...5.0).contains(atmospheres),
                  (Const.freezingPointOfWater...323.0).contains(p.surfaceTemp) {
            self = .terrestrial
        } else {
            self = .desert
        }
    }

    var name: String {
        switch self {
        case .belt: "Planetoid belt"
        case .rock: "Airless rock"
        case .hothouse: "Hothouse"
        case .desert: "Desert"
        case .terrestrial: "Earthlike"
        case .ocean: "Ocean"
        case .ice: "Ice world"
        case .iceGiant: "Ice giant"
        case .gasGiant: "Gas giant"
        }
    }

    var color: Color {
        switch self {
        case .belt: Color(red: 0.62, green: 0.56, blue: 0.50)
        case .rock: Color(red: 0.55, green: 0.55, blue: 0.57)
        case .hothouse: Color(red: 0.93, green: 0.80, blue: 0.45)
        case .desert: Color(red: 0.80, green: 0.42, blue: 0.25)
        case .terrestrial: Color(red: 0.25, green: 0.62, blue: 0.45)
        case .ocean: Color(red: 0.15, green: 0.40, blue: 0.85)
        case .ice: Color(red: 0.88, green: 0.94, blue: 1.00)
        case .iceGiant: Color(red: 0.45, green: 0.78, blue: 0.90)
        case .gasGiant: Color(red: 0.85, green: 0.65, blue: 0.42)
        }
    }
}

extension Planet {
    var kind: PlanetKind { PlanetKind(self) }
}

extension Star {
    /// Star color, interpolated along approximate blackbody colors.
    var color: Color { Self.color(temperature: temperature) }

    static func color(temperature: Double) -> Color {
        let stops: [(t: Double, r: Double, g: Double, b: Double)] = [
            (2500, 1.00, 0.42, 0.20),
            (3500, 1.00, 0.58, 0.32),
            (4500, 1.00, 0.74, 0.45),
            (5300, 1.00, 0.88, 0.64),
            (5800, 1.00, 0.96, 0.82),
            (6500, 0.98, 0.98, 1.00),
            (7500, 0.85, 0.89, 1.00),
            (10000, 0.70, 0.78, 1.00),
            (20000, 0.60, 0.70, 1.00),
            (40000, 0.55, 0.65, 1.00),
        ]
        let t = min(max(temperature, stops.first!.t), stops.last!.t)
        let upper = stops.firstIndex { $0.t >= t } ?? stops.count - 1
        let lo = stops[max(upper - 1, 0)], hi = stops[upper]
        let f = hi.t == lo.t ? 0 : (t - lo.t) / (hi.t - lo.t)
        return Color(red: lo.r + (hi.r - lo.r) * f,
                     green: lo.g + (hi.g - lo.g) * f,
                     blue: lo.b + (hi.b - lo.b) * f)
    }

    /// Display diameter (points). Radii span ~0.1 to ~10 solar radii, so this uses a
    /// cube-root scale: still ordered by size, but red dwarfs stay visible and O stars fit.
    var displayDiameter: CGFloat { min(28 * cbrt(radius), 60) }
}

extension SpectralClass {
    /// Color at the middle of the class's temperature range, for the legend.
    var color: Color {
        let range = temperatureRange
        return Star.color(temperature: (range.lowerBound + range.upperBound) / 2)
    }
}

extension PlanetHost {
    /// Habitable zone: from the runaway-greenhouse limit out to Kasting's
    /// outer edge (1.37 AU for the sun), scaled by luminosity.
    var habitableZone: ClosedRange<Double> {
        greenhouseRadius...(1.37 * ecosphereRadius)
    }
}

/// Stars drawn on the axis of a focused host: their distance from it, and the hosts
/// whose planets are shown collapsed beside them.
struct NeighborStars {
    var starIndices: [Int]
    var a: Double
    var e: Double
    var hostIndices: [Int]
}

extension StarSystem: Identifiable {
    var id: UInt64 { seed }

    var configurationLabel: String {
        let multiplicity = switch (orbitType, companions.count) {
        case (_, 0): "single"
        case (.circumbinary, 1): "close binary, circumbinary planets"
        case (.circumbinary, _): "triple, circumbinary planets"
        case (_, 1): "binary"
        default: "triple"
        }
        let withPlanets = hosts.filter { !$0.planets.isEmpty }.count
        return withPlanets > 1 ? "\(multiplicity), \(withPlanets) planetary systems" : multiplicity
    }

    /// The other stars as seen from a host, placed at their separation from it.
    /// Seen from the outer star of a triple, the inner pair is one group at the outer orbit.
    func neighbors(ofHost hostIndex: Int) -> [NeighborStars] {
        let focus = hosts[hostIndex].starIndices
        var groups: [(stars: [Int], a: Double, e: Double)] = []
        if focus.contains(0) {
            // Primary (or close pair): each companion not in the host at its own orbit.
            for (offset, companion) in companions.enumerated() where !focus.contains(offset + 1) {
                groups.append(([offset + 1], companion.a, companion.e))
            }
        } else if focus == [1] {
            groups.append(([0], companions[0].a, companions[0].e))
            if companions.count > 1 { groups.append(([2], companions[1].a, companions[1].e)) }
        } else if focus == [2] {
            groups.append(([0, 1], companions[1].a, companions[1].e))
        }
        return groups.map { group in
            var hostIndices: [Int] = []
            for star in group.stars {
                if let index = self.hostIndex(ofStar: star), !hostIndices.contains(index) {
                    hostIndices.append(index)
                }
            }
            return NeighborStars(starIndices: group.stars, a: group.a, e: group.e, hostIndices: hostIndices)
        }
    }
}
