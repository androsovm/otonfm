import SwiftUI
import UIKit

struct YakutiaGradient {
    let topColor: UIColor
    let bottomColor: UIColor
    let name: String
    let description: String
}

class YakutiaGradients {
    static let shared = YakutiaGradients()
    
    let gradients: [YakutiaGradient] = [
        YakutiaGradient(topColor: UIColor(red: 0.15, green: 0.30, blue: 0.70, alpha: 1.0), bottomColor: UIColor(red: 0.40, green: 0.18, blue: 0.50, alpha: 1.0), name: "northernLights", description: "Северное сияние над Якутией"),
        YakutiaGradient(topColor: UIColor(red: 0.95, green: 0.48, blue: 0.22, alpha: 1.0), bottomColor: UIColor(red: 0.30, green: 0.12, blue: 0.30, alpha: 1.0), name: "yakutskSunset", description: "Закат над Якутском"),
        YakutiaGradient(topColor: UIColor(red: 0.22, green: 0.15, blue: 0.35, alpha: 1.0), bottomColor: UIColor(red: 0.40, green: 0.25, blue: 0.48, alpha: 1.0), name: "forestTwilight", description: "Сумерки в якутской тайге"),
        YakutiaGradient(topColor: UIColor(red: 0.50, green: 0.68, blue: 0.85, alpha: 1.0), bottomColor: UIColor(red: 0.15, green: 0.35, blue: 0.60, alpha: 1.0), name: "lenaSunrise", description: "Рассвет над рекой Лена"),
        YakutiaGradient(topColor: UIColor(red: 0.12, green: 0.15, blue: 0.28, alpha: 1.0), bottomColor: UIColor(red: 0.22, green: 0.26, blue: 0.40, alpha: 1.0), name: "frozenLena", description: "Зимняя Лена в сумерках"),
        YakutiaGradient(topColor: UIColor(red: 0.35, green: 0.14, blue: 0.50, alpha: 1.0), bottomColor: UIColor(red: 0.65, green: 0.15, blue: 0.40, alpha: 1.0), name: "yakutianGems", description: "Самоцветы Якутии"),
        YakutiaGradient(topColor: UIColor(red: 0.85, green: 0.60, blue: 0.30, alpha: 1.0), bottomColor: UIColor(red: 0.50, green: 0.20, blue: 0.15, alpha: 1.0), name: "summerEvening", description: "Летний вечер в Якутии"),
        YakutiaGradient(topColor: UIColor(red: 0.20, green: 0.10, blue: 0.40, alpha: 1.0), bottomColor: UIColor(red: 0.40, green: 0.20, blue: 0.60, alpha: 1.0), name: "polarStar", description: "Полярная звезда в ясную ночь"),
        YakutiaGradient(topColor: UIColor(red: 0.85, green: 0.90, blue: 0.95, alpha: 1.0), bottomColor: UIColor(red: 0.60, green: 0.75, blue: 0.90, alpha: 1.0), name: "winterMorning", description: "Зимнее утро в Якутии"),
        YakutiaGradient(topColor: UIColor(red: 0.28, green: 0.20, blue: 0.35, alpha: 1.0), bottomColor: UIColor(red: 0.45, green: 0.15, blue: 0.50, alpha: 1.0), name: "purpleEvening", description: "Лиловый вечер на Лене"),
        YakutiaGradient(topColor: UIColor(red: 0.25, green: 0.20, blue: 0.30, alpha: 1.0), bottomColor: UIColor(red: 0.40, green: 0.30, blue: 0.45, alpha: 1.0), name: "ancientLegends", description: "Древние легенды якутов"),
        YakutiaGradient(topColor: UIColor(red: 0.95, green: 0.52, blue: 0.20, alpha: 1.0), bottomColor: UIColor(red: 0.60, green: 0.20, blue: 0.05, alpha: 1.0), name: "amberSunset", description: "Янтарный закат над тундрой"),
        YakutiaGradient(topColor: UIColor(red: 0.15, green: 0.25, blue: 0.35, alpha: 1.0), bottomColor: UIColor(red: 0.30, green: 0.40, blue: 0.45, alpha: 1.0), name: "winterTaiga", description: "Зимняя тайга в снегу"),
        YakutiaGradient(topColor: UIColor(red: 0.30, green: 0.20, blue: 0.50, alpha: 1.0), bottomColor: UIColor(red: 0.50, green: 0.30, blue: 0.65, alpha: 1.0), name: "yakutianCrystals", description: "Кристаллы якутского льда"),
        YakutiaGradient(topColor: UIColor(red: 0.12, green: 0.15, blue: 0.45, alpha: 1.0), bottomColor: UIColor(red: 0.25, green: 0.10, blue: 0.55, alpha: 1.0), name: "starryNight", description: "Звездное небо Якутии"),
        YakutiaGradient(topColor: UIColor(red: 0.85, green: 0.65, blue: 0.85, alpha: 1.0), bottomColor: UIColor(red: 0.50, green: 0.25, blue: 0.65, alpha: 1.0), name: "springBloom", description: "Цветение весны в долине Туймаада"),
        YakutiaGradient(topColor: UIColor(red: 0.35, green: 0.10, blue: 0.40, alpha: 1.0), bottomColor: UIColor(red: 0.50, green: 0.15, blue: 0.55, alpha: 1.0), name: "olonkhoNight", description: "Ночь Эпоса Олонхо"),
        YakutiaGradient(topColor: UIColor(red: 0.20, green: 0.30, blue: 0.50, alpha: 1.0), bottomColor: UIColor(red: 0.35, green: 0.45, blue: 0.60, alpha: 1.0), name: "diamondSky", description: "Алмазное небо Якутии"),
        YakutiaGradient(topColor: UIColor(red: 0.20, green: 0.40, blue: 0.35, alpha: 1.0), bottomColor: UIColor(red: 0.35, green: 0.55, blue: 0.45, alpha: 1.0), name: "tundraSummer", description: "Летняя тундра в цвету"),
        YakutiaGradient(topColor: UIColor(red: 0.70, green: 0.20, blue: 0.10, alpha: 1.0), bottomColor: UIColor(red: 0.90, green: 0.60, blue: 0.30, alpha: 1.0), name: "autumnColors", description: "Осенние краски Якутии"),
        
        // Яркие летние градиенты Якутии
        YakutiaGradient(topColor: UIColor(red: 0.10, green: 0.75, blue: 0.45, alpha: 1.0), bottomColor: UIColor(red: 0.60, green: 0.95, blue: 0.20, alpha: 1.0), name: "yakutianMeadow", description: "Якутский луг в разгар лета"),
        YakutiaGradient(topColor: UIColor(red: 0.95, green: 0.78, blue: 0.20, alpha: 1.0), bottomColor: UIColor(red: 0.98, green: 0.50, blue: 0.30, alpha: 1.0), name: "midnightSun", description: "Полуночное солнце в Якутии"),
        YakutiaGradient(topColor: UIColor(red: 0.20, green: 0.80, blue: 0.90, alpha: 1.0), bottomColor: UIColor(red: 0.10, green: 0.45, blue: 0.80, alpha: 1.0), name: "yakutianLakes", description: "Голубые озёра Якутии"),
        YakutiaGradient(topColor: UIColor(red: 0.95, green: 0.25, blue: 0.45, alpha: 1.0), bottomColor: UIColor(red: 0.98, green: 0.60, blue: 0.15, alpha: 1.0), name: "yakutianFlowers", description: "Яркие цветы якутской тундры"),
        YakutiaGradient(topColor: UIColor(red: 0.70, green: 0.95, blue: 0.55, alpha: 1.0), bottomColor: UIColor(red: 0.15, green: 0.65, blue: 0.30, alpha: 1.0), name: "ysyakhCelebration", description: "Праздник Ысыах в разгар лета")
    ]
    
    private init() {}
}