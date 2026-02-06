import SwiftUI

/// Animated starry sky with gently twinkling stars.
struct StarrySkyView: View {

    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let brightness: CGFloat
        let speed: Double
        let phase: Double
    }

    @State private var stars: [Star] = (0..<50).map { _ in
        Star(
            x: CGFloat.random(in: 0...1),
            y: CGFloat.random(in: 0...1),
            size: CGFloat.random(in: 1...3),
            brightness: CGFloat.random(in: 0.4...1.0),
            speed: Double.random(in: 2...6),
            phase: Double.random(in: 0...(2 * .pi))
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                for star in stars {
                    let twinkle = 0.5 + 0.5 * sin(t * (.pi * 2) / star.speed + star.phase)
                    context.opacity = Double(star.brightness) * twinkle

                    let rect = CGRect(
                        x: star.x * size.width - star.size / 2,
                        y: star.y * size.height - star.size / 2,
                        width: star.size,
                        height: star.size
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
