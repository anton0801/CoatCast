//
//  PaintEngine.swift
//  CoatCast
//
//  The app's differentiator: a pure, stateless calculation engine for coverage
//  (liters of paint + primer, can counts, leftover), climate-adjusted drying
//  windows, color-mix scaling and unit conversion. All math is SI (m², liters);
//  display-unit conversion happens at the view layer.
//

import Foundation

struct CoverageResult: Equatable {
    var netArea: Double = 0          // m² after openings
    var coats: Int = 0
    var coverage: Double = 0         // effective m²/L used for paint
    var paintLiters: Double = 0      // raw need (coats included)
    var paintCans: Int = 0           // rounded up to can size
    var remainderLiters: Double = 0  // leftover in the last paint can
    var primerLiters: Double = 0     // primer is always 1 coat
    var primerCans: Int = 0
}

enum PaintEngine {

    // MARK: Coverage

    /// Effective spreading rate (m²/L per coat) for a paint type on a surface.
    static func effectiveCoverage(_ type: PaintType, _ surface: Surface) -> Double {
        max(0.1, type.baseCoverage * surface.absorptionFactor)
    }

    static func coverage(netArea: Double,
                         coats: Int,
                         type: PaintType,
                         surface: Surface,
                         primerType: PaintType = .primer,
                         canLiters: Double = 2.5,
                         primerCanLiters: Double = 2.5) -> CoverageResult {
        let area = max(0, netArea)
        let cov = effectiveCoverage(type, surface)
        let n = max(0, coats)

        let paintLiters = (area * Double(n)) / cov
        let paintCans = canLiters > 0 ? Int(ceil(paintLiters / canLiters)) : 0
        let remainder = max(0, Double(paintCans) * canLiters - paintLiters)

        let primerCov = effectiveCoverage(primerType, surface)
        let primerLiters = area / primerCov
        let primerCans = primerCanLiters > 0 ? Int(ceil(primerLiters / primerCanLiters)) : 0

        return CoverageResult(netArea: area,
                              coats: n,
                              coverage: cov,
                              paintLiters: paintLiters,
                              paintCans: paintCans,
                              remainderLiters: remainder,
                              primerLiters: primerLiters,
                              primerCans: primerCans)
    }

    /// Net wall area after subtracting all opening areas.
    static func netArea(wallArea: Double, openings: [Opening]) -> Double {
        max(0, wallArea - openings.reduce(0) { $0 + $1.area })
    }

    // MARK: Drying window (the climate engine)

    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }

    /// Multiplier off the 20°C / 50% RH reference. Colder & more humid → longer.
    static func climateMultiplier(temperatureC T: Double, humidityPct H: Double) -> Double {
        let tempF = clamp(1 + (20 - T) * 0.04, 0.6, 2.5)
        let humF  = clamp(1 + (H - 50) * 0.01, 0.7, 2.0)
        return clamp(tempF * humF, 0.5, 4.0)
    }

    /// Inter-coat dry time in minutes for a paint type at a given climate.
    static func dryMinutes(type: PaintType, temperatureC: Double, humidityPct: Double) -> Double {
        (type.baseRecoatMinutes * climateMultiplier(temperatureC: temperatureC, humidityPct: humidityPct))
            .rounded()
    }

    // MARK: Color mix scaling ("repeat exactly")

    static func scaleMix(baseParts: Double, pigmentParts: [Double], toVolume: Double)
        -> (base: Double, pigments: [Double]) {
        let total = baseParts + pigmentParts.reduce(0, +)
        guard total > 0 else { return (0, pigmentParts.map { _ in 0 }) }
        let perPart = toVolume / total
        return (baseParts * perPart, pigmentParts.map { $0 * perPart })
    }
}

// MARK: - Unit conversion + display units

enum MeasureUnit: String, CaseIterable, Identifiable {
    case meters, feet            // areas: m² vs ft²
    var id: String { rawValue }
    var areaShort: String { self == .meters ? "m²" : "ft²" }
    var lengthShort: String { self == .meters ? "m" : "ft" }
    var displayName: String { self == .meters ? "Metric (m²)" : "Imperial (ft²)" }
}

enum VolumeUnit: String, CaseIterable, Identifiable {
    case liters, gallons
    var id: String { rawValue }
    var short: String { self == .liters ? "L" : "gal" }
    var displayName: String { self == .liters ? "Liters (L)" : "Gallons (gal)" }
}

enum UnitConvert {
    static let m2PerFt2 = 0.092903           // 1 ft² = 0.092903 m²
    static let litersPerGallon = 3.785411784

    /// SI m² → displayed value in the chosen unit.
    static func areaToDisplay(_ m2: Double, _ u: MeasureUnit) -> Double {
        u == .feet ? m2 / m2PerFt2 : m2
    }
    /// Displayed area value → SI m².
    static func areaToSI(_ value: Double, _ u: MeasureUnit) -> Double {
        u == .feet ? value * m2PerFt2 : value
    }
    static func lengthToDisplay(_ m: Double, _ u: MeasureUnit) -> Double {
        u == .feet ? m / 0.3048 : m
    }
    static func lengthToSI(_ value: Double, _ u: MeasureUnit) -> Double {
        u == .feet ? value * 0.3048 : value
    }
    static func volumeToDisplay(_ liters: Double, _ u: VolumeUnit) -> Double {
        u == .gallons ? liters / litersPerGallon : liters
    }
    static func volumeToSI(_ value: Double, _ u: VolumeUnit) -> Double {
        u == .gallons ? value * litersPerGallon : value
    }
}
