//
//  CustomTabBar.swift
//  CoatCast
//
//  Enum-driven custom tab bar (a plain TabView can't hide its bar reliably on
//  iOS 14). Blur background, spring selection animation, per-tab badges.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case studio, schedule, stock, capture, settings
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .studio: return "Studio"
        case .schedule: return "Schedule"
        case .stock: return "Stock"
        case .capture: return "Capture"
        case .settings: return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .studio: return "paintbrush.fill"
        case .schedule: return "timer"
        case .stock: return "shippingbox.fill"
        case .capture: return "camera.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selection: AppTab
    var scheduleBadge: Int = 0
    var captureBadge: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { selection = tab }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            if selection == tab {
                                Circle().fill(Theme.accent.opacity(0.16)).frame(width: 38, height: 38)
                            }
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(selection == tab ? Theme.accentActive : Theme.textInactive)
                                .scaleEffect(selection == tab ? 1.08 : 1.0)
                            if badge(for: tab) > 0 {
                                Text("\(badge(for: tab))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(tab == .schedule ? Theme.drying : Theme.defect))
                                    .offset(x: 13, y: -11)
                            }
                        }
                        .frame(height: 38)
                        Text(tab.title)
                            .font(.system(size: 10, weight: selection == tab ? .bold : .medium, design: .rounded))
                            .foregroundColor(selection == tab ? Theme.accentActive : Theme.textInactive)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 10).padding(.bottom, 4).padding(.horizontal, 6)
        .background(
            ZStack {
                BlurView(style: .systemThinMaterial)
                Theme.surface.opacity(0.6)
            }
            .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .top)
            .edgesIgnoringSafeArea(.bottom)
        )
    }

    private func badge(for tab: AppTab) -> Int {
        switch tab {
        case .schedule: return scheduleBadge
        case .capture: return captureBadge
        default: return 0
        }
    }
}
