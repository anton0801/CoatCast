import UIKit
import FirebaseCore
import FirebaseMessaging
import AppTrackingTransparency
import UserNotifications
import AppsFlyerLib

final class AppDelegate: UIResponder, UIApplicationDelegate {

    private let smelter = Smelter()
    private let spout = Spout()
    private lazy var crew: [Crewman] = [
        TrackerCrewman(host: self),
        SignalCrewman(host: self),
        AlarmCrewman(host: self)
    ]

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        FirebaseApp.configure()
        crew.forEach { $0.enlist() }
        NotificationCenter.default.post(name: .muster, object: nil)

        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            spout.vent(remote)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onActivation),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    @objc private func onActivation() {
        if #available(iOS 14, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()
                    UserDefaults.standard.set(status.rawValue, forKey: "att_status")
                }
            }
        } else {
            AppsFlyerLib.shared().start()
        }
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        messaging.token { token, err in
            guard err == nil, let t = token else { return }
            UserDefaults.standard.set(t, forKey: CoatKey.fcm)
            UserDefaults.standard.set(t, forKey: CoatKey.push)
            UserDefaults(suiteName: Coat.suiteFoundry)?.set(t, forKey: "shared_fcm")
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        spout.vent(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        spout.vent(response.notification.request.content.userInfo)
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        spout.vent(userInfo)
        completionHandler(.newData)
    }
}

extension AppDelegate: AppsFlyerLibDelegate, DeepLinkDelegate {
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        smelter.takePour(data)
    }

    func onConversionDataFail(_ error: Error) {
        smelter.takePour([
            "error": true,
            "error_desc": error.localizedDescription
        ])
    }

    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status, let link = result.deepLink else { return }
        smelter.takeRunners(link.clickEvent)
    }
}

protocol Crewman: AnyObject {
    func enlist()
}

final class TrackerCrewman: NSObject, Crewman {
    private weak var host: AppDelegate?
    init(host: AppDelegate) { self.host = host }
    func enlist() {
        NotificationCenter.default.addObserver(self, selector: #selector(report), name: .muster, object: nil)
    }
    @objc private func report() {
        let sdk = AppsFlyerLib.shared()
        sdk.appsFlyerDevKey = Coat.pyroKey
        sdk.appleAppID = Coat.appCode
        sdk.delegate = host
        sdk.deepLinkDelegate = host
        sdk.isDebug = false
    }
}

final class SignalCrewman: NSObject, Crewman {
    private weak var host: AppDelegate?
    init(host: AppDelegate) { self.host = host }
    func enlist() {
        NotificationCenter.default.addObserver(self, selector: #selector(report), name: .muster, object: nil)
    }
    @objc private func report() {
        Messaging.messaging().delegate = host
        UIApplication.shared.registerForRemoteNotifications()
    }
}

final class AlarmCrewman: NSObject, Crewman {
    private weak var host: AppDelegate?
    init(host: AppDelegate) { self.host = host }
    func enlist() {
        NotificationCenter.default.addObserver(self, selector: #selector(report), name: .muster, object: nil)
    }
    @objc private func report() {
        UNUserNotificationCenter.current().delegate = host
    }
}

final class Smelter: NSObject {

    private var pourBuffer: [AnyHashable: Any] = [:]
    private var runnersBuffer: [AnyHashable: Any] = [:]
    private var fuse: Timer?

    func takePour(_ data: [AnyHashable: Any]) {
        pourBuffer = data
        armFuse()
        if !runnersBuffer.isEmpty { weld() }
    }

    func takeRunners(_ data: [AnyHashable: Any]) {
        guard !UserDefaults.standard.bool(forKey: CoatKey.primed) else { return }
        runnersBuffer = data
        NotificationCenter.default.post(
            name: .runnersArrived,
            object: nil,
            userInfo: ["deeplinksData": data]
        )
        fuse?.invalidate()
        fuse = nil
        if !pourBuffer.isEmpty { weld() }
    }

    private func armFuse() {
        fuse?.invalidate()
        fuse = Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(pourFire), userInfo: nil, repeats: false)
    }

    @objc private func pourFire() {
        weld()
    }

    private func weld() {
        fuse?.invalidate()
        fuse = nil

        var merged = pourBuffer
        for (k, v) in runnersBuffer {
            let tag = "deep_\(k)"
            if merged[tag] == nil { merged[tag] = v }
        }

        NotificationCenter.default.post(
            name: .pourArrived,
            object: nil,
            userInfo: ["conversionData": merged]
        )
    }
}

extension Dictionary where Key == AnyHashable, Value == Any {
    subscript(dig path: String) -> String? {
        var node: Any? = self
        for key in path.split(separator: ".") {
            node = (node as? [AnyHashable: Any])?[String(key)]
        }
        return node as? String
    }
}

final class Spout {

    func vent(_ payload: [AnyHashable: Any]) {
        guard let url = payload[dig: "url"]
            ?? payload[dig: "data.url"]
            ?? payload[dig: "aps.data.url"]
            ?? payload[dig: "custom.url"] else { return }

        UserDefaults.standard.set(url, forKey: CoatKey.pushURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            NotificationCenter.default.post(
                name: .sheenWake,
                object: nil,
                userInfo: ["temp_url": url]
            )
        }
    }
}
