import Foundation

final class Shop {
    let mould: Mould
    let pyrometer: Pyrometer
    let ladle: Ladle
    let seal: Seal

    init(mould: Mould, pyrometer: Pyrometer, ladle: Ladle, seal: Seal) {
        self.mould = mould
        self.pyrometer = pyrometer
        self.ladle = ladle
        self.seal = seal
    }

    static func staffed() -> Shop {
        Shop(
            mould: SandMould(),
            pyrometer: KilnPyrometer(),
            ladle: CastLadle(),
            seal: MoldSeal()
        )
    }
}

@MainActor
final class Works {

    static let shared = Works()

    private var bins: [String: Any] = [:]

    private init() {}

    func stash<T>(_ instance: T, as type: T.Type) {
        bins[String(describing: type)] = instance
    }

    func cast<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        if let instance = bins[key] as? T {
            return instance
        }
        let built = forge(type)
        bins[key] = built
        return built
    }

    private func forge<T>(_ type: T.Type) -> T {
        switch String(describing: type) {
        case String(describing: Shop.self):
            return Shop.staffed() as! T
        case String(describing: Foundry.self):
            return Foundry(shop: cast(Shop.self)) as! T
        default:
            fatalError("Works: no builder for \(type)")
        }
    }
}
