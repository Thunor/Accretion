//
//  SystemRow.swift
//  AccretionApp
//
//  One star system: the star (or close pair) the planets orbit on the left,
//  its bodies and any companion stars laid out to the right on a
//  logarithmic distance axis.
//

import SwiftUI

/// Logarithmic AU axis shared by the rows and the header so they line up.
enum OrbitScale {
    static let range = 0.01...1000.0
    static let decades: [Double] = [0.01, 0.1, 1, 10, 100, 1000]
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
        case ..<1: String(format: "%.2g AU", au)
        case ..<10: String(format: "%.1f AU", au)
        case ..<1000: String(format: "%.0f AU", au)
        default: String(format: "%.1fk AU", au / 1000)
        }
    }
}

/// Draws a star as a bright disc with a soft glow in its color.
func drawStar(_ star: Star, at center: CGPoint, diameter: CGFloat, in context: inout GraphicsContext) {
    let color = star.color
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

struct SystemRow: View {
    let system: StarSystem

    var body: some View {
        HStack(spacing: 0) {
            HostStarsView(system: system)
                .frame(width: OrbitScale.starColumnWidth)
            OrbitTrack(system: system)
                .overlay(alignment: .topLeading) {
                    Text(caption)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.leading, OrbitScale.inset)
                        .padding(.top, 3)
                }
        }
        .frame(height: OrbitScale.rowHeight)
    }

    private var caption: String {
        let stars = system.stars.map(\.designation).joined(separator: " + ")
        let bodies = switch system.planets.count {
        case 0: "no stable planets"
        case 1: "1 body"
        case let n: "\(n) bodies"
        }
        return String(format: "%@  ·  %@  ·  host %.2f M☉ %.3g L☉  ·  %@  ·  seed %llu",
                      stars, system.configurationLabel, system.stellarMass,
                      system.stellarLuminosity, bodies, system.seed)
    }
}

/// The star the planets orbit, or both stars of a close circumbinary pair.
struct HostStarsView: View {
    let system: StarSystem

    var body: some View {
        let hosts = system.hostStars
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            if hosts.count == 2 {
                // Close pair: partner behind and offset, both slightly reduced to fit.
                let primary = hosts[0].displayDiameter * 0.8
                let partner = hosts[1].displayDiameter * 0.8
                drawStar(hosts[1], at: CGPoint(x: center.x + primary * 0.35, y: center.y + primary * 0.2),
                         diameter: partner, in: &context)
                drawStar(hosts[0], at: CGPoint(x: center.x - partner * 0.3, y: center.y - partner * 0.15),
                         diameter: primary, in: &context)
            } else {
                drawStar(hosts[0], at: center, diameter: hosts[0].displayDiameter, in: &context)
            }
        }
        .help(hosts.map { star in
            String(format: "%@: %.2f M☉, %.2f R☉, %.0f K",
                   star.designation, star.mass, star.radius, star.temperature)
        }.joined(separator: "\n"))
    }
}

/// Orbits, habitable zone, stability limits, companions and bodies, drawn in a
/// single Canvas so 1000 rows stay cheap.
struct OrbitTrack: View {
    let system: StarSystem

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let midY = size.height * 0.55

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
            if let outermost = system.planets.map(\.a).max() {
                context.stroke(horizontal(OrbitScale.range.lowerBound, outermost),
                               with: .color(.white.opacity(0.18)), lineWidth: 1)
            }

            // Habitable zone, inner to outer edge.
            let zone = system.habitableZone
            context.stroke(horizontal(zone.lowerBound, zone.upperBound),
                           with: .color(.green), style: StrokeStyle(lineWidth: 3, lineCap: .round))

            // Edges of the dynamically stable region.
            for limit in [system.stableInnerLimit, system.stableOuterLimit].compactMap({ $0 }) {
                let x = OrbitScale.x(limit, width: w)
                context.stroke(Path { $0.move(to: CGPoint(x: x, y: midY - 16))
                                      $0.addLine(to: CGPoint(x: x, y: midY + 16)) },
                               with: .color(.orange.opacity(0.8)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            }

            // Companion stars at their separation, with a bar from periastron to apastron.
            for companion in system.outerCompanions {
                let star = companion.star
                context.stroke(horizontal(companion.periastron, companion.apastron),
                               with: .color(star.color.opacity(0.45)),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round))
                let x = OrbitScale.x(companion.a, width: w)
                drawStar(star, at: CGPoint(x: x, y: midY),
                         diameter: min(star.displayDiameter * 0.7, 36), in: &context)
                context.draw(Text("\(star.designation)  \(OrbitScale.label(companion.a))")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.7)),
                             at: CGPoint(x: min(x, w - 40), y: size.height - 7))
            }

            for (index, planet) in system.planets.enumerated() {
                let kind = planet.kind
                let x = OrbitScale.x(planet.a, width: w)
                if kind == .belt {
                    drawBelt(in: &context, x: x, y: midY, color: kind.color,
                             seed: system.seed &+ UInt64(index))
                } else {
                    // Sized by radius on a square-root scale so giants don't swamp the row.
                    let d = 3 + 14 * sqrt(planet.radius / 71_492)
                    let rect = CGRect(x: x - d / 2, y: midY - d / 2, width: d, height: d)
                    context.fill(Path(ellipseIn: rect), with: .color(kind.color))
                    context.stroke(Path(ellipseIn: rect), with: .color(.black.opacity(0.4)), lineWidth: 0.5)
                }
            }
        }
    }

    /// A scatter of planetoids, jittered deterministically from the system seed.
    private func drawBelt(in context: inout GraphicsContext, x: CGFloat, y: CGFloat,
                          color: Color, seed: UInt64) {
        var rng = SplitMix64(seed: seed)
        for _ in 0..<14 {
            let dx = CGFloat.random(in: -7...7, using: &rng)
            let dy = CGFloat.random(in: -5...5, using: &rng)
            let d = CGFloat.random(in: 1.2...2.4, using: &rng)
            context.fill(Path(ellipseIn: CGRect(x: x + dx - d / 2, y: y + dy - d / 2,
                                                width: d, height: d)),
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
