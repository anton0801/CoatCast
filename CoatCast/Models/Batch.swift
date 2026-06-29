import Foundation

struct BatchLog: Codable {
    let pour: [String: String]
    let runners: [String: String]
    let gateURL: String?
    let gateMode: String?
    let cold: Bool
    let sealStamped: Bool
    let sealBroke: Bool
    let sealAt: Date?
}

struct Batch {
    var pour: [String: String] = [:]
    var runners: [String: String] = [:]
    var gateURL: String? = nil
    var gateMode: String? = nil
    var cold: Bool = true
    var solid: Bool = false
    var tempered: Bool = false
    var sealStamped: Bool = false
    var sealBroke: Bool = false
    var sealAt: Date? = nil

    var poured: Bool { !pour.isEmpty }
    var organicCool: Bool { pour["af_status"] == "Organic" }

    var sealDue: Bool {
        guard !sealStamped && !sealBroke else { return false }
        if let date = sealAt {
            return Date().timeIntervalSince(date) / 86400 >= 3
        }
        return true
    }

    static func reline(from log: BatchLog) -> Batch {
        var b = Batch()
        b.pour = log.pour
        b.runners = log.runners
        b.gateURL = log.gateURL
        b.gateMode = log.gateMode
        b.cold = log.cold
        b.sealStamped = log.sealStamped
        b.sealBroke = log.sealBroke
        b.sealAt = log.sealAt
        return b
    }

    func log() -> BatchLog {
        BatchLog(
            pour: pour,
            runners: runners,
            gateURL: gateURL,
            gateMode: gateMode,
            cold: cold,
            sealStamped: sealStamped,
            sealBroke: sealBroke,
            sealAt: sealAt
        )
    }
}

enum Tap: Equatable {
    case idle
    case askSeal
    case cast
    case scrap
}
