//
//  ContentView.swift
//  CoatCast
//
//  RootView: the app's phase machine. Splash → (first launch ? Onboarding :
//  Main). The onboarding flag is persisted so it is shown only once.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var clock: Clock
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private enum Phase { case splash, onboarding, main }
    @State private var phase: Phase = .splash

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        phase = hasCompletedOnboarding ? .main : .onboarding
                    }
                }
                .transition(.opacity)

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
        .onAppear { clock.start() }
    }
}
