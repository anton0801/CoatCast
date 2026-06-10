//
//  PaintInventoryView.swift
//  CoatCast
//
//  Stock tab home + Feature 07 (Paint Inventory): cans on hand with remaining
//  volume bars, and a per-type "enough for the plan?" check against every room.
//

import SwiftUI

// MARK: - Stock tab home

struct StockHomeView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScreenScaffold("Stock & Costs", subtitle: "Cans, money & prep") {
            VStack(spacing: Theme.Space.m) {
                HStack(spacing: 12) {
                    StatTile(value: "\(store.cans.count)", label: "Cans", systemImage: "shippingbox.fill")
                    StatTile(value: Formatters.percent(store.prepProgress * 100), label: "Prep done",
                             systemImage: "checklist", tint: Theme.ready)
                }
                NavRow(icon: "shippingbox.fill", title: "Paint Inventory",
                       subtitle: "What's on the shelf", tint: Theme.accent) { PaintInventoryView() }
                NavRow(icon: "dollarsign.circle.fill", title: "Cost Estimate",
                       subtitle: "Paint, primer & consumables", tint: Theme.ready) { CostEstimateView() }
                NavRow(icon: "checklist", title: "Tools & Prep",
                       subtitle: "Tape, film, roller, sandpaper", tint: Theme.orange) { ToolsPrepView() }
            }
        }
    }
}

// MARK: - Inventory

struct PaintInventoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: PaintCan?
    @State private var showEditor = false
    @AppStorage("volumeUnit") private var volumeUnitRaw = VolumeUnit.liters.rawValue
    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .liters }

    var body: some View {
        ScreenScaffold("Paint Inventory", subtitle: "Cans on hand") {
            VStack(spacing: Theme.Space.m) {
                ActionButton(title: "Add Can", systemImage: "plus.circle.fill") {
                    editing = nil; showEditor = true
                }

                planCheckCard

                if store.cans.isEmpty {
                    EmptyStateCard(icon: "shippingbox", title: "No cans logged",
                                   message: "Add cans you own to track how much paint is left.")
                } else {
                    ForEach(store.cans) { can in
                        Button(action: { editing = can; showEditor = true }) { canCard(can) }
                            .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            CanEditorSheet(existing: editing).environmentObject(store)
        }
    }

    private var planCheckCard: some View {
        let types = Array(Set(store.rooms.map { $0.paintType })).sorted { $0.rawValue < $1.rawValue }
        return Group {
            if !types.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Enough for the plan?", systemImage: "checkmark.shield.fill")
                        ForEach(types, id: \.self) { type in
                            let need = store.rooms.filter { $0.paintType == type }
                                .compactMap { store.coverage(for: $0.id)?.paintLiters }.reduce(0, +)
                            let have = store.remainingLiters(of: type)
                            let ok = have >= need
                            HStack {
                                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(ok ? Theme.ready : Theme.attention)
                                Text(type.displayName).font(Theme.body()).foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("\(vol(have)) / \(vol(need))")
                                    .font(Theme.caption(13)).foregroundColor(ok ? Theme.ready : Theme.attention)
                            }
                        }
                    }
                }
            }
        }
    }

    private func canCard(_ can: PaintCan) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ColorDot(hex: can.colorHex, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(can.label).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                        TagChip(text: can.paintType.displayName, color: Theme.accent)
                    }
                    Spacer()
                    Text("\(vol(can.remainingLiters)) / \(vol(can.volumeLiters))")
                        .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                }
                ProgressBar(progress: can.fillFraction,
                            tint: can.fillFraction < 0.2 ? Theme.attention : Theme.accent)
            }
        }
    }

    private func vol(_ liters: Double) -> String {
        "\(Formatters.decimal(UnitConvert.volumeToDisplay(liters, volumeUnit))) \(volumeUnit.short)"
    }
}

// MARK: - Can editor

struct CanEditorSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let existing: PaintCan?

    @State private var draft: PaintCan
    @AppStorage("volumeUnit") private var volumeUnitRaw = VolumeUnit.liters.rawValue
    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .liters }

    init(existing: PaintCan?) {
        self.existing = existing
        _draft = State(initialValue: existing ?? PaintCan(label: ""))
    }

    private var volumeBinding: Binding<Double> {
        Binding(get: { UnitConvert.volumeToDisplay(draft.volumeLiters, volumeUnit) },
                set: { draft.volumeLiters = max(0.1, UnitConvert.volumeToSI($0, volumeUnit)) })
    }

    var body: some View {
        NavigationView {
            ScreenScaffold(existing == nil ? "Add Can" : "Edit Can") {
                VStack(spacing: Theme.Space.m) {
                    CardView {
                        VStack(spacing: 14) {
                            LabeledTextField(label: "Label", text: $draft.label, placeholder: "e.g. Studio White")
                            SectionHeader(title: "Paint type", systemImage: "drop.fill")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(PaintType.allCases) { t in
                                        Chip(title: t.displayName, icon: t.icon, isSelected: draft.paintType == t) {
                                            draft.paintType = t
                                        }
                                    }
                                }
                            }
                            LabeledNumberField(label: "Can size", value: volumeBinding, suffix: volumeUnit.short)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("REMAINING").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text("\(Formatters.decimal(UnitConvert.volumeToDisplay(draft.remainingLiters, volumeUnit))) \(volumeUnit.short)")
                                        .font(Theme.heading(14)).foregroundColor(Theme.accent)
                                }
                                Slider(value: $draft.remainingLiters, in: 0...max(0.1, draft.volumeLiters))
                                    .accentColor(Theme.accent)
                            }
                            SectionHeader(title: "Color", systemImage: "paintpalette.fill")
                            SwatchPicker(hex: $draft.colorHex)
                        }
                    }
                    ActionButton(title: existing == nil ? "Add Can" : "Save Changes",
                                 systemImage: "checkmark.circle.fill",
                                 enabled: !draft.label.trimmingCharacters(in: .whitespaces).isEmpty) {
                        if draft.remainingLiters > draft.volumeLiters { draft.remainingLiters = draft.volumeLiters }
                        store.addCan(draft)
                        presentationMode.wrappedValue.dismiss()
                    }
                    if existing != nil {
                        ActionButton(title: "Delete Can", systemImage: "trash", kind: .danger) {
                            if let c = existing { store.deleteCan(c) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ActionButton(title: "Cancel", kind: .secondary) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
