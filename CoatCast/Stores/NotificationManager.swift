//
//  NotificationManager.swift
//  CoatCast
//
//  Wraps UNUserNotificationCenter for real local notifications: coat-dry alerts
//  (scheduled when a coat is applied, cancelled if reverted), plus user reminders
//  (buy more paint / remove tape). iOS 14 safe.
//

import Foundation
import UserNotifications

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private let center = UNUserNotificationCenter.current()

    init() { refreshAuthorization() }

    // MARK: Authorization

    func refreshAuthorization() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = (settings.authorizationStatus == .authorized
                                     || settings.authorizationStatus == .provisional)
            }
        }
    }

    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                completion?(granted)
            }
        }
    }

    // MARK: Coat-dry notification

    /// Schedules a one-shot "coat is dry" notification. Returns the request id
    /// (store it on the Coat so it can be cancelled on revert). Requests
    /// authorization first if needed.
    @discardableResult
    func scheduleCoatDry(roomName: String, coatLabel: String, after seconds: TimeInterval) -> String {
        let id = "coat-\(UUID().uuidString)"
        let fire = max(1, seconds)

        let schedule = {
            let content = UNMutableNotificationContent()
            content.title = "\(coatLabel) is dry — \(roomName)"
            content.body = "The drying window is complete. You can apply the next coat now."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fire, repeats: false)
            self.center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }

        if isAuthorized {
            schedule()
        } else {
            requestAuthorization { granted in if granted { schedule() } }
        }
        return id
    }

    func cancel(id: String?) {
        guard let id = id else { return }
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: Reminders (buy paint / remove tape / generic)

    @discardableResult
    func scheduleReminder(title: String, body: String, at date: Date) -> String {
        let id = "reminder-\(UUID().uuidString)"
        let schedule = {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            comps.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            self.center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
        if isAuthorized { schedule() } else { requestAuthorization { if $0 { schedule() } } }
        return id
    }

    func sendTest() {
        let fire: () -> Void = {
            let content = UNMutableNotificationContent()
            content.title = "Coat Cast"
            content.body = "Test notification — reminders are working."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
            self.center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
        }
        if isAuthorized { fire() } else { requestAuthorization { if $0 { fire() } } }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
