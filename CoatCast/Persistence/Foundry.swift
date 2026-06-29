import Foundation
import Combine
import AppsFlyerLib

@MainActor
final class Foundry {

    private var batch = Batch()
    private var lined = false
    private var hardened = false
    private var casting = false

    private let shop: Shop

    private let tapSubject = PassthroughSubject<Tap, Never>()
    var tapPublisher: AnyPublisher<Tap, Never> {
        tapSubject.eraseToAnyPublisher()
    }

    private var sealTask: Task<Void, Never>?

    init(shop: Shop) {
        self.shop = shop
    }

    private func ensureLined() {
        guard !lined else { return }
        batch = Batch.reline(from: shop.mould.recall())
        lined = true
    }

    private func harden() -> Bool {
        guard !hardened else { return false }
        hardened = true
        return true
    }

    func warmUp() {
        ensureLined()
    }

    func loadPour(_ raw: [String: Any]) {
        ensureLined()
        batch.pour = raw.mapValues { "\($0)" }
        shop.mould.imprint(batch.log())
    }

    func loadRunners(_ raw: [String: Any]) {
        ensureLined()
        batch.runners = raw.mapValues { "\($0)" }
        shop.mould.imprint(batch.log())
    }

    func castBatch() async {
        ensureLined()
        guard !hardened, !casting else { return }
        casting = true
        defer { casting = false }

        let melt = Melt(batch: batch, shop: shop)

        let line = Pour { melt }
            .then(checkSprue)
            .then(openGate)
            .then(temper)
            .then(pourMains)

        let done = await line.run()
        batch = done.batch
        deliver(done.verdict ?? .idle)
    }

    private func checkSprue(_ melt: Melt) async -> Melt {
        if melt.verdict != nil { return melt }
        if let push = pendingPush() {
            melt.verdict = melt.pourGate(url: push)
        }
        return melt
    }

    private func openGate(_ melt: Melt) async -> Melt {
        if melt.verdict != nil { return melt }
        if !melt.batch.poured { melt.verdict = .idle }
        return melt
    }

    private func temper(_ melt: Melt) async -> Melt {
        if melt.verdict != nil { return melt }
        guard melt.batch.organicCool, melt.batch.cold, !melt.batch.tempered else { return melt }

        melt.batch.tempered = true
        melt.shop.mould.imprint(melt.batch.log())

        try? await Task.sleep(nanoseconds: 5_000_000_000)

        guard !melt.batch.solid else { return melt }

        let id = AppsFlyerLib.shared().getAppsFlyerUID()
        do {
            let fresh = (try await melt.shop.pyrometer.read(deviceID: id)).mapValues { "\($0)" }
            let missing = melt.batch.runners.keys.filter { fresh[$0] == nil }
            var merged = fresh
            for key in missing { merged[key] = melt.batch.runners[key] }
            melt.batch.pour = merged
            melt.shop.mould.imprint(melt.batch.log())
        } catch {
            print("\(Coat.logKiln) temper soft fail: \(error)")
        }

        return melt
    }

    private func pourMains(_ melt: Melt) async -> Melt {
        if melt.verdict != nil { return melt }
        guard melt.batch.poured else {
            melt.verdict = .idle
            return melt
        }
        do {
            let url = try await melt.shop.ladle.pour(charge: melt.batch.pour.mapValues { $0 as Any })
            melt.verdict = melt.pourGate(url: url)
        } catch {
            melt.verdict = .scrap
        }
        return melt
    }

    private func deliver(_ tap: Tap) {
        if case .idle = tap {
            tapSubject.send(.idle)
            return
        }
        if harden() {
            tapSubject.send(tap)
        }
    }

    private func pendingPush() -> String? {
        guard let url = UserDefaults.standard.string(forKey: CoatKey.pushURL), !url.isEmpty else { return nil }
        return url
    }

    func sealMold(then ack: @escaping () -> Void) {
        ensureLined()
        sealTask = Task { [weak self] in
            guard let self = self else { return }

            let stamped = await self.shop.seal.request()

            self.batch.sealStamped = stamped
            self.batch.sealBroke = !stamped
            self.batch.sealAt = Date()
            self.shop.mould.imprint(self.batch.log())

            if stamped {
                self.shop.seal.armRunner()
            }

            self.tapSubject.send(.cast)
            ack()
        }
    }

    func skipSeal() {
        ensureLined()
        batch.sealAt = Date()
        shop.mould.imprint(batch.log())
        tapSubject.send(.cast)
    }

    func reportColdEnd() -> Bool {
        return harden()
    }
}
