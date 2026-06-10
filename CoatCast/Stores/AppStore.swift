//
//  AppStore.swift
//  CoatCast
//
//  Single source of truth. Holds the Codable AppData aggregate, exposes typed
//  CRUD, and centralizes every derived calculation (net area, coverage, the
//  layer-scheduler lock rule, inventory sufficiency, costs) so numbers agree
//  across all screens. Mutations persist via the debounced PersistenceManager.
//

import Foundation
import Combine

final class AppStore: ObservableObject {
    @Published private(set) var data: AppData

    private let persistence = PersistenceManager.shared
    private let notifications = NotificationManager.shared

    init() {
        self.data = persistence.load()
        // Catch up any drying coats that finished while the app was closed.
        reconcile(asOf: Date())
    }

    private func save() { persistence.save(data) }
    func flush() { persistence.flush(data) }

    // MARK: Generic upsert / remove

    private func upsert<T: Identifiable>(_ item: T, _ keyPath: WritableKeyPath<AppData, [T]>)
        where T.ID == UUID {
        if let i = data[keyPath: keyPath].firstIndex(where: { $0.id == item.id }) {
            data[keyPath: keyPath][i] = item
        } else {
            data[keyPath: keyPath].append(item)
        }
        save()
    }
    private func remove<T: Identifiable>(_ item: T, _ keyPath: WritableKeyPath<AppData, [T]>)
        where T.ID == UUID {
        data[keyPath: keyPath].removeAll { $0.id == item.id }
        save()
    }

    // MARK: Preferences

    var prefs: PaintPrefs { data.prefs }
    func updatePrefs(_ p: PaintPrefs) { data.prefs = p; save() }
    func updatePrefs(_ mutate: (inout PaintPrefs) -> Void) {
        var p = data.prefs; mutate(&p); data.prefs = p; save()
    }

    // MARK: Rooms

    var rooms: [PaintRoom] { data.rooms.sorted { $0.createdAt < $1.createdAt } }
    func room(_ id: UUID?) -> PaintRoom? { data.rooms.first { $0.id == id } }

    func addRoom(_ r: PaintRoom) {
        upsert(r, \.rooms)
        ensureCoats(for: r)
    }
    func updateRoom(_ r: PaintRoom) {
        upsert(r, \.rooms)
        ensureCoats(for: r)
    }
    func deleteRoom(_ r: PaintRoom) {
        // Cascade: openings, coats, room-bound cost/defect/photo/prep.
        data.openings.removeAll { $0.roomID == r.id }
        data.coats.forEach { if $0.roomID == r.id { notifications.cancel(id: $0.notificationID) } }
        data.coats.removeAll { $0.roomID == r.id }
        data.costItems.removeAll { $0.roomID == r.id }
        data.defects.removeAll { $0.roomID == r.id }
        data.photoPairs.removeAll {
            if $0.roomID == r.id {
                PhotoStore.shared.delete(named: $0.beforeFileName)
                PhotoStore.shared.delete(named: $0.afterFileName)
                return true
            }
            return false
        }
        data.prepTasks.removeAll { $0.roomID == r.id }
        remove(r, \.rooms)
    }

    // MARK: Openings

    func openings(for roomID: UUID) -> [Opening] {
        data.openings.filter { $0.roomID == roomID }.sorted { $0.id.uuidString < $1.id.uuidString }
    }
    func addOpening(_ o: Opening) { upsert(o, \.openings) }
    func updateOpening(_ o: Opening) { upsert(o, \.openings) }
    func removeOpening(_ o: Opening) { remove(o, \.openings) }

    func netArea(for roomID: UUID) -> Double {
        guard let r = room(roomID) else { return 0 }
        return PaintEngine.netArea(wallArea: r.wallArea, openings: openings(for: roomID))
    }

    func coverage(for roomID: UUID) -> CoverageResult? {
        guard let r = room(roomID) else { return nil }
        return PaintEngine.coverage(netArea: netArea(for: roomID),
                                    coats: r.targetCoats,
                                    type: r.paintType,
                                    surface: r.surface,
                                    primerType: data.prefs.primerType,
                                    canLiters: r.canLiters,
                                    primerCanLiters: data.prefs.defaultPrimerCanLiters)
    }

    // MARK: Coats / Layer scheduler

    func coats(for roomID: UUID) -> [Coat] {
        data.coats.filter { $0.roomID == roomID }.sorted { $0.index < $1.index }
    }

    /// Ensures a primer coat (index 0) + coats 1...targetCoats exist for a room.
    func ensureCoats(for room: PaintRoom) {
        var existing = coats(for: room.id)
        // Primer coat
        if !existing.contains(where: { $0.isPrimer }) {
            let primer = Coat(roomID: room.id, index: 0, isPrimer: true)
            data.coats.append(primer)
            existing.append(primer)
        }
        // Top coats
        let topCoats = existing.filter { !$0.isPrimer }
        let target = max(room.targetCoats, 1)
        if topCoats.count < target {
            for i in (topCoats.count + 1)...target {
                data.coats.append(Coat(roomID: room.id, index: i))
            }
        } else if topCoats.count > target {
            // Trim trailing untouched coats only (never remove an applied one).
            let removable = topCoats.filter { $0.dryStartedAt == nil && $0.status == .pending }
                .sorted { $0.index > $1.index }
            var toRemove = topCoats.count - target
            for coat in removable where toRemove > 0 {
                data.coats.removeAll { $0.id == coat.id }
                toRemove -= 1
            }
        }
        save()
    }

    /// Lowest-index pending coat for a room.
    func nextApplicableCoat(for roomID: UUID) -> Coat? {
        coats(for: roomID).first { $0.status == .pending }
    }

    /// Locked while the most-recently-applied coat is still inside its dry window.
    func isNextCoatLocked(for roomID: UUID, asOf now: Date) -> Bool {
        let applied = coats(for: roomID)
            .filter { $0.dryStartedAt != nil }
            .sorted { ($0.dryStartedAt ?? .distantPast) < ($1.dryStartedAt ?? .distantPast) }
        guard let last = applied.last else { return false }
        return !last.isDry(asOf: now)
    }

    /// The coat currently drying for a room (if any).
    func dryingCoat(for roomID: UUID, asOf now: Date) -> Coat? {
        coats(for: roomID).first { $0.dryStartedAt != nil && !$0.isDry(asOf: now) }
    }

    func applyNextCoat(for roomID: UUID, now: Date = Date()) {
        guard !isNextCoatLocked(for: roomID, asOf: now),
              var coat = nextApplicableCoat(for: roomID),
              let room = room(roomID) else { return }

        let type = coat.isPrimer ? data.prefs.primerType : room.paintType
        let minutes = PaintEngine.dryMinutes(type: type,
                                             temperatureC: data.prefs.temperatureC,
                                             humidityPct: data.prefs.humidityPct)
        coat.dryStartedAt = now
        coat.dryMinutes = minutes
        coat.status = .drying
        coat.appliedColorHex = room.colorHex
        coat.notificationID = notifications.scheduleCoatDry(roomName: room.name,
                                                            coatLabel: coat.label,
                                                            after: minutes * 60)
        upsert(coat, \.coats)
        addHistory(HistoryEntry(roomID: roomID, kind: .painted,
                                detail: "\(coat.label) applied in \(room.name)"))
    }

    func revertCoat(_ coat: Coat) {
        notifications.cancel(id: coat.notificationID)
        var c = coat
        c.status = .pending
        c.dryStartedAt = nil
        c.dryMinutes = 0
        c.notificationID = nil
        c.appliedColorHex = nil
        upsert(c, \.coats)
        // Drop the most recent matching "painted" history entry.
        if let idx = data.history.lastIndex(where: { $0.roomID == coat.roomID && $0.kind == .painted }) {
            data.history.remove(at: idx)
            save()
        }
    }

    /// Transition drying→done for any coat whose window elapsed; append a single
    /// "dried" history entry. Cheap: only writes when something actually changes.
    func reconcile(asOf now: Date) {
        var changed = false
        for i in data.coats.indices {
            if data.coats[i].status == .drying, data.coats[i].isDry(asOf: now) {
                data.coats[i].status = .done
                let label = data.coats[i].label
                let roomID = data.coats[i].roomID
                let roomName = room(roomID)?.name ?? "room"
                data.history.append(HistoryEntry(roomID: roomID, kind: .dried,
                                                 detail: "\(label) dried in \(roomName)"))
                changed = true
            }
        }
        if changed { save() }
    }

    func coatsDone(for roomID: UUID) -> Int { coats(for: roomID).filter { $0.status == .done }.count }
    func coatsTotal(for roomID: UUID) -> Int { coats(for: roomID).count }
    func roomProgress(for roomID: UUID) -> Double {
        let total = coatsTotal(for: roomID)
        guard total > 0 else { return 0 }
        return Double(coatsDone(for: roomID)) / Double(total)
    }

    /// Count of coats currently drying across all rooms — used for the tab badge.
    func dryingCount(asOf now: Date) -> Int {
        data.coats.filter { $0.dryStartedAt != nil && !$0.isDry(asOf: now) }.count
    }
    /// Rooms where the next coat is unlocked & pending — "ready to paint".
    func readyCount(asOf now: Date) -> Int {
        rooms.filter { nextApplicableCoat(for: $0.id) != nil && !isNextCoatLocked(for: $0.id, asOf: now) }.count
    }

    // MARK: Color mixes

    var mixes: [ColorMix] { data.mixes.sorted { $0.createdAt > $1.createdAt } }
    func addMix(_ m: ColorMix) { upsert(m, \.mixes) }
    func updateMix(_ m: ColorMix) { upsert(m, \.mixes) }
    func deleteMix(_ m: ColorMix) { remove(m, \.mixes) }

    // MARK: Inventory

    var cans: [PaintCan] { data.cans.sorted { $0.label < $1.label } }
    func addCan(_ c: PaintCan) { upsert(c, \.cans) }
    func updateCan(_ c: PaintCan) { upsert(c, \.cans) }
    func deleteCan(_ c: PaintCan) { remove(c, \.cans) }

    func remainingLiters(of type: PaintType) -> Double {
        data.cans.filter { $0.paintType == type }.reduce(0) { $0 + $1.remainingLiters }
    }
    /// Liters short of the plan for a room (0 if enough stock of the room's type).
    func shortfall(for roomID: UUID) -> Double {
        guard let cov = coverage(for: roomID), let r = room(roomID) else { return 0 }
        let have = remainingLiters(of: r.paintType)
        return max(0, cov.paintLiters - have)
    }

    // MARK: Cost

    var costItems: [CostItem] { data.costItems }
    func addCost(_ c: CostItem) { upsert(c, \.costItems) }
    func updateCost(_ c: CostItem) { upsert(c, \.costItems) }
    func deleteCost(_ c: CostItem) { remove(c, \.costItems) }
    var totalCost: Double { data.costItems.reduce(0) { $0 + $1.total } }
    func cost(in category: CostCategory) -> Double {
        data.costItems.filter { $0.category == category }.reduce(0) { $0 + $1.total }
    }

    /// Prefill paint + primer cost lines from the engine for a room.
    func estimateCosts(for roomID: UUID, paintUnitCost: Double, primerUnitCost: Double) {
        guard let cov = coverage(for: roomID), let r = room(roomID) else { return }
        data.costItems.removeAll { $0.roomID == roomID && ($0.category == .paint || $0.category == .primer) }
        if cov.paintCans > 0 {
            data.costItems.append(CostItem(roomID: roomID, title: "\(r.name) — \(r.paintType.displayName)",
                                           category: .paint, quantity: Double(cov.paintCans), unitCost: paintUnitCost))
        }
        if cov.primerCans > 0 {
            data.costItems.append(CostItem(roomID: roomID, title: "\(r.name) — Primer",
                                           category: .primer, quantity: Double(cov.primerCans), unitCost: primerUnitCost))
        }
        save()
    }

    // MARK: Prep tasks

    var prepTasks: [PrepTask] { data.prepTasks }
    func addPrep(_ t: PrepTask) { upsert(t, \.prepTasks) }
    func updatePrep(_ t: PrepTask) { upsert(t, \.prepTasks) }
    func deletePrep(_ t: PrepTask) { remove(t, \.prepTasks) }
    func togglePrep(_ t: PrepTask) { var x = t; x.isDone.toggle(); upsert(x, \.prepTasks) }
    var prepProgress: Double {
        guard !data.prepTasks.isEmpty else { return 0 }
        return Double(data.prepTasks.filter { $0.isDone }.count) / Double(data.prepTasks.count)
    }

    // MARK: Defects

    var defects: [DefectNote] { data.defects.sorted { $0.createdAt > $1.createdAt } }
    func addDefect(_ d: DefectNote) { upsert(d, \.defects) }
    func updateDefect(_ d: DefectNote) { upsert(d, \.defects) }
    func deleteDefect(_ d: DefectNote) {
        PhotoStore.shared.delete(named: d.imageFileName)
        remove(d, \.defects)
    }
    func markDefectFixed(_ d: DefectNote) {
        var x = d; x.isFixed = true
        upsert(x, \.defects)
        let roomName = room(d.roomID)?.name ?? "project"
        addHistory(HistoryEntry(roomID: d.roomID, kind: .fixed,
                                detail: "\(d.kind.displayName) fixed in \(roomName)"))
    }
    var openDefectCount: Int { data.defects.filter { !$0.isFixed }.count }

    // MARK: Photo pairs

    var photoPairs: [PhotoPair] { data.photoPairs.sorted { $0.createdAt > $1.createdAt } }
    func addPhotoPair(_ p: PhotoPair) { upsert(p, \.photoPairs) }
    func updatePhotoPair(_ p: PhotoPair) { upsert(p, \.photoPairs) }
    func deletePhotoPair(_ p: PhotoPair) {
        PhotoStore.shared.delete(named: p.beforeFileName)
        PhotoStore.shared.delete(named: p.afterFileName)
        remove(p, \.photoPairs)
    }

    // MARK: History

    var history: [HistoryEntry] { data.history.sorted { $0.date > $1.date } }
    func addHistory(_ h: HistoryEntry) { data.history.append(h); save() }
    func clearHistory() { data.history.removeAll(); save() }

    // MARK: Presets

    var presets: [PaintPreset] { data.presets }
    func addPreset(_ p: PaintPreset) { upsert(p, \.presets) }
    func updatePreset(_ p: PaintPreset) { upsert(p, \.presets) }
    func deletePreset(_ p: PaintPreset) { remove(p, \.presets) }
    func applyPreset(_ p: PaintPreset) {
        updatePrefs { prefs in
            prefs.paintType = p.paintType
            prefs.surface = p.surface
            prefs.defaultCanLiters = p.canLiters
        }
    }

    // MARK: Reset / backup support

    func resetAll() {
        data.coats.forEach { notifications.cancel(id: $0.notificationID) }
        PhotoStore.shared.clearAll()
        data = SampleData.make()
        flush()
    }
}
