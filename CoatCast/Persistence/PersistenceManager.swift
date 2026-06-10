//
//  PersistenceManager.swift
//  CoatCast
//
//  Offline persistence: a single Codable AppData JSON document in Documents,
//  written atomically and debounced. Photos are stored as separate blobs.
//  All iOS 14 safe (Foundation only).
//

import Foundation

final class PersistenceManager {
    static let shared = PersistenceManager()

    let fileName = "coatcast.json"
    private var pendingSave: DispatchWorkItem?

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    var fileURL: URL { documentsURL.appendingPathComponent(fileName) }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: Load / Save

    func load() -> AppData {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode(AppData.self, from: data) else {
            let seed = SampleData.make()
            saveNow(seed)
            return seed
        }
        return decoded
    }

    /// Debounced save — coalesces rapid edits (typing) into one disk write.
    func save(_ data: AppData) {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow(data) }
        pendingSave = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Synchronous write — used on scenePhase background to guarantee no loss.
    func saveNow(_ data: AppData) {
        pendingSave?.cancel()
        guard let encoded = try? encoder.encode(data) else { return }
        try? encoded.write(to: fileURL, options: [.atomic])
    }

    func flush(_ data: AppData) { saveNow(data) }
}
