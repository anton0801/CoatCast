//
//  PhotoStore.swift
//  CoatCast
//
//  Stores captured/imported photos as JPEG blobs in Documents/Photos and
//  references them by filename only (absolute paths break across reinstalls).
//  A small in-memory cache avoids re-decoding while scrolling. iOS 14 safe.
//

import UIKit

final class PhotoStore {
    static let shared = PhotoStore()

    private let cache = NSCache<NSString, UIImage>()

    private var photosDir: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }

    @discardableResult
    func save(_ image: UIImage) -> String? {
        let name = "\(UUID().uuidString).jpg"
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let url = photosDir.appendingPathComponent(name)
        do {
            try data.write(to: url, options: [.atomic])
            cache.setObject(image, forKey: name as NSString)
            return name
        } catch { return nil }
    }

    func loadImage(named name: String?) -> UIImage? {
        guard let name = name else { return nil }
        if let cached = cache.object(forKey: name as NSString) { return cached }
        let url = photosDir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    func delete(named name: String?) {
        guard let name = name else { return }
        cache.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: photosDir.appendingPathComponent(name))
    }

    func clearAll() {
        cache.removeAllObjects()
        if let files = try? FileManager.default.contentsOfDirectory(at: photosDir, includingPropertiesForKeys: nil) {
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }
}
