//
//  ColorMixView.swift
//  CoatCast
//
//  Feature 05 (Color Mix): build a tint recipe from a base + pigment parts,
//  preview the blended result, save it, and "repeat exactly" by scaling the
//  recipe to any target volume.
//

import SwiftUI

// Weighted RGB blend of a white base + pigments (approximate mixing preview).
enum PaintMixer {
    static func blend(baseParts: Double, baseHex: UInt = 0xFFFFFF, pigments: [Pigment]) -> UInt {
        let total = baseParts + pigments.reduce(0) { $0 + $1.parts }
        guard total > 0 else { return baseHex }
        func comps(_ hex: UInt) -> (Double, Double, Double) {
            (Double((hex & 0xFF0000) >> 16), Double((hex & 0x00FF00) >> 8), Double(hex & 0x0000FF))
        }
        var (r, g, b) = (0.0, 0.0, 0.0)
        let base = comps(baseHex)
        r += base.0 * baseParts; g += base.1 * baseParts; b += base.2 * baseParts
        for p in pigments {
            let c = comps(p.colorHex)
            r += c.0 * p.parts; g += c.1 * p.parts; b += c.2 * p.parts
        }
        r /= total; g /= total; b /= total
        return (UInt(r.rounded()) << 16) | (UInt(g.rounded()) << 8) | UInt(b.rounded())
    }
}

// MARK: - List

struct ColorMixListView: View {
    @EnvironmentObject var store: AppStore
    @State private var showEditor = false
    @State private var editing: ColorMix?

    var body: some View {
        ScreenScaffold("Color Mix", subtitle: "Recipes you can repeat exactly") {
            VStack(spacing: Theme.Space.m) {
                ActionButton(title: "New Mix", systemImage: "plus.circle.fill") {
                    editing = nil; showEditor = true
                }
                if store.mixes.isEmpty {
                    EmptyStateCard(icon: "eyedropper.halffull", title: "No mixes saved",
                                   message: "Record a base + pigment recipe so you can match the color again later.")
                } else {
                    ForEach(store.mixes) { mix in
                        Button(action: { editing = mix; showEditor = true }) {
                            mixCard(mix)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            ColorMixEditorView(existing: editing).environmentObject(store)
        }
    }

    private func mixCard(_ mix: ColorMix) -> some View {
        CardView {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: mix.resultHex))
                    .frame(width: 48, height: 48)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke, lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(mix.name).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                    Text("\(mix.baseName) + \(mix.pigments.count) pigment\(mix.pigments.count == 1 ? "" : "s")")
                        .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                    if let roomID = mix.roomID, let room = store.room(roomID) {
                        TagChip(text: room.name, color: Theme.accent)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Theme.textInactive)
            }
        }
    }
}

// MARK: - Editor

struct ColorMixEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let existing: ColorMix?

    @State private var name: String
    @State private var baseName: String
    @State private var baseParts: Double
    @State private var pigments: [Pigment]
    @State private var roomID: UUID?
    @State private var targetVolume: Double = 1

    @AppStorage("volumeUnit") private var volumeUnitRaw = VolumeUnit.liters.rawValue
    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .liters }

    init(existing: ColorMix?) {
        self.existing = existing
        let m = existing ?? ColorMix(name: "")
        _name = State(initialValue: m.name)
        _baseName = State(initialValue: m.baseName)
        _baseParts = State(initialValue: m.baseParts)
        _pigments = State(initialValue: m.pigments)
        _roomID = State(initialValue: m.roomID)
    }

    private var resultHex: UInt { PaintMixer.blend(baseParts: baseParts, pigments: pigments) }
    private var scaled: (base: Double, pigments: [Double]) {
        let liters = UnitConvert.volumeToSI(targetVolume, volumeUnit)
        return PaintEngine.scaleMix(baseParts: baseParts, pigmentParts: pigments.map { $0.parts }, toVolume: liters)
    }

    var body: some View {
        NavigationView {
            ScreenScaffold(existing == nil ? "New Mix" : "Edit Mix") {
                VStack(spacing: Theme.Space.m) {
                    // Preview
                    CardView {
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Color(hex: resultHex))
                                .frame(width: 80, height: 80)
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Blended result").font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                                Text(String(format: "#%06X", resultHex)).font(Theme.heading(16))
                                    .foregroundColor(Theme.textPrimary)
                                Text("\(Formatters.decimal(baseParts + pigments.reduce(0){$0+$1.parts})) total parts")
                                    .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledTextField(label: "Mix name", text: $name, placeholder: "e.g. Teal Mist")
                            LabeledTextField(label: "Base", text: $baseName, placeholder: "White Base")
                            LabeledNumberField(label: "Base parts", value: $baseParts, suffix: "parts")
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                SectionHeader(title: "Pigments", systemImage: "drop.fill")
                                Button(action: addPigment) {
                                    Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent).font(.system(size: 22))
                                }
                            }
                            if pigments.isEmpty {
                                Text("Add pigments to tint the base.")
                                    .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                            }
                            ForEach(pigments.indices, id: \.self) { i in
                                pigmentRow(i)
                            }
                        }
                    }

                    // Repeat exactly
                    CardView(tint: Theme.accent) {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Repeat exactly", systemImage: "arrow.triangle.2.circlepath")
                            LabeledNumberField(label: "Target volume", value: $targetVolume, suffix: volumeUnit.short)
                            Divider().background(Theme.stroke)
                            HStack {
                                Text(baseName).font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(Formatters.decimal(UnitConvert.volumeToDisplay(scaled.base, volumeUnit), max: 3)) \(volumeUnit.short)")
                                    .font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                            }
                            ForEach(pigments.indices, id: \.self) { i in
                                HStack {
                                    Text(pigments[i].name).font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text("\(Formatters.decimal(UnitConvert.volumeToDisplay(i < scaled.pigments.count ? scaled.pigments[i] : 0, volumeUnit), max: 3)) \(volumeUnit.short)")
                                        .font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                                }
                            }
                        }
                    }

                    // Bind to room
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Bind to room", systemImage: "link")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Chip(title: "None", isSelected: roomID == nil) { roomID = nil }
                                    ForEach(store.rooms) { r in
                                        Chip(title: r.name, isSelected: roomID == r.id) { roomID = r.id }
                                    }
                                }
                            }
                        }
                    }

                    ActionButton(title: existing == nil ? "Save Mix" : "Save Changes",
                                 systemImage: "checkmark.circle.fill",
                                 enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) { save() }
                    if existing != nil {
                        ActionButton(title: "Delete Mix", systemImage: "trash", kind: .danger) {
                            if let m = existing { store.deleteMix(m) }
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

    private func pigmentRow(_ i: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Pigment name", text: $pigments[i].name)
                    .font(Theme.body()).foregroundColor(Theme.textPrimary)
                Spacer()
                Button(action: { pigments.remove(at: i) }) {
                    Image(systemName: "minus.circle.fill").foregroundColor(Theme.defect)
                }
                .buttonStyle(PlainButtonStyle())
            }
            HStack {
                Text("Parts").font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                Slider(value: $pigments[i].parts, in: 0.5...20, step: 0.5).accentColor(Theme.accent)
                Text(Formatters.decimal(pigments[i].parts)).font(Theme.heading(14))
                    .foregroundColor(Theme.textPrimary).frame(width: 38)
            }
            SwatchPicker(hex: $pigments[i].colorHex)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
    }

    private func addPigment() {
        pigments.append(Pigment(name: "Pigment \(pigments.count + 1)", parts: 1, colorHex: 0x14B8A6))
    }

    private func save() {
        UIApplication.shared.dismissKeyboard()
        var m = existing ?? ColorMix(name: name)
        m.name = name
        m.baseName = baseName
        m.baseParts = baseParts
        m.pigments = pigments
        m.resultHex = resultHex
        m.roomID = roomID
        store.addMix(m)
        // Apply the mixed color to the bound room's swatch.
        if let rid = roomID, var room = store.room(rid) { room.colorHex = resultHex; store.updateRoom(room) }
        presentationMode.wrappedValue.dismiss()
    }
}
