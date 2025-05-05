import UIKit
import RevenueCat

// Ключи для UserDefaults
enum UserDefaultsKeys {
    static let firstLaunchDate = "firstLaunchDate"
    static let lastPaywallDisplayDate = "lastPaywallDisplayDate"
    static let testMode = "paywallTestMode" // Ключ для режима тестирования
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Здесь можно выполнять дополнительную настройку приложения при запуске
        
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey:"appl_SUEUYjngtLhXGzXaOeHnovfAmfS")
        
        // Проверяем и сохраняем дату первого запуска
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.firstLaunchDate) == nil {
            UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.firstLaunchDate)
            print("Первый запуск приложения: дата сохранена")
        }
        
        print("AppDelegate: didFinishLaunchingWithOptions")
        return true
    }
    
    // Можно добавить другие методы делегата по необходимости
}

// Расширение для работы с датами использования приложения
extension AppDelegate {
    static func daysSinceFirstLaunch() -> Int {
        guard let firstLaunchDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.firstLaunchDate) as? Date else {
            // Если дата не найдена, сохраняем текущую и возвращаем 0
            UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.firstLaunchDate)
            return 0
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: firstLaunchDate, to: Date())
        return components.day ?? 0
    }
    
    static func shouldShowPaywall() -> Bool {
        // Проверка режима тестирования (если включен - всегда показываем paywall)
        if UserDefaults.standard.bool(forKey: UserDefaultsKeys.testMode) {
            print("🧪 Режим тестирования paywall активен")
            return true
        }
        
        let days = daysSinceFirstLaunch()
        let targetDays = [3, 6, 15]
        
        // Проверяем, является ли текущий день одним из целевых
        if targetDays.contains(days) {
            // Проверяем, показывали ли мы paywall сегодня
            if let lastDisplayDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastPaywallDisplayDate) as? Date {
                let calendar = Calendar.current
                return !calendar.isDateInToday(lastDisplayDate)
            }
            return true
        }
        return false
    }
    
    // Методы для управления режимом тестирования
    static func enablePaywallTestMode() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.testMode)
        print("🧪 Режим тестирования paywall включен")
    }
    
    static func disablePaywallTestMode() {
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.testMode)
        print("🧪 Режим тестирования paywall выключен")
    }
    
    static func isPaywallTestModeEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: UserDefaultsKeys.testMode)
    }
    
    static func markPaywallAsDisplayed() {
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.lastPaywallDisplayDate)
    }
}
