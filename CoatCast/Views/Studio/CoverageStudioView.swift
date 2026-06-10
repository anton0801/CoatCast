//
//  CoverageStudioView.swift
//  CoatCast
//
//  Feature 01 (Coverage Studio) + 02 (Add Opening). The Studio tab home lists
//  rooms and the live coverage engine; tapping a room opens its breakdown, and
//  the editor drives wall area − openings × coats → liters of paint + primer.
//

import SwiftUI

// MARK: - Studio tab home

struct StudioHomeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var clock: Clock
    @State private var showNewRoom = false

    var body: some View {
        ScreenScaffold("Coverage Studio",
                       subtitle: "Rooms, openings & paint you actually need") {
            VStack(spacing: Theme.Space.m) {
                Button(action: { showNewRoom = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Room")
                    }
                    .font(Theme.heading(15)).foregroundColor(Theme.onAccent)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.primaryButtonGradient)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
                    .shadow(color: Theme.glow, radius: 10, y: 5)
                }
                .buttonStyle(PlainButtonStyle())

                if store.rooms.isEmpty {
                    EmptyStateCard(icon: "paintbrush",
                                   title: "No rooms yet",
                                   message: "Add a room to calculate paint, primer and your drying schedule.")
                } else {
                    ForEach(store.rooms) { room in
                        NavigationLink(destination: RoomDetailView(roomID: room.id)) {
                            RoomCard(room: room)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                SectionHeader(title: "Color", systemImage: "paintpalette.fill")
                NavRow(icon: "eyedropper.halffull", title: "Color Mix",
                       subtitle: "Save & repeat tint recipes", tint: Theme.pink) {
                    ColorMixListView()
                }
                NavRow(icon: "square.grid.2x2.fill", title: "Swatch Wall",
                       subtitle: "Bind colors to rooms", tint: Theme.orange) {
                    SwatchWallView()
                }
            }
        }
        .sheet(isPresented: $showNewRoom) {
            RoomEditorView(existing: nil).environmentObject(store)
        }
    }

    private struct RoomCard: View {
        @EnvironmentObject var store: AppStore
        let room: PaintRoom
        var body: some View {
            CardView {
                HStack(spacing: 14) {
                    ColorDot(hex: room.colorHex, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(room.name).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                        HStack(spacing: 6) {
                            TagChip(text: room.paintType.displayName, color: Theme.accent)
                            TagChip(text: room.surface.displayName, color: Theme.textSecondary)
                        }
                        if let cov = store.coverage(for: room.id) {
                            Text("\(Formatters.decimal(cov.paintLiters)) L · \(cov.coats) coats")
                                .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                        }
                    }
                    Spacer()
                    ProgressRing(progress: store.roomProgress(for: room.id), size: 50, lineWidth: 6)
                }
            }
        }
    }
}

// MARK: - Room detail (coverage breakdown + openings)

struct RoomDetailView: View {
    @EnvironmentObject var store: AppStore
    let roomID: UUID

    @State private var showEdit = false
    @State private var showAddOpening = false
    @AppStorage("measureUnit") private var measureUnitRaw = MeasureUnit.meters.rawValue
    @AppStorage("volumeUnit") private var volumeUnitRaw = VolumeUnit.liters.rawValue

    private var measureUnit: MeasureUnit { MeasureUnit(rawValue: measureUnitRaw) ?? .meters }
    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .liters }

    var body: some View {
        Group {
            if let room = store.room(roomID), let cov = store.coverage(for: roomID) {
                ScreenScaffold(room.name, subtitle: "\(room.paintType.displayName) · \(room.surface.displayName)") {
                    VStack(spacing: Theme.Space.m) {
                        coverageCard(room: room, cov: cov)
                        shortfallCard(room: room, cov: cov)
                        openingsCard(room: room)
                        actionsCard(room: room)
                    }
                }
            } else {
                ScreenScaffold("Room") { EmptyStateCard(icon: "trash", title: "Room removed", message: "This room no longer exists.") }
            }
        }
        .sheet(isPresented: $showEdit) {
            RoomEditorView(existing: store.room(roomID)).environmentObject(store)
        }
        .sheet(isPresented: $showAddOpening) {
            AddOpeningSheet(roomID: roomID).environmentObject(store)
        }
    }

    private func vol(_ liters: Double) -> String {
        "\(Formatters.decimal(UnitConvert.volumeToDisplay(liters, volumeUnit))) \(volumeUnit.short)"
    }
    private func area(_ m2: Double) -> String {
        "\(Formatters.decimal(UnitConvert.areaToDisplay(m2, measureUnit))) \(measureUnit.areaShort)"
    }

    private func coverageCard(room: PaintRoom, cov: CoverageResult) -> some View {
        CardView(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Paint needed", systemImage: "drop.fill")
                HStack(spacing: 12) {
                    bigStat(vol(cov.paintLiters), "Paint", Theme.accent)
                    bigStat(vol(cov.primerLiters), "Primer", Theme.pink)
                }
                Divider().background(Theme.stroke)
                detailRow("Net area", area(cov.netArea))
                detailRow("Coverage", "\(Formatters.decimal(cov.coverage)) \(measureUnit.areaShort)/\(volumeUnit.short)")
                detailRow("Coats", "\(cov.coats)")
                detailRow("Paint cans", "\(cov.paintCans) × \(vol(room.canLiters))")
                detailRow("Leftover in last can", vol(cov.remainderLiters))
            }
        }
    }

    private func shortfallCard(room: PaintRoom, cov: CoverageResult) -> some View {
        let short = store.shortfall(for: roomID)
        return Group {
            if short > 0 {
                CardView(tint: Theme.attention) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.attention)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Short \(vol(short)) of \(room.paintType.displayName)")
                                .font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                            Text("Stock on hand won't cover this plan.")
                                .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }
            } else {
                CardView(tint: Theme.ready) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(Theme.ready)
                        Text("You have enough \(room.paintType.displayName) in stock.")
                            .font(Theme.caption(13)).foregroundColor(Theme.textPrimary)
                        Spacer()
                    }
                }
            }
        }
    }

    private func openingsCard(room: PaintRoom) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Openings", systemImage: "window.vertical.closed")
                    Button(action: { showAddOpening = true }) {
                        Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent).font(.system(size: 22))
                    }
                }
                let openings = store.openings(for: roomID)
                if openings.isEmpty {
                    Text("No windows or doors subtracted yet.")
                        .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                } else {
                    ForEach(openings) { o in
                        HStack {
                            Image(systemName: o.kind.icon).foregroundColor(Theme.accent)
                            Text(o.kind.displayName).font(Theme.body()).foregroundColor(Theme.textPrimary)
                            Text("\(Formatters.decimal(o.width))×\(Formatters.decimal(o.height)) ×\(o.count)")
                                .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("−\(area(o.area))").font(Theme.caption(12)).foregroundColor(Theme.defect)
                            Button(action: { store.removeOpening(o) }) {
                                Image(systemName: "trash").foregroundColor(Theme.defect).font(.system(size: 14))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func actionsCard(room: PaintRoom) -> some View {
        VStack(spacing: 12) {
            NavigationLink(destination: LayerSchedulerView(roomID: roomID)) {
                HStack {
                    Image(systemName: "timer")
                    Text("Open Layer Scheduler")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(Theme.heading(15)).foregroundColor(Theme.onSecondary)
                .padding(16)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surfaceAlt))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())

            HStack(spacing: 12) {
                ActionButton(title: "Edit Room", systemImage: "pencil", kind: .secondary) { showEdit = true }
                ActionButton(title: "Delete", systemImage: "trash", kind: .danger) {
                    store.deleteRoom(room)
                }
            }
        }
    }

    private func bigStat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(Theme.title(22)).foregroundColor(tint).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(tint.opacity(0.10)))
    }
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
        }
    }
}

// MARK: - Room editor (create / edit)

struct RoomEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let existing: PaintRoom?

    @State private var draft: PaintRoom
    @AppStorage("measureUnit") private var measureUnitRaw = MeasureUnit.meters.rawValue
    @AppStorage("volumeUnit") private var volumeUnitRaw = VolumeUnit.liters.rawValue
    private var measureUnit: MeasureUnit { MeasureUnit(rawValue: measureUnitRaw) ?? .meters }
    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .liters }

    init(existing: PaintRoom?) {
        self.existing = existing
        _draft = State(initialValue: existing ?? PaintRoom(name: ""))
    }

    private var wallAreaBinding: Binding<Double> {
        Binding(get: { UnitConvert.areaToDisplay(draft.wallArea, measureUnit) },
                set: { draft.wallArea = UnitConvert.areaToSI($0, measureUnit) })
    }
    private var canBinding: Binding<Double> {
        Binding(get: { UnitConvert.volumeToDisplay(draft.canLiters, volumeUnit) },
                set: { draft.canLiters = max(0.1, UnitConvert.volumeToSI($0, volumeUnit)) })
    }

    private var liveCoverage: CoverageResult {
        PaintEngine.coverage(netArea: draft.wallArea,
                             coats: draft.targetCoats,
                             type: draft.paintType,
                             surface: draft.surface,
                             primerType: store.prefs.primerType,
                             canLiters: draft.canLiters,
                             primerCanLiters: store.prefs.defaultPrimerCanLiters)
    }

    var body: some View {
        NavigationView {
            ScreenScaffold(existing == nil ? "New Room" : "Edit Room") {
                VStack(spacing: Theme.Space.m) {
                    CardView {
                        VStack(spacing: 14) {
                            LabeledTextField(label: "Room name", text: $draft.name, placeholder: "e.g. Bedroom")
                            LabeledNumberField(label: "Wall area (gross)", value: wallAreaBinding,
                                               suffix: measureUnit.areaShort)
                            Stepper2(label: "Target coats", value: $draft.targetCoats, range: 1...6)
                            LabeledNumberField(label: "Can size", value: canBinding, suffix: volumeUnit.short)
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Paint type", systemImage: "drop.fill")
                            chipRow(PaintType.allCases.map { ($0.displayName, $0.icon, $0 == draft.paintType) }) { i in
                                draft.paintType = PaintType.allCases[i]
                            }
                            SectionHeader(title: "Surface", systemImage: "square.split.bottomrightquarter")
                            chipRow(Surface.allCases.map { ($0.displayName, $0.icon, $0 == draft.surface) }) { i in
                                draft.surface = Surface.allCases[i]
                                draft.targetCoats = Surface.allCases[i].defaultCoats
                            }
                            SectionHeader(title: "Swatch color", systemImage: "paintpalette.fill")
                            SwatchPicker(hex: $draft.colorHex)
                        }
                    }

                    CardView(tint: Theme.accent) {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Live estimate", systemImage: "function")
                            HStack {
                                Text("Paint").font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(Formatters.decimal(UnitConvert.volumeToDisplay(liveCoverage.paintLiters, volumeUnit))) \(volumeUnit.short) · \(liveCoverage.paintCans) cans")
                                    .font(Theme.heading(14)).foregroundColor(Theme.accent)
                            }
                            HStack {
                                Text("Primer").font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                                Spacer()
                                Text("\(Formatters.decimal(UnitConvert.volumeToDisplay(liveCoverage.primerLiters, volumeUnit))) \(volumeUnit.short)")
                                    .font(Theme.heading(14)).foregroundColor(Theme.pink)
                            }
                            Text("Add windows/doors after saving to subtract their area.")
                                .font(Theme.caption(11)).foregroundColor(Theme.textInactive)
                        }
                    }

                    LabeledTextField(label: "Notes", text: $draft.notes, placeholder: "Optional")

                    ActionButton(title: existing == nil ? "Save Room" : "Save Changes",
                                 systemImage: "checkmark.circle.fill",
                                 enabled: !draft.name.trimmingCharacters(in: .whitespaces).isEmpty) {
                        save()
                    }
                    ActionButton(title: "Cancel", kind: .secondary) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func chipRow(_ items: [(String, String, Bool)], onSelect: @escaping (Int) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    Chip(title: item.0, icon: item.1, isSelected: item.2) { onSelect(idx) }
                }
            }
        }
    }

    private func save() {
        UIApplication.shared.dismissKeyboard()
        if existing == nil { store.addRoom(draft) } else { store.updateRoom(draft) }
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Add Opening sheet (feature 02)

struct AddOpeningSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let roomID: UUID

    @State private var kind: OpeningKind = .window
    @State private var width: Double = 0
    @State private var height: Double = 0
    @State private var count: Int = 1
    @AppStorage("measureUnit") private var measureUnitRaw = MeasureUnit.meters.rawValue
    private var measureUnit: MeasureUnit { MeasureUnit(rawValue: measureUnitRaw) ?? .meters }

    private var areaSI: Double {
        UnitConvert.areaToSI(width * height, measureUnit) * Double(count)
    }

    var body: some View {
        NavigationView {
            ScreenScaffold("Add Opening", subtitle: "Subtracted from wall area") {
                VStack(spacing: Theme.Space.m) {
                    CardView {
                        VStack(spacing: 14) {
                            HStack(spacing: 10) {
                                ForEach(OpeningKind.allCases) { k in
                                    Chip(title: k.displayName, icon: k.icon, isSelected: kind == k) { kind = k }
                                }
                            }
                            LabeledNumberField(label: "Width", value: $width, suffix: measureUnit.lengthShort)
                            LabeledNumberField(label: "Height", value: $height, suffix: measureUnit.lengthShort)
                            Stepper2(label: "Count", value: $count, range: 1...20)
                        }
                    }
                    CardView(tint: Theme.accent) {
                        HStack {
                            Text("Area removed").font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(Formatters.decimal(width * height * Double(count))) \(measureUnit.areaShort)")
                                .font(Theme.heading(16)).foregroundColor(Theme.accent)
                        }
                    }
                    ActionButton(title: "Add Opening", systemImage: "plus.circle.fill",
                                 enabled: width > 0 && height > 0) {
                        store.addOpening(Opening(roomID: roomID, kind: kind,
                                                 width: UnitConvert.lengthToSI(width, measureUnit),
                                                 height: UnitConvert.lengthToSI(height, measureUnit),
                                                 count: count))
                        presentationMode.wrappedValue.dismiss()
                    }
                    ActionButton(title: "Cancel", kind: .secondary) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
