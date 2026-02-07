import SwiftUI

/// Animated falling snow — gentle snowflakes drifting down with soft wind.
struct FallingSnowView: View {

    private struct Snowflake {
        let baseX: CGFloat
        let size: CGFloat
        let speed: Double
        let opacity: CGFloat
        let swayAmount: CGFloat
        let swaySpeed: Double
        let phase: Double
    }

    @State private var snowflakes: [Snowflake] = (0..<60).map { i in
        let category = i % 3
        let size: CGFloat
        let speed: Double
        let opacity: CGFloat

        switch category {
        case 0:
            size = CGFloat.random(in: 2...3)
            speed = Double.random(in: 18...25)
            opacity = CGFloat.random(in: 0.25...0.45)
        case 1:
            size = CGFloat.random(in: 3...4.5)
            speed = Double.random(in: 12...18)
            opacity = CGFloat.random(in: 0.4...0.6)
        default:
            size = CGFloat.random(in: 5...6)
            speed = Double.random(in: 8...12)
            opacity = CGFloat.random(in: 0.5...0.75)
        }

        return Snowflake(
            baseX: CGFloat.random(in: 0...1),
            size: size,
            speed: speed,
            opacity: opacity,
            swayAmount: CGFloat.random(in: 10...25),
            swaySpeed: Double.random(in: 3...7),
            phase: Double(i) * 1.1
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                // Global wind direction shifts over time
                let wind = sin(t * (.pi * 2) / 20.0) * 15.0

                for flake in snowflakes {
                    let cycleTime = (t + flake.phase).truncatingRemainder(dividingBy: flake.speed)
                    let progress = cycleTime / flake.speed

                    let y = size.height * CGFloat(progress)
                    let sway = sin(t * (.pi * 2) / flake.swaySpeed + flake.phase * 2) * flake.swayAmount
                    let x = flake.baseX * size.width + sway + CGFloat(wind)

                    context.opacity = Double(flake.opacity)

                    let rect = CGRect(
                        x: x - flake.size / 2,
                        y: y - flake.size / 2,
                        width: flake.size,
                        height: flake.size
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
    }
}
