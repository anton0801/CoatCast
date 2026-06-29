//
//  ContentView.swift
//  CoatCast
//
//  RootView: the app's phase machine. Splash → (first launch ? Onboarding :
//  Main). The onboarding flag is persisted so it is shown only once.
//

import SwiftUI

struct RootView: View {
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @StateObject private var store = AppStore()
    @StateObject private var notifications = NotificationManager.shared
    @StateObject private var clock = Clock()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearanceRaw = AppAppearance.system.rawValue

    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .system }

    private enum Phase { case onboarding, main }
    @State private var phase: Phase = .main

    var body: some View {
        ZStack {
            switch phase {
            case .onboarding:
                OnboardingView {
                    hasCompletedOnboarding = true
                    withAnimation(.easeInOut(duration: 0.5)) { phase = .main }
                }
                .transition(.opacity)

            case .main:
                RootTabView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            clock.start()
            if !hasCompletedOnboarding {
                phase = .onboarding
            }
        }
        .environmentObject(store)
        .environmentObject(notifications)
        .environmentObject(clock)
        .preferredColorScheme(appearance.colorScheme)
        .accentColor(Theme.accent)
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                clock.start()
                notifications.refreshAuthorization()
                store.reconcile(asOf: Date())
            case .background, .inactive:
                store.flush()
                clock.stop()
            @unknown default:
                break
            }
        }
    }
}
