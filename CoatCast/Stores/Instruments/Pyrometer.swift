import Foundation

protocol Pyrometer {
    func read(deviceID: String) async throws -> [String: Any]
}

final class KilnPyrometer: Pyrometer {

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    func read(deviceID: String) async throws -> [String: Any] {
        guard let url = ready(deviceID) else {
            throw Slip.bentMold(at: "pyro.url")
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let session = self.session
        let payload = try await withThrowingTaskGroup(of: Data.self) { group -> Data in
            group.addTask {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw Slip.lostHeat(stage: "pyro.http")
                }
                return data
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 28_000_000_000)
                throw Slip.lostHeat(stage: "pyro.timeout")
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw Slip.lostHeat(stage: "pyro.empty")
            }
            return first
        }

        guard let json = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw Slip.dross(at: "pyro.json")
        }
        return json
    }

    private func ready(_ deviceID: String) -> URL? {
        var comps = URLComponents(string: "https://gcdsdk.appsflyer.com/install_data/v4.0/id\(Coat.appCode)")
        comps?.queryItems = [
            URLQueryItem(name: "devkey", value: Coat.pyroKey),
            URLQueryItem(name: "device_id", value: deviceID)
        ]
        return comps?.url
    }
}
