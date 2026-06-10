//
//  Models.swift
//  CoatCast
//
//  All domain models — value types, Codable/Identifiable/Equatable, UUID ids,
//  foreign keys via UUID. Computed properties are NOT persisted. The single
//  `AppData` aggregate is the one JSON document on disk.
//

import Foundation

// MARK: - Domain enums

enum PaintType: String, Codable, CaseIterable, Identifiable {
    case water, acrylic, enamel, primer
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .water:   return "Water-Based"
        case .acrylic: return "Acrylic"
        case .enamel:  return "Enamel"
        case .primer:  return "Primer"
        }
    }
    var icon: String {
        switch self {
        case .water:   return "drop.fill"
        case .acrylic: return "paintbrush.pointed.fill"
        case .enamel:  return "sparkles"
        case .primer:  return "square.layers.3d.up.fill"
        }
    }
    /// Theoretical spreading rate on a sealed wall, m² per liter, 1 coat.
    var baseCoverage: Double {
        switch self {
        case .water:   return 11.0
        case .acrylic: return 10.0
        case .enamel:  return 13.0
        case .primer:  return 9.0
        }
    }
    /// Base inter-coat dry/recoat time (minutes) at reference climate 20°C / 50% RH.
    var baseRecoatMinutes: Double {
        switch self {
        case .water:   return 120
        case .acrylic: return 180
        case .enamel:  return 480
        case .primer:  return 60
        }
    }
}

enum Surface: String, Codable, CaseIterable, Identifiable {
    case walls, ceiling, wood, metal
    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .walls:   return "square.split.bottomrightquarter"
        case .ceiling: return "square.dashed"
        case .wood:    return "tree.fill"
        case .metal:   return "gearshape.fill"
        }
    }
    /// Multiplies effective coverage. <1 porous (drinks paint), >1 non-porous.
    var absorptionFactor: Double {
        switch self {
        case .walls:   return 1.00
        case .ceiling: return 0.95
        case .wood:    return 0.80
        case .metal:   return 1.15
        }
    }
    var defaultCoats: Int {
        switch self {
        case .walls: return 2
        case .ceiling: return 2
        case .wood: return 3
        case .metal: return 2
        }
    }
}

enum Finish: String, Codable, CaseIterable, Identifiable {
    case matte, satin, gloss
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .matte: return "circle.fill"
        case .satin: return "circle.lefthalf.filled"
        case .gloss: return "sun.max.fill"
        }
    }
    var recommendedCoats: Int {
        switch self {
        case .matte: return 2
        case .satin: return 2
        case .gloss: return 3
        }
    }
    var subtitle: String {
        switch self {
        case .matte: return "Flat, hides imperfections"
        case .satin: return "Soft sheen, easy to clean"
        case .gloss: return "High shine, extra coat"
        }
    }
}

enum OpeningKind: String, Codable, CaseIterable, Identifiable {
    case window, door
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var icon: String { self == .window ? "window.vertical.closed" : "door.left.hand.closed" }
}

enum CoatStatus: String, Codable {
    case pending, drying, done
}

enum CostCategory: String, Codable, CaseIterable, Identifiable {
    case paint, primer, consumable
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .paint: return "paintbrush.fill"
        case .primer: return "square.layers.3d.up.fill"
        case .consumable: return "shippingbox.fill"
        }
    }
}

enum DefectKind: String, Codable, CaseIterable, Identifiable {
    case drip, missedSpot, bubble, other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .drip: return "Drip / Run"
        case .missedSpot: return "Missed Spot"
        case .bubble: return "Bubble"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .drip: return "drop.triangle.fill"
        case .missedSpot: return "circle.dotted"
        case .bubble: return "bubbles.and.sparkles.fill"
        case .other: return "exclamationmark.triangle.fill"
        }
    }
}

enum HistoryKind: String, Codable, CaseIterable, Identifiable {
    case painted, dried, fixed
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .painted: return "paintbrush.fill"
        case .dried: return "checkmark.seal.fill"
        case .fixed: return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - Preferences (onboarding O1–O4 + climate)

struct PaintPrefs: Codable, Equatable {
    var paintType: PaintType = .water
    var surface: Surface = .walls
    var temperatureC: Double = 20
    var humidityPct: Double = 50
    var finish: Finish = .matte
    var primerType: PaintType = .primer
    var defaultCanLiters: Double = 2.5
    var defaultPrimerCanLiters: Double = 2.5

    /// Coats suggested by the surface + finish combination.
    var recommendedCoats: Int { max(surface.defaultCoats, finish.recommendedCoats) }
}

// MARK: - Core entities

struct PaintRoom: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var wallArea: Double = 0          // m², gross
    var targetCoats: Int = 2
    var paintType: PaintType = .water
    var surface: Surface = .walls
    var colorHex: UInt = 0x5EEAD4
    var canLiters: Double = 2.5
    var notes: String = ""
    var createdAt: Date = Date()
}

struct Opening: Identifiable, Codable, Equatable {
    var id = UUID()
    var roomID: UUID
    var kind: OpeningKind = .window
    var width: Double = 0             // m
    var height: Double = 0            // m
    var count: Int = 1
    var area: Double { max(0, width) * max(0, height) * Double(max(0, count)) }
}

struct Coat: Identifiable, Codable, Equatable {
    var id = UUID()
    var roomID: UUID
    var index: Int                    // 1-based order (primer uses isPrimer + index 0)
    var isPrimer: Bool = false
    var status: CoatStatus = .pending
    var dryStartedAt: Date? = nil     // set on apply
    var dryMinutes: Double = 0        // snapshot at apply time
    var appliedColorHex: UInt? = nil
    var notificationID: String? = nil
    var createdAt: Date = Date()

    var dryEndsAt: Date? {
        guard let s = dryStartedAt else { return nil }
        return s.addingTimeInterval(dryMinutes * 60)
    }
    func isDry(asOf now: Date) -> Bool {
        guard let end = dryEndsAt else { return false }
        return now >= end
    }
    func remainingSeconds(asOf now: Date) -> Int {
        guard let end = dryEndsAt else { return 0 }
        return max(0, Int(end.timeIntervalSince(now).rounded(.up)))
    }
    func progress(asOf now: Date) -> Double {
        guard let start = dryStartedAt, dryMinutes > 0 else { return status == .done ? 1 : 0 }
        let total = dryMinutes * 60
        let elapsed = now.timeIntervalSince(start)
        return min(1, max(0, elapsed / total))
    }
    var label: String { isPrimer ? "Primer" : "Coat \(index)" }
}

struct Pigment: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var parts: Double = 1
    var colorHex: UInt = 0x000000
}

struct ColorMix: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var baseName: String = "White Base"
    var baseParts: Double = 10
    var pigments: [Pigment] = []
    var resultHex: UInt = 0xCCCCCC
    var roomID: UUID? = nil
    var createdAt: Date = Date()

    var totalParts: Double { baseParts + pigments.reduce(0) { $0 + $1.parts } }
}

struct PaintCan: Identifiable, Codable, Equatable {
    var id = UUID()
    var label: String
    var paintType: PaintType = .water
    var colorHex: UInt = 0xFFFFFF
    var volumeLiters: Double = 2.5
    var remainingLiters: Double = 2.5
    var roomID: UUID? = nil

    var fillFraction: Double { volumeLiters > 0 ? min(1, max(0, remainingLiters / volumeLiters)) : 0 }
}

struct CostItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var roomID: UUID? = nil
    var title: String
    var category: CostCategory = .paint
    var quantity: Double = 1
    var unitCost: Double = 0
    var total: Double { quantity * unitCost }
}

struct PrepTask: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isDone: Bool = false
    var roomID: UUID? = nil
    var category: String = "Prep"
}

struct DefectNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var roomID: UUID? = nil
    var kind: DefectKind = .drip
    var fixAction: String = ""
    var imageFileName: String? = nil
    var isFixed: Bool = false
    var createdAt: Date = Date()
}

struct PhotoPair: Identifiable, Codable, Equatable {
    var id = UUID()
    var roomID: UUID? = nil
    var beforeFileName: String? = nil
    var afterFileName: String? = nil
    var caption: String = ""
    var createdAt: Date = Date()
}

struct HistoryEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var roomID: UUID? = nil
    var kind: HistoryKind = .painted
    var detail: String
    var date: Date = Date()
}

struct PaintPreset: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var paintType: PaintType = .water
    var surface: Surface = .walls
    var coverage: Double = 10
    var canLiters: Double = 2.5
    var colorHex: UInt = 0xFFFFFF
}

// MARK: - Root aggregate (single JSON document)

struct AppData: Codable {
    var schemaVersion: Int = 1
    var prefs: PaintPrefs = PaintPrefs()
    var rooms: [PaintRoom] = []
    var openings: [Opening] = []
    var coats: [Coat] = []
    var mixes: [ColorMix] = []
    var cans: [PaintCan] = []
    var costItems: [CostItem] = []
    var prepTasks: [PrepTask] = []
    var defects: [DefectNote] = []
    var photoPairs: [PhotoPair] = []
    var history: [HistoryEntry] = []
    var presets: [PaintPreset] = []
}
