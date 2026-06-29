import Foundation
import AppsFlyerLib
import FirebaseCore
import FirebaseMessaging
import WebKit

protocol Ladle {
    func pour(charge: [String: Any]) async throws -> String
}

final class CastLadle: Ladle {

    private let session: URLSession
    private let arc: [Double] = [99.0, 198.0, 396.0]
    private let cap = 3
    private let agent: String = WKWebView().value(forKey: "userAgent") as? String ?? ""

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    func pour(charge: [String: Any]) async throws -> String {
        let request = try mix(charge)

        func ring(_ n: Int, carrying: Error) async throws -> String {
            do {
                return try await tap(request)
            } catch let slip as Slip {
                if slip.isSealed { throw slip }
                let next = n + 1
                guard next < cap else { throw slip }
                if case .overheated(let cool) = slip {
                    try await dwell(cool)
                } else {
                    try await dwell(arc[n])
                }
                return try await ring(next, carrying: slip)
            } catch {
                let next = n + 1
                guard next < cap else { throw error }
                try await dwell(arc[n])
                return try await ring(next, carrying: error)
            }
        }

        return try await ring(0, carrying: Slip.lostHeat(stage: "pour"))
    }

    private func mix(_ charge: [String: Any]) throws -> URLRequest {
        guard let endpoint = URL(string: Coat.ladleEndpoint) else {
            throw Slip.bentMold(at: "ladle.url")
        }

        var body = charge
        body["os"] = "iOS"
        body["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        body["bundle_id"] = Bundle.main.bundleIdentifier ?? ""
        body["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        body["store_id"] = "id\(Coat.appCode)"
        body["push_token"] = UserDefaults.standard.string(forKey: CoatKey.push)
            ?? Messaging.messaging().fcmToken
        body["locale"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(agent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func tap(_ request: URLRequest) async throws -> String {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw Slip.lostHeat(stage: "tap.response")
        }

        switch http.statusCode {
        case 404:
            throw Slip.gateShut(httpCode: 404)
        case 429:
            let cool = TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "60") ?? 60
            throw Slip.overheated(cooldown: cool)
        case 200...299:
            break
        default:
            throw Slip.lostHeat(stage: "tap.status")
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let solid = root["ok"] as? Bool else {
            throw Slip.dross(at: "tap.body")
        }
        guard solid else {
            throw Slip.batchVoid(reason: "okFalse")
        }
        guard let gate = root["url"] as? String, !gate.isEmpty else {
            throw Slip.dross(at: "tap.url")
        }
        return gate
    }

    private func dwell(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
