//
//  PDFReport.swift
//  CoatCast
//
//  Builds a shareable PDF of the project plan (liters & cost per room, coats
//  done/remaining) using UIGraphicsPDFRenderer + NSString drawing. iOS 14 safe
//  (no AttributedString). Returns a temp-file URL for the share sheet.
//

import UIKit

enum PDFReport {

    static func generate(store: AppStore,
                         currencySymbol: String,
                         volumeUnit: VolumeUnit,
                         measureUnit: MeasureUnit) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter @72dpi
        let margin: CGFloat = 48
        let maxY: CGFloat = pageRect.height - margin
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CoatCast-Report.pdf")

        func vol(_ liters: Double) -> String {
            "\(num(UnitConvert.volumeToDisplay(liters, volumeUnit))) \(volumeUnit.short)"
        }
        func area(_ m2: Double) -> String {
            "\(num(UnitConvert.areaToDisplay(m2, measureUnit))) \(measureUnit.areaShort)"
        }
        func num(_ v: Double) -> String {
            String(format: "%.2f", v)
        }

        do {
            try renderer.writePDF(to: url) { ctx in
                var y: CGFloat = margin
                ctx.beginPage()

                func newPageIfNeeded(_ needed: CGFloat) {
                    if y + needed > maxY { ctx.beginPage(); y = margin }
                }
                @discardableResult
                func draw(_ text: String, size: CGFloat, weight: UIFont.Weight,
                          color: UIColor = UIColor(hex: 0x0E3A36), indent: CGFloat = 0) -> CGFloat {
                    newPageIfNeeded(size + 8)
                    let font = UIFont.systemFont(ofSize: size, weight: weight)
                    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                    (text as NSString).draw(at: CGPoint(x: margin + indent, y: y), withAttributes: attrs)
                    y += size + 8
                    return y
                }
                func rule() {
                    newPageIfNeeded(12)
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: margin, y: y))
                    path.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
                    UIColor(hex: 0xD8E6E9).setStroke()
                    path.lineWidth = 1
                    path.stroke()
                    y += 14
                }

                // Header
                draw("COAT CAST", size: 26, weight: .heavy, color: UIColor(hex: 0x0D9488))
                draw("Project Report — \(Formatters.date(Date()))", size: 12, weight: .regular,
                     color: UIColor(hex: 0x4A6B66))
                rule()

                // Summary
                let totalPaint = store.rooms.compactMap { store.coverage(for: $0.id)?.paintLiters }.reduce(0, +)
                let totalPrimer = store.rooms.compactMap { store.coverage(for: $0.id)?.primerLiters }.reduce(0, +)
                let coatsDone = store.rooms.reduce(0) { $0 + store.coatsDone(for: $1.id) }
                let coatsTotal = store.rooms.reduce(0) { $0 + store.coatsTotal(for: $1.id) }

                draw("Summary", size: 16, weight: .bold)
                draw("Rooms: \(store.rooms.count)", size: 12, weight: .regular, indent: 8)
                draw("Total paint: \(vol(totalPaint))    Primer: \(vol(totalPrimer))", size: 12, weight: .regular, indent: 8)
                draw("Coats complete: \(coatsDone) / \(coatsTotal)", size: 12, weight: .regular, indent: 8)
                draw("Total cost: \(currencySymbol)\(num(store.totalCost))", size: 12, weight: .regular, indent: 8)
                draw("Open defects: \(store.openDefectCount)    Prep: \(Int(store.prepProgress*100))%",
                     size: 12, weight: .regular, indent: 8)
                rule()

                // Per room
                draw("Rooms", size: 16, weight: .bold)
                if store.rooms.isEmpty {
                    draw("No rooms added.", size: 12, weight: .regular, indent: 8)
                }
                for room in store.rooms {
                    guard let cov = store.coverage(for: room.id) else { continue }
                    y += 4
                    draw(room.name, size: 14, weight: .semibold, color: UIColor(hex: 0x0E3A36))
                    draw("\(room.paintType.displayName) · \(room.surface.displayName) · \(cov.coats) coats",
                         size: 11, weight: .regular, color: UIColor(hex: 0x4A6B66), indent: 8)
                    draw("Net area: \(area(cov.netArea))    Coverage: \(num(cov.coverage)) \(measureUnit.areaShort)/\(volumeUnit.short)",
                         size: 11, weight: .regular, indent: 8)
                    draw("Paint: \(vol(cov.paintLiters)) (\(cov.paintCans) cans)    Primer: \(vol(cov.primerLiters))",
                         size: 11, weight: .regular, indent: 8)
                    draw("Coats done: \(store.coatsDone(for: room.id)) / \(store.coatsTotal(for: room.id))",
                         size: 11, weight: .regular, indent: 8)
                    let roomCost = store.costItems.filter { $0.roomID == room.id }.reduce(0) { $0 + $1.total }
                    if roomCost > 0 {
                        draw("Room cost: \(currencySymbol)\(num(roomCost))", size: 11, weight: .regular, indent: 8)
                    }
                }

                rule()
                draw("Generated by Coat Cast · Plan the paint, not the mess.",
                     size: 10, weight: .regular, color: UIColor(hex: 0x8FA9A4))
            }
            return url
        } catch {
            return nil
        }
    }
}
