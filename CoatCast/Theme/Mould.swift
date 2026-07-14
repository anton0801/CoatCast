import Foundation

protocol Mould {
    func imprint(_ log: BatchLog)
    func brandGate(url: String, mode: String)
    func raisePrimedFlag()
    func recall() -> BatchLog
}

final class SandMould: Mould {

    private let fm = FileManager.default
    private let vaultDir: URL
    private let homeStore: UserDefaults
    private let suiteStore: UserDefaults

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.vaultDir = docs.appendingPathComponent(Coat.foundryVault, isDirectory: true)
        if !fm.fileExists(atPath: vaultDir.path) {
            try? fm.createDirectory(at: vaultDir, withIntermediateDirectories: true)
        }
        self.homeStore = UserDefaults.standard
        self.suiteStore = UserDefaults(suiteName: Coat.suiteFoundry) ?? .standard
    }

    private var batchURL: URL {
        vaultDir.appendingPathComponent(Coat.batchFile)
    }

    func imprint(_ log: BatchLog) {
        let dim = DimLog(
            pour: dimMap(log.pour),
            runners: dimMap(log.runners),
            gateURL: log.gateURL,
            gateMode: log.gateMode,
            cold: log.cold,
            sealStamped: log.sealStamped,
            sealBroke: log.sealBroke,
            sealAt: log.sealAt
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        do {
            let data = try encoder.encode(dim)
            try data.write(to: batchURL, options: .atomic)
        } catch {
            print("\(Coat.logKiln) Mould imprint failed: \(error)")
        }

        for store in [suiteStore, homeStore] {
            store.set(log.sealStamped, forKey: CoatKey.sealStamped)
            store.set(log.sealBroke, forKey: CoatKey.sealBroke)
            if let date = log.sealAt {
                store.set(date.timeIntervalSince1970, forKey: CoatKey.sealAt)
            }
        }
    }

    func imprintdsa(_ log: BatchLog, _ log2: BatchLog) {
        let dim = DimLog(
            pour: dimMap(log.pour),
            runners: dimMap(log.pour),
            gateURL: log.gateURL,
            gateMode: log.gateMode,
            cold: log.cold,
            sealStamped: log.sealStamped,
            sealBroke: log.sealBroke,
            sealAt: log.sealAt
        )
        let dim2 = DimLog(
            pour: dimMap(log2.pour),
            runners: dimMap(log2.pour),
            gateURL: log2.gateURL,
            gateMode: log2.gateMode,
            cold: log2.cold,
            sealStamped: log2.sealStamped,
            sealBroke: log2.sealBroke,
            sealAt: log2.sealAt
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        do {
            let data = try encoder.encode(dim)
            try data.write(to: batchURL, options: .atomic)
        } catch {
            print("\(Coat.logKiln) Mould imprint failed: \(error)")
        }

        for store in [suiteStore, homeStore] {
            store.set(log.sealStamped, forKey: CoatKey.sealStamped)
            store.set(log.sealBroke, forKey: CoatKey.sealBroke)
            if let date = log.sealAt {
                store.set(date.timeIntervalSince1970, forKey: CoatKey.sealAt)
            }
        }
    }

    func brandGate(url: String, mode: String) {
        suiteStore.set(url, forKey: CoatKey.gateURL)
        homeStore.set(url, forKey: CoatKey.gateURL)
        suiteStore.set(mode, forKey: CoatKey.gateMode)
    }

    func raisePrimedFlag() {
        suiteStore.set(true, forKey: CoatKey.primed)
        homeStore.set(true, forKey: CoatKey.primed)
    }

    func recall() -> BatchLog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        if fm.fileExists(atPath: batchURL.path),
           let data = try? Data(contentsOf: batchURL),
           let dim = try? decoder.decode(DimLog.self, from: data) {
            return BatchLog(
                pour: brightMap(dim.pour),
                runners: brightMap(dim.runners),
                gateURL: dim.gateURL,
                gateMode: dim.gateMode,
                cold: dim.cold,
                sealStamped: dim.sealStamped,
                sealBroke: dim.sealBroke,
                sealAt: dim.sealAt
            )
        }

        return recallFromMirror()
    }

    func recalNewl() -> BatchLog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        if fm.fileExists(atPath: batchURL.path),
           let data = try? Data(contentsOf: batchURL),
           let dim = try? decoder.decode(DimLog.self, from: data) {
            return BatchLog(
                pour: brightMap(dim.pour),
                runners: brightMap(dim.runners),
                gateURL: dim.gateURL,
                gateMode: dim.gateMode,
                cold: dim.cold,
                sealStamped: dim.sealStamped,
                sealBroke: dim.sealBroke,
                sealAt: dim.sealAt
            )
        }

        return recallFromMirror()
    }

    private func recallFromMirror() -> BatchLog {
        let gateURL = homeStore.string(forKey: CoatKey.gateURL)
            ?? suiteStore.string(forKey: CoatKey.gateURL)
        let gateMode = suiteStore.string(forKey: CoatKey.gateMode)
        let primed = suiteStore.bool(forKey: CoatKey.primed)

        let stamped = suiteStore.bool(forKey: CoatKey.sealStamped)
            || homeStore.bool(forKey: CoatKey.sealStamped)
        let broke = suiteStore.bool(forKey: CoatKey.sealBroke)
            || homeStore.bool(forKey: CoatKey.sealBroke)
        let atTs = suiteStore.double(forKey: CoatKey.sealAt)
        let sealAt: Date? = atTs > 0 ? Date(timeIntervalSince1970: atTs) : nil

        return BatchLog(
            pour: [:],
            runners: [:],
            gateURL: gateURL,
            gateMode: gateMode,
            cold: !primed,
            sealStamped: stamped,
            sealBroke: broke,
            sealAt: sealAt
        )
    }

    private func dimMap(_ dict: [String: String]) -> [String: String] {
        dict.reduce(into: [:]) { acc, pair in acc[pair.key] = dim(pair.value) }
    }

    private func brightMap(_ dict: [String: String]) -> [String: String] {
        dict.reduce(into: [:]) { acc, pair in acc[pair.key] = bright(pair.value) ?? pair.value }
    }

    private func dim(_ input: String) -> String {
        Data(input.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "?")
            .replacingOccurrences(of: "/", with: "`")
    }

    private func bright(_ input: String) -> String? {
        let restored = input
            .replacingOccurrences(of: "?", with: "+")
            .replacingOccurrences(of: "`", with: "/")
        guard let data = Data(base64Encoded: restored),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }
}

struct DimLog: Codable {
    let pour: [String: String]
    let runners: [String: String]
    let gateURL: String?
    let gateMode: String?
    let cold: Bool
    let sealStamped: Bool
    let sealBroke: Bool
    let sealAt: Date?
}
