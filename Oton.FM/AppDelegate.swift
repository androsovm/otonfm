import UIKit
import RevenueCat

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Здесь можно выполнять дополнительную настройку приложения при запуске
        
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey:"appl_SUEUYjngtLhXGzXaOeHnovfAmfS")
        
        print("AppDelegate: didFinishLaunchingWithOptions")
        return true
    }
    // Можно добавить другие методы делегата по необходимости
} 
