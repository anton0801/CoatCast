//
//  HistoryView.swift
//  CoatCast
//
//  Feature 13 (History): a chronological log of painted / dried / fixed events,
//  filterable by kind.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var filter: HistoryKind? = nil

    private var entries: [HistoryEntry] {
        guard let f = filter else { return store.history }
        return store.history.filter { $0.kind == f }
    }

    var body: some View {
        ScreenScaffold("History", subtitle: "Everything you've done") {
            VStack(spacing: Theme.Space.m) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(title: "All", isSelected: filter == nil) { filter = nil }
                        ForEach(HistoryKind.allCases) { k in
                            Chip(title: k.displayName, icon: k.icon, isSelected: filter == k) { filter = k }
                        }
                    }
                }

                if entries.isEmpty {
                    EmptyStateCard(icon: "clock.arrow.circlepath", title: "No history yet",
                                   message: "Apply coats and fix defects to build your log.")
                } else {
                    ForEach(entries) { e in
                        CardView {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(color(for: e.kind).opacity(0.16)).frame(width: 40, height: 40)
                                    Image(systemName: e.kind.icon).foregroundColor(color(for: e.kind))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(e.detail).font(Theme.body()).foregroundColor(Theme.textPrimary)
                                    Text(Formatters.date(e.date)).font(Theme.caption(11))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                            }
                        }
                    }

                    ActionButton(title: "Clear History", systemImage: "trash", kind: .secondary) {
                        store.clearHistory()
                    }
                }
            }
        }
    }

    private func color(for kind: HistoryKind) -> Color {
        switch kind {
        case .painted: return Theme.accent
        case .dried: return Theme.ready
        case .fixed: return Theme.attention
        }
    }
}
