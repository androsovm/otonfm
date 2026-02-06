import SwiftUI
import UIKit

/// Animation type for gradient backgrounds.
enum BackgroundAnimationType: Sendable, Equatable {
    case stars
    case snow
}

/// A single themed gradient inspired by the nature and culture of Yakutia.
struct YakutiaGradient: Sendable {
    let topColor: UIColor
    let bottomColor: UIColor
    let name: String
    let description: String
    let animation: BackgroundAnimationType?
}

/// Yakutia-themed gradients collection.
enum YakutiaGradients {

    /// The complete collection of Yakutia-themed gradients.
    static let all: [YakutiaGradient] = [

        // ── Summer / Warm (no animation) ──────────────────────────

        // #0 — Тёплый закат
        YakutiaGradient(
            topColor: UIColor(red: 0.90, green: 0.50, blue: 0.25, alpha: 1.0),
            bottomColor: UIColor(red: 0.40, green: 0.18, blue: 0.12, alpha: 1.0),
            name: "warmSunset",
            description: "Тёплый закат над Туймаадой",
            animation: nil
        ),
        // #1 — Янтарное золото
        YakutiaGradient(
            topColor: UIColor(red: 0.88, green: 0.65, blue: 0.28, alpha: 1.0),
            bottomColor: UIColor(red: 0.40, green: 0.22, blue: 0.10, alpha: 1.0),
            name: "amberGold",
            description: "Янтарное золото Якутии",
            animation: nil
        ),
        // #2 — Костёр на Лене
        YakutiaGradient(
            topColor: UIColor(red: 0.92, green: 0.48, blue: 0.18, alpha: 1.0),
            bottomColor: UIColor(red: 0.45, green: 0.18, blue: 0.10, alpha: 1.0),
            name: "lenaFireside",
            description: "Костёр на берегу Лены",
            animation: nil
        ),
        // #3 — Ысыах: золотое солнце
        YakutiaGradient(
            topColor: UIColor(red: 0.85, green: 0.68, blue: 0.30, alpha: 1.0),
            bottomColor: UIColor(red: 0.42, green: 0.25, blue: 0.12, alpha: 1.0),
            name: "ysyakhSun",
            description: "Ысыах — золотое солнце лета",
            animation: nil
        ),
        // #4 — Алаас: яркая зелень якутских лугов
        YakutiaGradient(
            topColor: UIColor(red: 0.45, green: 0.78, blue: 0.40, alpha: 1.0),
            bottomColor: UIColor(red: 0.20, green: 0.35, blue: 0.16, alpha: 1.0),
            name: "alaas",
            description: "Алаас — зелёные луга Якутии",
            animation: nil
        ),
        // #5 — Ысыах луг: солнечная зелень летнего праздника
        YakutiaGradient(
            topColor: UIColor(red: 0.70, green: 0.82, blue: 0.32, alpha: 1.0),
            bottomColor: UIColor(red: 0.32, green: 0.38, blue: 0.12, alpha: 1.0),
            name: "ysyakhMeadow",
            description: "Ысыах — солнечный луг праздника",
            animation: nil
        ),
        // #6 — Кумыс: сливочное тепло
        YakutiaGradient(
            topColor: UIColor(red: 0.78, green: 0.62, blue: 0.42, alpha: 1.0),
            bottomColor: UIColor(red: 0.35, green: 0.22, blue: 0.15, alpha: 1.0),
            name: "kumysCream",
            description: "Кумыс — сливочное тепло",
            animation: nil
        ),
        // #7 — Осенняя лиственница
        YakutiaGradient(
            topColor: UIColor(red: 0.78, green: 0.50, blue: 0.22, alpha: 1.0),
            bottomColor: UIColor(red: 0.35, green: 0.18, blue: 0.10, alpha: 1.0),
            name: "autumnLarch",
            description: "Осенняя лиственница в золоте",
            animation: nil
        ),
        // #8 — Розовый рассвет
        YakutiaGradient(
            topColor: UIColor(red: 0.85, green: 0.50, blue: 0.55, alpha: 1.0),
            bottomColor: UIColor(red: 0.38, green: 0.18, blue: 0.25, alpha: 1.0),
            name: "pinkDawn",
            description: "Розовый рассвет над тайгой",
            animation: nil
        ),

        // ── Winter (snow) ─────────────────────────────────────────

        // #9 — Морозное утро: свежесть зимнего рассвета
        YakutiaGradient(
            topColor: UIColor(red: 0.55, green: 0.65, blue: 0.78, alpha: 1.0),
            bottomColor: UIColor(red: 0.20, green: 0.25, blue: 0.38, alpha: 1.0),
            name: "frostyMorning",
            description: "Морозное утро в Якутии",
            animation: .snow
        ),
        // #10 — Голубой лёд: прозрачность зимней реки
        YakutiaGradient(
            topColor: UIColor(red: 0.48, green: 0.62, blue: 0.72, alpha: 1.0),
            bottomColor: UIColor(red: 0.18, green: 0.22, blue: 0.35, alpha: 1.0),
            name: "blueIce",
            description: "Голубой лёд реки Лены",
            animation: .snow
        ),

        // ── Night (stars) ─────────────────────────────────────────

        // #11 — Северное сияние
        YakutiaGradient(
            topColor: UIColor(red: 0.35, green: 0.60, blue: 0.58, alpha: 1.0),
            bottomColor: UIColor(red: 0.15, green: 0.25, blue: 0.35, alpha: 1.0),
            name: "softAurora",
            description: "Мягкое северное сияние",
            animation: .stars
        ),
        // #12 — Лиловый вечер
        YakutiaGradient(
            topColor: UIColor(red: 0.62, green: 0.42, blue: 0.65, alpha: 1.0),
            bottomColor: UIColor(red: 0.28, green: 0.15, blue: 0.32, alpha: 1.0),
            name: "lilacEvening",
            description: "Лиловый вечер над Леной",
            animation: .stars
        ),
        // #13 — Полярная заря
        YakutiaGradient(
            topColor: UIColor(red: 0.55, green: 0.48, blue: 0.68, alpha: 1.0),
            bottomColor: UIColor(red: 0.22, green: 0.18, blue: 0.35, alpha: 1.0),
            name: "polarDawn",
            description: "Полярная заря — лавандовый рассвет",
            animation: .stars
        ),
    ]

    /// Total number of gradients.
    static let count = all.count

    /// Linear interpolation between two UIColors by factor t in [0, 1].
    static func lerpColor(_ from: UIColor, _ to: UIColor, t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }
}
