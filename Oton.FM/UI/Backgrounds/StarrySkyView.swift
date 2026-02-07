import SwiftUI

/// Animated starry sky with twinkling stars and the Big Dipper constellation.
struct StarrySkyView: View {

    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let brightness: CGFloat
        let speed: Double
        let phase: Double
    }

    // Big Dipper (Большая Медведица) — 7 stars in normalized coordinates
    private static let bigDipper: [(x: CGFloat, y: CGFloat, size: CGFloat, name: String)] = [
        (0.20, 0.13, 3.0, "Alkaid"),
        (0.29, 0.10, 3.2, "Mizar"),
        (0.38, 0.11, 3.0, "Alioth"),
        (0.46, 0.15, 2.8, "Megrez"),
        (0.74, 0.14, 3.5, "Dubhe"),
        (0.76, 0.23, 3.2, "Merak"),
        (0.43, 0.23, 3.0, "Phecda"),
    ]

    // Connections: handle (0-1-2-3), bowl (3-4-5-6-3)
    private static let bigDipperLines: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3),
        (3, 4), (4, 5), (5, 6), (6, 3),
    ]

    @State private var stars: [Star] = {
        // Background stars — varied sizes with more small dim stars for depth
        var result: [Star] = (0..<120).map { _ in
            let isBright = Double.random(in: 0...1) < 0.15
            return Star(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: isBright ? CGFloat.random(in: 2...3.5) : CGFloat.random(in: 0.8...2),
                brightness: isBright ? CGFloat.random(in: 0.6...1.0) : CGFloat.random(in: 0.3...0.7),
                speed: Double.random(in: 2...8),
                phase: Double.random(in: 0...(2 * .pi))
            )
        }

        // Big Dipper constellation stars — brighter, steadier
        for c in bigDipper {
            result.append(Star(
                x: c.x,
                y: c.y,
                size: c.size,
                brightness: 0.95,
                speed: Double.random(in: 8...14),
                phase: Double.random(in: 0...(2 * .pi))
            ))
        }

        return result
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                // Draw all background stars
                let constellationStart = stars.count - Self.bigDipper.count
                for (i, star) in stars.enumerated() {
                    let twinkle = 0.5 + 0.5 * sin(t * (.pi * 2) / star.speed + star.phase)
                    let alpha = Double(star.brightness) * twinkle

                    let cx = star.x * size.width
                    let cy = star.y * size.height

                    // Subtle glow for constellation stars
                    if i >= constellationStart {
                        context.opacity = alpha * 0.2
                        let glowSize = star.size * 4
                        let glowRect = CGRect(
                            x: cx - glowSize / 2,
                            y: cy - glowSize / 2,
                            width: glowSize,
                            height: glowSize
                        )
                        context.fill(
                            Path(ellipseIn: glowRect),
                            with: .color(.white.opacity(0.5))
                        )
                    }

                    context.opacity = alpha
                    let rect = CGRect(
                        x: cx - star.size / 2,
                        y: cy - star.size / 2,
                        width: star.size,
                        height: star.size
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }

                // Draw constellation lines
                let constellationStars = Self.bigDipper
                let lineAlpha = 0.5 + 0.5 * sin(t * (.pi * 2) / 10.0)
                context.opacity = 0.12 * lineAlpha

                for (from, to) in Self.bigDipperLines {
                    let s = constellationStars[from]
                    let e = constellationStars[to]
                    var path = Path()
                    path.move(to: CGPoint(x: s.x * size.width, y: s.y * size.height))
                    path.addLine(to: CGPoint(x: e.x * size.width, y: e.y * size.height))
                    context.stroke(path, with: .color(.white), lineWidth: 0.5)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
