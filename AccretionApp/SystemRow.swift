//
//  SystemRow.swift
//  AccretionApp
//
//  One star system: the focused star (or close pair) on the left, its bodies
//  laid out to the right on a logarithmic distance axis, and the other stars
//  at their separation with their own planets collapsed beside them.
//  Clicking another star expands its planets and collapses the focused ones.
//

import SwiftUI

/// Logarithmic AU axis shared by the rows and the header so they line up.
enum OrbitScale {
    // Down to 0.001 AU so brown dwarfs' close-in planets and habitable zones fit.
    static let range = 0.001...1000.0
    static let decades: [Double] = [0.001, 0.01, 0.1, 1, 10, 100, 1000]
    static let inset: CGFloat = 12
    static let starColumnWidth: CGFloat = 76
    static let rowHeight: CGFloat = 76

    static func x(_ au: Double, width: CGFloat) -> CGFloat {
        let lo = log10(range.lowerBound), hi = log10(range.upperBound)
        let clamped = min(max(au, range.lowerBound), range.upperBound)
        let fraction = (log10(clamped) - lo) / (hi - lo)
        return inset + CGFloat(fraction) * (width - 2 * inset)
    }

    static func label(_ au: Double) -> String {
        switch au {
        case ..<0.01: String(format: "%.3f AU", au)
        case ..<1: String(format: "%.2g AU", au)
        case ..<10: String(format: "%.1f AU", au)
        case ..<1000: String(format: "%.0f AU", au)
        default: String(format: "%.1fk AU", au / 1000)
        }
    }
}

/// Draws a star as a bright disc with a soft glow in its color. A black hole is a dark disc
/// inside an orange accretion glow; a pulsar adds its two radio beams.
func drawStar(_ star: Star, at center: CGPoint, diameter: CGFloat, in context: inout GraphicsContext) {
    let color = star.color
    if star.spectralClass == .blackHole {
        let glow = diameter * 2.2
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - glow / 2, y: center.y - glow / 2, width: glow, height: glow)),
            with: .radialGradient(Gradient(colors: [color, color.opacity(0.35), color.opacity(0)]),
                                  center: center, startRadius: diameter / 2, endRadius: glow / 2))
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                                   width: diameter, height: diameter)),
            with: .color(.black))
        return
    }
    if star.spectralClass == .pulsar {
        // Beams tilted off the spin axis, as from a magnetic pole.
        let length = diameter * 3
        let dx = length * 0.45, dy = length * 0.9
        context.stroke(Path { $0.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
                              $0.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy)) },
                       with: .linearGradient(Gradient(colors: [color.opacity(0), color, color.opacity(0)]),
                                             startPoint: CGPoint(x: center.x - dx, y: center.y - dy),
                                             endPoint: CGPoint(x: center.x + dx, y: center.y + dy)),
                       lineWidth: 1.5)
    }
    let glow = diameter * 1.6
    context.fill(
        Path(ellipseIn: CGRect(x: center.x - glow / 2, y: center.y - glow / 2, width: glow, height: glow)),
        with: .radialGradient(Gradient(colors: [color.opacity(0.5), color.opacity(0)]),
                              center: center, startRadius: diameter / 2, endRadius: glow / 2))
    context.fill(
        Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                               width: diameter, height: diameter)),
        with: .radialGradient(Gradient(colors: [.white, color]),
                              center: center, startRadius: 0, endRadius: diameter / 2))
}

/// Draws one star, or a close pair with the partner behind and offset.
func drawStars(_ stars: [Star], at center: CGPoint, scale: CGFloat, maxDiameter: CGFloat,
               in context: inout GraphicsContext) {
    let diameters = stars.map { min($0.displayDiameter * scale, maxDiameter) }
    if stars.count == 2 {
        drawStar(stars[1], at: CGPoint(x: center.x + diameters[0] * 0.35, y: center.y + diameters[0] * 0.2),
                 diameter: diameters[1], in: &context)
        drawStar(stars[0], at: CGPoint(x: center.x - diameters[1] * 0.3, y: center.y - diameters[1] * 0.15),
                 diameter: diameters[0], in: &context)
    } else if let star = stars.first {
        drawStar(star, at: center, diameter: diameters[0], in: &context)
    }
}

struct SystemRow: View {
    let system: StarSystem
    /// The selected planet, if it is in this system.
    var selectedPlanet: PlanetReference?
    var onSelectPlanet: (_ host: Int, _ index: Int) -> Void = { _, _ in }

    /// Which host's planets are expanded on the axis.
    @State private var focusedHost = 0

    var body: some View {
        let hostIndex = system.hosts.indices.contains(focusedHost) ? focusedHost : 0
        let host = system.hosts[hostIndex]
        HStack(spacing: 0) {
            HostStarsView(stars: system.stars(of: host))
                .frame(width: OrbitScale.starColumnWidth)
                .contentShape(Rectangle())
                .onTapGesture { focus(0) }
                .id(hostIndex)
                .transition(.opacity)
            OrbitTrack(system: system, hostIndex: hostIndex,
                       selectedIndex: selectedPlanet?.host == hostIndex ? selectedPlanet?.index : nil,
                       onSelectPlanet: { onSelectPlanet(hostIndex, $0) },
                       onFocusHost: focus)
                .id(hostIndex)
                .transition(.opacity)
                .overlay(alignment: .topLeading) {
                    Text(caption(hostIndex: hostIndex))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.leading, OrbitScale.inset)
                        .padding(.top, 3)
                        .allowsHitTesting(false)
                }
        }
        .frame(height: OrbitScale.rowHeight)
    }

    private func focus(_ hostIndex: Int) {
        guard hostIndex != focusedHost else { return }
        withAnimation(.easeInOut(duration: 0.25)) { focusedHost = hostIndex }
    }

    private func caption(hostIndex: Int) -> String {
        let host = system.hosts[hostIndex]
        let stars = system.stars.map(\.designation).joined(separator: " + ")
        let focus = hostIndex == 0 ? "" : "Planets of "
            + system.stars(of: host).map(\.designation).joined(separator: " + ") + "  ·  "
        let bodies = switch host.planets.count {
        case 0: "no stable planets"
        case 1: "1 body"
        case let n: "\(n) bodies"
        }
        // The system's most Earth-like planet, wherever it orbits.
        var habitability = ""
        if let best = system.bestHabitabilityCandidate, best.isPotentiallyHabitable {
            let where_ = best.host == 0 ? "" : " of "
                + system.stars(of: system.hosts[best.host]).map(\.designation).joined(separator: " + ")
            habitability = String(format: "  ·  habitable: planet %ld%@ (ESI %.2f)",
                                  best.index + 1, where_, best.earthSimilarity)
        }
        let light = host.luminosity <= Const.minimumLuminosity
            ? "dark" : String(format: "%.3g L☉", host.luminosity)
        return String(format: "%@%@  ·  %@  ·  host %.2f M☉ %@  ·  %@%@  ·  seed %llu",
                      focus, stars, system.configurationLabel, host.mass,
                      light, bodies, habitability, system.seed)
    }
}

/// The focused star, or both stars of a close circumbinary pair.
/// Clicking it returns the row to the primary's planets.
struct HostStarsView: View {
    let stars: [Star]

    var body: some View {
        Canvas { context, size in
            drawStars(stars, at: CGPoint(x: size.width / 2, y: size.height / 2),
                      scale: stars.count == 2 ? 0.8 : 1, maxDiameter: 60, in: &context)
        }
        .help(stars.map { star in
            if let name = star.spectralClass.remnantName {
                let radius = star.radius * Const.solarRadiusInKM
                if star.spectralClass == .blackHole {
                    return String(format: "Black hole: %.1f M☉, event horizon %.0f km", star.mass, radius)
                }
                let kind = star.isMillisecondPulsar ? "Millisecond pulsar" : name.capitalized
                let wind = star.spinDownLuminosity > 0
                    ? String(format: ", wind %.3g L☉", star.spinDownLuminosity) : ""
                return String(format: "%@ %@: %.2f M☉, %.0f km across, %.3g K%@",
                              star.designation, kind, star.mass, 2 * radius, star.temperature, wind)
            }
            return star.isBrownDwarf
                ? String(format: "%@ brown dwarf: %.0f Jupiter masses, %.3f R☉, %.0f K",
                         star.designation, star.mass * Const.jupiterMassesPerSolarMass,
                         star.radius, star.temperature)
                : String(format: "%@: %.2f M☉, %.2f R☉, %.0f K",
                         star.designation, star.mass, star.radius, star.temperature)
        }.joined(separator: "\n"))
    }
}

/// Orbits, habitable zone, stability limits, neighbouring stars and bodies of one
/// host, drawn in a single Canvas so 1000 rows stay cheap. Clicking a body selects
/// it; clicking another star (or its collapsed planets) focuses that star.
struct OrbitTrack: View {
    let system: StarSystem
    let hostIndex: Int
    let selectedIndex: Int?
    let onSelectPlanet: (Int) -> Void
    let onFocusHost: (Int) -> Void

    private var host: PlanetHost { system.hosts[hostIndex] }

    var body: some View {
        GeometryReader { proxy in
            track
                .contentShape(Rectangle())
                .onTapGesture { location in
                    if let index = planetIndex(at: location, in: proxy.size) {
                        onSelectPlanet(index)
                    } else if let neighbor = neighborLayouts(in: proxy.size)
                                .first(where: { $0.hitRect.contains(location) }),
                              let target = neighbor.stars.hostIndices.first {
                        onFocusHost(target)
                    }
                }
        }
    }

    static func midY(height: CGFloat) -> CGFloat { height * 0.55 }

    /// Where a planet is drawn; belts span their merged planetoids, at least 16 points wide.
    static func frame(of planet: Planet, in size: CGSize) -> CGRect {
        let x = OrbitScale.x(planet.a, width: size.width)
        let y = midY(height: size.height)
        if let range = planet.beltRange {
            let lo = OrbitScale.x(range.lowerBound, width: size.width)
            let hi = OrbitScale.x(range.upperBound, width: size.width)
            let width = max(hi - lo, 0) + 16
            return CGRect(x: (lo + hi) / 2 - width / 2, y: y - 6, width: width, height: 12)
        }
        // Sized by radius on a square-root scale so giants don't swamp the row.
        let d = 3 + 14 * sqrt(planet.radius / 71_492)
        return CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)
    }

    /// The planet nearest the click, if the click is on (or just around) one.
    private func planetIndex(at location: CGPoint, in size: CGSize) -> Int? {
        let hits = host.planets.indices.compactMap { index -> (index: Int, distance: CGFloat)? in
            let frame = Self.frame(of: host.planets[index], in: size)
            // Pad small bodies so they stay easy to click.
            let target = frame.insetBy(dx: min(frame.width / 2 - 7, 0), dy: min(frame.height / 2 - 7, 0))
            guard target.contains(location) else { return nil }
            return (index, hypot(location.x - frame.midX, location.y - frame.midY))
        }
        return hits.min { $0.distance < $1.distance }?.index
    }

    // MARK: - Neighbouring stars

    /// Geometry of another star (or pair) and the collapsed strips of its planets.
    struct NeighborLayout {
        let stars: NeighborStars
        let center: CGPoint
        let diameter: CGFloat
        let strips: [(hostIndex: Int, rect: CGRect)]
        let hitRect: CGRect
    }

    static let stripWidth: CGFloat = 44
    static let stripLaneHeight: CGFloat = 6

    private func neighborLayouts(in size: CGSize) -> [NeighborLayout] {
        let midY = Self.midY(height: size.height)
        return system.neighbors(ofHost: hostIndex).map { neighbor in
            let stars = neighbor.starIndices.map { system.stars[$0] }
            let diameter = stars.map { min($0.displayDiameter * 0.7, 36) }.max() ?? 10
            let center = CGPoint(x: OrbitScale.x(neighbor.a, width: size.width), y: midY)

            // Collapsed planets sit beside the star, flipping left near the right edge.
            let lanes = neighbor.hostIndices.filter { !system.hosts[$0].planets.isEmpty }
            var stripX = center.x + diameter / 2 + 6
            if stripX + Self.stripWidth > size.width - 2 {
                stripX = center.x - diameter / 2 - 6 - Self.stripWidth
            }
            let top = midY - CGFloat(lanes.count) * Self.stripLaneHeight / 2
            let strips = lanes.enumerated().map { lane, host in
                (hostIndex: host, rect: CGRect(x: stripX, y: top + CGFloat(lane) * Self.stripLaneHeight,
                                              width: Self.stripWidth, height: Self.stripLaneHeight - 1))
            }

            var hitRect = CGRect(x: center.x - diameter / 2, y: midY - diameter / 2,
                                 width: diameter, height: diameter)
            for strip in strips { hitRect = hitRect.union(strip.rect) }
            return NeighborLayout(stars: neighbor, center: center, diameter: diameter,
                                  strips: strips, hitRect: hitRect.insetBy(dx: -4, dy: -4))
        }
    }

    /// A host's planets squeezed into a strip, on a log scale spanning its own planets.
    private func drawCollapsedPlanets(of host: PlanetHost, in rect: CGRect,
                                      context: inout GraphicsContext) {
        context.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2),
                     with: .color(.white.opacity(0.08)))
        let distances = host.planets.map { log10($0.a) }
        guard let lo = distances.min(), let hi = distances.max() else { return }
        for (planet, distance) in zip(host.planets, distances) {
            let fraction = hi > lo ? (distance - lo) / (hi - lo) : 0.5
            let x = rect.minX + 3 + CGFloat(fraction) * (rect.width - 6)
            let d: CGFloat = planet.isGasGiant ? 3.4 : 2.4
            context.fill(Path(ellipseIn: CGRect(x: x - d / 2, y: rect.midY - d / 2, width: d, height: d)),
                         with: .color(planet.kind.color))
        }
    }

    // MARK: - Drawing

    private var track: some View {
        Canvas { context, size in
            let w = size.width
            let midY = Self.midY(height: size.height)

            func horizontal(_ from: Double, _ to: Double) -> Path {
                Path { $0.move(to: CGPoint(x: OrbitScale.x(from, width: w), y: midY))
                       $0.addLine(to: CGPoint(x: OrbitScale.x(to, width: w), y: midY)) }
            }

            // Decade grid lines.
            for au in OrbitScale.decades {
                let x = OrbitScale.x(au, width: w)
                context.stroke(Path { $0.move(to: CGPoint(x: x, y: 0))
                                      $0.addLine(to: CGPoint(x: x, y: size.height)) },
                               with: .color(.white.opacity(0.06)), lineWidth: 1)
            }

            // Orbital plane, from the star out to the last body.
            if let outermost = host.planets.map(\.a).max() {
                context.stroke(horizontal(OrbitScale.range.lowerBound, outermost),
                               with: .color(.white.opacity(0.18)), lineWidth: 1)
            }

            // Belts first, as faint bands with their planetoids, so the habitable zone and
            // planets stay readable on top of wide debris zones.
            for (index, planet) in host.planets.enumerated() where planet.kind == .belt {
                let rect = Self.frame(of: planet, in: size)
                context.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2),
                             with: .color(planet.kind.color.opacity(0.14)))
                drawBelt(in: &context, rect: rect, color: planet.kind.color,
                         seed: system.seed &+ UInt64(hostIndex * 1000 + index))
            }

            // Habitable zone, inner to outer edge. Quiet neutron stars and black holes have none;
            // a pulsar's wind heats a temperate zone (though its radiation rules out life as
            // we know it), and white dwarfs have a small, slowly shrinking one.
            if !system.stars(of: host).contains(where: {
                $0.spectralClass == .neutronStar || $0.spectralClass == .blackHole }) {
                let zone = host.habitableZone
                context.stroke(horizontal(zone.lowerBound, zone.upperBound),
                               with: .color(.green), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }

            // Edges of the dynamically stable region.
            for limit in [host.stableInnerLimit, host.stableOuterLimit].compactMap({ $0 }) {
                let x = OrbitScale.x(limit, width: w)
                context.stroke(Path { $0.move(to: CGPoint(x: x, y: midY - 16))
                                      $0.addLine(to: CGPoint(x: x, y: midY + 16)) },
                               with: .color(.orange.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            }

            // Other stars at their separation, with a bar from periastron to apastron,
            // and their own planets collapsed beside them.
            var labelPositions: [CGFloat] = []
            for layout in neighborLayouts(in: size) {
                let neighbor = layout.stars
                let stars = neighbor.starIndices.map { system.stars[$0] }
                context.stroke(horizontal(neighbor.a * (1 - neighbor.e), neighbor.a * (1 + neighbor.e)),
                               with: .color(stars[0].color.opacity(0.45)),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round))
                drawStars(stars, at: layout.center, scale: 0.7, maxDiameter: 36, in: &context)
                for strip in layout.strips {
                    drawCollapsedPlanets(of: system.hosts[strip.hostIndex], in: strip.rect, context: &context)
                }
                let names = stars.map(\.designation).joined(separator: " + ")
                // Stagger labels of companions close together, e.g. both pinned at the right edge.
                let labelX = min(max(layout.center.x, 40), w - 40)
                let overlaps = labelPositions.filter { abs($0 - labelX) < 80 }.count
                labelPositions.append(labelX)
                context.draw(Text("\(names)  \(OrbitScale.label(neighbor.a))")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.7)),
                             at: CGPoint(x: labelX, y: size.height - 7 - CGFloat(overlaps) * 11))
            }

            for (index, planet) in host.planets.enumerated() {
                let kind = planet.kind
                let rect = Self.frame(of: planet, in: size)
                if kind == .belt {
                    // Drawn above; a selected belt gets an outline instead of a ring.
                    if selectedIndex == index {
                        context.stroke(Path(roundedRect: rect.insetBy(dx: -3, dy: -3), cornerRadius: 9),
                                       with: .color(.white), lineWidth: 1.5)
                    }
                    continue
                }
                context.fill(Path(ellipseIn: rect), with: .color(kind.color))
                context.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.4)), lineWidth: 0.5)
                if system.isPotentiallyHabitable(planet, in: host) {
                    let halo = max(rect.width, rect.height) + 5
                    context.stroke(Path(ellipseIn: CGRect(x: rect.midX - halo / 2, y: rect.midY - halo / 2,
                                                          width: halo, height: halo)),
                                   with: .color(.green), lineWidth: 1.5)
                }
                if selectedIndex == index {
                    let ring = max(rect.width, rect.height) + 8
                    context.stroke(Path(ellipseIn: CGRect(x: rect.midX - ring / 2, y: rect.midY - ring / 2,
                                                          width: ring, height: ring)),
                                   with: .color(.white), lineWidth: 1.5)
                }
            }
        }
    }

    /// A scatter of planetoids filling the belt's span, jittered deterministically from the seed.
    private func drawBelt(in context: inout GraphicsContext, rect: CGRect,
                          color: Color, seed: UInt64) {
        var rng = SplitMix64(seed: seed)
        let count = 12 + Int(rect.width / 6)
        for _ in 0..<count {
            let x = CGFloat.random(in: rect.minX + 1...rect.maxX - 1, using: &rng)
            let y = CGFloat.random(in: rect.minY + 1...rect.maxY - 1, using: &rng)
            let d = CGFloat.random(in: 1.2...2.4, using: &rng)
            context.fill(Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)),
                         with: .color(color))
        }
    }
}

/// AU labels aligned with the rows' distance axis.
struct OrbitAxis: View {
    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: OrbitScale.starColumnWidth)
            GeometryReader { proxy in
                ForEach(OrbitScale.decades, id: \.self) { au in
                    Text(OrbitScale.label(au))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .position(x: OrbitScale.x(au, width: proxy.size.width),
                                  y: proxy.size.height / 2)
                }
            }
        }
        .frame(height: 18)
    }
}
