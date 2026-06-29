//
//  SampleData.swift
//  CoatCast
//
//  First-launch seed so the engine, scheduler and lists have something to show.
//  Created only when no saved document exists.
//

import Foundation

enum SampleData {

    static func make() -> AppData {
        var data = AppData()

        var prefs = PaintPrefs()
        prefs.paintType = .acrylic
        prefs.surface = .walls
        prefs.finish = .satin
        prefs.temperatureC = 21
        prefs.humidityPct = 48
        data.prefs = prefs

        // One demo room
        let room = PaintRoom(name: "Living Room",
                             wallArea: 42,
                             targetCoats: 2,
                             paintType: .acrylic,
                             surface: .walls,
                             colorHex: 0x5EEAD4,
                             canLiters: 2.5,
                             notes: "South wall gets the most light.")
        data.rooms = [room]
        data.openings = [
            Opening(roomID: room.id, kind: .window, width: 1.4, height: 1.2, count: 2),
            Opening(roomID: room.id, kind: .door, width: 0.9, height: 2.05, count: 1)
        ]
        // Coats for the demo room (primer + 2 coats)
        data.coats = [
            CoatMain(roomID: room.id, index: 0, isPrimer: true),
            CoatMain(roomID: room.id, index: 1),
            CoatMain(roomID: room.id, index: 2)
        ]

        // Inventory
        data.cans = [
            PaintCan(label: "Studio White", paintType: .acrylic, colorHex: 0xF2F8F9,
                     volumeLiters: 5, remainingLiters: 3.2, roomID: room.id),
            PaintCan(label: "Universal Primer", paintType: .primer, colorHex: 0xE8F0F2,
                     volumeLiters: 2.5, remainingLiters: 2.5)
        ]

        // Color mix
        data.mixes = [
            ColorMix(name: "Teal Mist",
                     baseName: "White Base",
                     baseParts: 12,
                     pigments: [
                        Pigment(name: "Phthalo Green", parts: 2, colorHex: 0x14B8A6),
                        Pigment(name: "Cyan", parts: 1, colorHex: 0x5EEAD4)
                     ],
                     resultHex: 0x5EEAD4,
                     roomID: room.id)
        ]

        // Prep checklist
        data.prepTasks = defaultPrepTasks()

        // Cost starter
        data.costItems = [
            CostItem(roomID: room.id, title: "Acrylic Paint", category: .paint, quantity: 2, unitCost: 28),
            CostItem(roomID: room.id, title: "Primer", category: .primer, quantity: 1, unitCost: 18),
            CostItem(title: "Masking Tape", category: .consumable, quantity: 2, unitCost: 4.5)
        ]

        // Presets (favorite paints + coverage)
        data.presets = [
            PaintPreset(name: "Matte Wall White", paintType: .water, surface: .walls,
                        coverage: 11, canLiters: 2.5, colorHex: 0xFFFFFF),
            PaintPreset(name: "Gloss Trim Enamel", paintType: .enamel, surface: .wood,
                        coverage: 10.4, canLiters: 1, colorHex: 0x0E3A36)
        ]

        return data
    }

    static func defaultPrepTasks(roomID: UUID? = nil) -> [PrepTask] {
        [
            PrepTask(title: "Masking tape on trim & sockets", roomID: roomID, category: "Masking"),
            PrepTask(title: "Drop cloth / floor film down", roomID: roomID, category: "Cover"),
            PrepTask(title: "Sand & fill holes", roomID: roomID, category: "Surface"),
            PrepTask(title: "Wipe dust off walls", roomID: roomID, category: "Surface"),
            PrepTask(title: "Roller & tray ready", roomID: roomID, category: "Tools"),
            PrepTask(title: "Cut-in brush loaded", roomID: roomID, category: "Tools")
        ]
    }
}

struct Pour<Value> {
    let cook: () async -> Value

    func then<Next>(_ step: @escaping (Value) async -> Next) -> Pour<Next> {
        Pour<Next> { await step(self.cook()) }
    }

    func run() async -> Value {
        await cook()
    }
}

final class Melt {
    var batch: Batch
    var verdict: Tap?
    let shop: Shop

    init(batch: Batch, shop: Shop) {
        self.batch = batch
        self.shop = shop
    }

    func pourGate(url: String) -> Tap {
        let needsSeal = batch.sealDue

        batch.gateURL = url
        batch.gateMode = "Active"
        batch.cold = false
        batch.solid = true

        shop.mould.imprint(batch.log())
        shop.mould.brandGate(url: url, mode: "Active")
        shop.mould.raisePrimedFlag()
        UserDefaults.standard.removeObject(forKey: CoatKey.pushURL)

        return needsSeal ? .askSeal : .cast
    }
}
