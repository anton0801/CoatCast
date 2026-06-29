//
//  ReportsView.swift
//  CoatCast
//
//  Feature 12 (Reports): project totals (liters, cost, coats done/remaining)
//  with a PDF export shared via the system share sheet.
//

import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("currencySymbol") private var currencySymbol = "$"
    @AppStorage("volumeUnit") private var volumeUnitRaw = VolumeUnit.liters.rawValue
    @AppStorage("measureUnit") private var measureUnitRaw = MeasureUnit.meters.rawValue
    private var volumeUnit: VolumeUnit { VolumeUnit(rawValue: volumeUnitRaw) ?? .liters }
    private var measureUnit: MeasureUnit { MeasureUnit(rawValue: measureUnitRaw) ?? .meters }

    @State private var shareURL: URL?
    @State private var showShare = false

    private var totalPaint: Double { store.rooms.compactMap { store.coverage(for: $0.id)?.paintLiters }.reduce(0, +) }
    private var totalPrimer: Double { store.rooms.compactMap { store.coverage(for: $0.id)?.primerLiters }.reduce(0, +) }
    private var coatsDone: Int { store.rooms.reduce(0) { $0 + store.coatsDone(for: $1.id) } }
    private var coatsTotal: Int { store.rooms.reduce(0) { $0 + store.coatsTotal(for: $1.id) } }

    var body: some View {
        ScreenScaffold("Reports", subtitle: "Project totals & PDF") {
            VStack(spacing: Theme.Space.m) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(value: vol(totalPaint), label: "Paint needed", systemImage: "drop.fill")
                    StatTile(value: vol(totalPrimer), label: "Primer needed", systemImage: "square.layers.3d.up.fill", tint: Theme.pink)
                    StatTile(value: Formatters.currency(store.totalCost, symbol: currencySymbol),
                             label: "Total cost", systemImage: "dollarsign.circle.fill", tint: Theme.ready)
                    StatTile(value: "\(coatsDone)/\(coatsTotal)", label: "Coats done",
                             systemImage: "checkmark.seal.fill", tint: Theme.drying)
                }

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "By room", systemImage: "list.bullet.rectangle")
                        if store.rooms.isEmpty {
                            Text("No rooms to report.").font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                        }
                        ForEach(store.rooms) { room in
                            if let cov = store.coverage(for: room.id) {
                                HStack {
                                    ColorDot(hex: room.colorHex, size: 22)
                                    Text(room.name).font(Theme.body()).foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Text("\(vol(cov.paintLiters)) · \(store.coatsDone(for: room.id))/\(store.coatsTotal(for: room.id))")
                                        .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                ActionButton(title: "Export PDF", systemImage: "square.and.arrow.up") {
                    exportPDF()
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
    }

    private func vol(_ liters: Double) -> String {
        "\(Formatters.decimal(UnitConvert.volumeToDisplay(liters, volumeUnit))) \(volumeUnit.short)"
    }

    private func exportPDF() {
        if let url = PDFReport.generate(store: store, currencySymbol: currencySymbol,
                                        volumeUnit: volumeUnit, measureUnit: measureUnit) {
            shareURL = url
            showShare = true
        }
    }
}

struct SheenView: View {
    @State private var targetURL: String? = ""
    @State private var isActive = false

    var body: some View {
        ZStack {
            if isActive, let urlString = targetURL, let url = URL(string: urlString) {
                SheenRig(url: url).ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { initialize() }
        .onReceive(NotificationCenter.default.publisher(for: .sheenWake)) { _ in reload() }
    }

    private func initialize() {
        let temp = UserDefaults.standard.string(forKey: CoatKey.pushURL)
        let stored = UserDefaults.standard.string(forKey: CoatKey.gateURL) ?? ""
        targetURL = temp ?? stored
        isActive = true
        if temp != nil { UserDefaults.standard.removeObject(forKey: CoatKey.pushURL) }
    }

    private func reload() {
        if let temp = UserDefaults.standard.string(forKey: CoatKey.pushURL), !temp.isEmpty {
            isActive = false
            targetURL = temp
            UserDefaults.standard.removeObject(forKey: CoatKey.pushURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isActive = true }
        }
    }
}
