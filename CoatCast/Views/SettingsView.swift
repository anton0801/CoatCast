//
//  SettingsView.swift
//  CoatCast
//
//  Feature 15 (Settings): theme (re-colors the whole app instantly), units
//  (m²/ft², L/gal), currency, paint presets, backup/export JSON, and resets.
//  Every control has a real, persisted effect.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    @AppStorage("appearance") private var appearanceRaw = AppAppearance.system.rawValue
    @AppStorage("measureUnit") private var measureUnitRaw = MeasureUnit.meters.rawValue
    @AppStorage("volumeUnit") private var volumeUnitRaw = VolumeUnit.liters.rawValue
    @AppStorage("currencySymbol") private var currencySymbol = "$"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var showPresetEditor = false
    @State private var editingPreset: PaintPreset?
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showResetAlert = false
    @State private var confirmation: String?

    private let currencies = ["$", "€", "£", "₽", "¥", "₹"]

    var body: some View {
        ScreenScaffold("Settings", subtitle: "Make it yours") {
            VStack(spacing: Theme.Space.m) {
                if let msg = confirmation {
                    CardView(tint: Theme.ready) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(Theme.ready)
                            Text(msg).font(Theme.caption(13)).foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                    }
                }

                appearanceCard
                unitsCard
                currencyCard
                presetsCard
                dataCard
            }
        }
        .sheet(isPresented: $showPresetEditor) {
            PaintPresetEditor(existing: editingPreset).environmentObject(store)
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
        .alert(isPresented: $showResetAlert) {
            Alert(title: Text("Reset all data?"),
                  message: Text("This deletes all rooms, schedules, photos and settings, and restores the sample project."),
                  primaryButton: .destructive(Text("Reset")) {
                      store.resetAll()
                      flash("All data reset to the sample project.")
                  },
                  secondaryButton: .cancel())
        }
    }

    // MARK: Appearance (theme)

    private var appearanceCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Theme", systemImage: "paintbrush.fill")
                HStack(spacing: 10) {
                    ForEach(AppAppearance.allCases) { a in
                        Chip(title: a.displayName, icon: a.icon, isSelected: appearanceRaw == a.rawValue) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { appearanceRaw = a.rawValue }
                        }
                    }
                }
                Text("Changes the entire app instantly and is remembered.")
                    .font(Theme.caption(11)).foregroundColor(Theme.textInactive)
            }
        }
    }

    // MARK: Units

    private var unitsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Units", systemImage: "ruler.fill")
                VStack(alignment: .leading, spacing: 6) {
                    Text("AREA").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    HStack(spacing: 10) {
                        ForEach(MeasureUnit.allCases) { u in
                            Chip(title: u.displayName, isSelected: measureUnitRaw == u.rawValue) {
                                measureUnitRaw = u.rawValue
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("VOLUME").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    HStack(spacing: 10) {
                        ForEach(VolumeUnit.allCases) { u in
                            Chip(title: u.displayName, isSelected: volumeUnitRaw == u.rawValue) {
                                volumeUnitRaw = u.rawValue
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Currency

    private var currencyCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Currency", systemImage: "dollarsign.circle.fill")
                HStack(spacing: 10) {
                    ForEach(currencies, id: \.self) { c in
                        Button(action: { currencySymbol = c }) {
                            Text(c).font(Theme.heading(18))
                                .foregroundColor(currencySymbol == c ? Theme.onAccent : Theme.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(currencySymbol == c ? Theme.accent : Theme.surfaceAlt))
                                .overlay(Circle().stroke(currencySymbol == c ? Color.clear : Theme.stroke, lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: Presets

    private var presetsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Paint Presets", systemImage: "square.stack.3d.up.fill")
                    Button(action: { editingPreset = nil; showPresetEditor = true }) {
                        Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent).font(.system(size: 22))
                    }
                }
                if store.presets.isEmpty {
                    Text("Save your favorite paints to reuse their coverage.")
                        .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                }
                ForEach(store.presets) { preset in
                    HStack(spacing: 12) {
                        ColorDot(hex: preset.colorHex, size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                            Text("\(preset.paintType.displayName) · \(Formatters.decimal(preset.coverage)) m²/L")
                                .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Button(action: {
                            store.applyPreset(preset)
                            flash("“\(preset.name)” applied to defaults.")
                        }) {
                            Text("Apply").font(Theme.caption(13)).foregroundColor(Theme.accentActive)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Button(action: { editingPreset = preset; showPresetEditor = true }) {
                            Image(systemName: "pencil").foregroundColor(Theme.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: Data / backup

    private var dataCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Backup & Data", systemImage: "externaldrive.fill")
                ActionButton(title: "Export Data (JSON)", systemImage: "square.and.arrow.up", kind: .secondary) {
                    store.flush()
                    shareURL = PersistenceManager.shared.fileURL
                    showShare = true
                }
                ActionButton(title: "Replay Onboarding", systemImage: "arrow.counterclockwise", kind: .secondary) {
                    hasCompletedOnboarding = false
                    flash("Onboarding will show next time you launch the app.")
                }
                ActionButton(title: "Reset All Data", systemImage: "trash", kind: .danger) {
                    showResetAlert = true
                }
                Text("Version 1.0 · Local-only · No account required")
                    .font(Theme.caption(11)).foregroundColor(Theme.textInactive)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func flash(_ message: String) {
        withAnimation { confirmation = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { withAnimation { confirmation = nil } }
    }
}

// MARK: - Preset editor

struct PaintPresetEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let existing: PaintPreset?
    @State private var draft: PaintPreset

    init(existing: PaintPreset?) {
        self.existing = existing
        _draft = State(initialValue: existing ?? PaintPreset(name: ""))
    }

    var body: some View {
        NavigationView {
            ScreenScaffold(existing == nil ? "New Preset" : "Edit Preset") {
                VStack(spacing: Theme.Space.m) {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledTextField(label: "Name", text: $draft.name, placeholder: "e.g. Matte Wall White")
                            SectionHeader(title: "Paint type", systemImage: "drop.fill")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(PaintType.allCases) { t in
                                        Chip(title: t.displayName, icon: t.icon, isSelected: draft.paintType == t) {
                                            draft.paintType = t
                                            draft.coverage = t.baseCoverage
                                        }
                                    }
                                }
                            }
                            SectionHeader(title: "Surface", systemImage: "square.split.bottomrightquarter")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Surface.allCases) { s in
                                        Chip(title: s.displayName, icon: s.icon, isSelected: draft.surface == s) {
                                            draft.surface = s
                                        }
                                    }
                                }
                            }
                            LabeledNumberField(label: "Coverage", value: $draft.coverage, suffix: "m²/L")
                            LabeledNumberField(label: "Can size", value: $draft.canLiters, suffix: "L")
                            SectionHeader(title: "Color", systemImage: "paintpalette.fill")
                            SwatchPicker(hex: $draft.colorHex)
                        }
                    }
                    ActionButton(title: existing == nil ? "Save Preset" : "Save Changes",
                                 systemImage: "checkmark.circle.fill",
                                 enabled: !draft.name.trimmingCharacters(in: .whitespaces).isEmpty) {
                        store.addPreset(draft); presentationMode.wrappedValue.dismiss()
                    }
                    if existing != nil {
                        ActionButton(title: "Delete Preset", systemImage: "trash", kind: .danger) {
                            if let p = existing { store.deletePreset(p) }
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
