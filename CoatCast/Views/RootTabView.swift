//
//  RootTabView.swift
//  CoatCast
//
//  The main shell: five tabs, each its own NavigationView stack (iOS 14 safe),
//  with the custom tab bar overlaid. Drives the per-second reconcile that flips
//  finished drying coats to "done".
//

import SwiftUI

struct RootTabView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var clock: Clock
    @State private var tab: AppTab = .studio

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .studio:   navStack { StudioHomeView() }
                case .schedule: navStack { ScheduleHomeView() }
                case .stock:    navStack { StockHomeView() }
                case .capture:  navStack { CaptureHomeView() }
                case .settings: navStack { SettingsView() }
                }
            }
            CustomTabBar(selection: $tab,
                         scheduleBadge: store.dryingCount(asOf: clock.now),
                         captureBadge: store.openDefectCount)
        }
        .onReceive(clock.$now) { store.reconcile(asOf: $0) }
        .onAppear { store.reconcile(asOf: Date()) }
    }

    private func navStack<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        NavigationView { content() }
            .navigationViewStyle(StackNavigationViewStyle())
    }
}
