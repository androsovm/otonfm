//
//  Oton_FMApp.swift
//  Oton.FM
//
//  Created by Yuri on 23/04/2025.
//

import SwiftUI
import UIKit

@main
struct OtonFMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isSplashActive = true

    var body: some Scene {
        WindowGroup {
            if isSplashActive {
                SplashView(isActive: $isSplashActive)
            } else {
                ContentView()
            }
        }
    }
}
