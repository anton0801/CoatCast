import Foundation
import UIKit
import UserNotifications

protocol Seal {
    func request() async -> Bool
    func armRunner()
}

final class MoldSeal: Seal {

    func request() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let gasket = OneGasket()
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, error in
                if let error = error {
                }
                DispatchQueue.main.async {
                    guard gasket.seat() else { return }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func armRunner() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}

final class OneGasket {
    private var seated = false
    private let lock = NSLock()

    func seat() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !seated else { return false }
        seated = true
        return true
    }
}
