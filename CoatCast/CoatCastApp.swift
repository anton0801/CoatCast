//
//  CoatCastApp.swift
//  CoatCast
//
//  App entry point. Injects the AppStore, NotificationManager and shared Clock,
//  applies the persisted appearance (theme) app-wide, and flushes data to disk
//  when leaving the foreground.
//

import SwiftUI

// App-wide theme selection (persisted via @AppStorage("appearance")).
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct CoatCastApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegateApplicatioIn

    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
}
