//
//  RemindersView.swift
//  CoatCast
//
//  Feature 14 (Reminders): real UNUserNotificationCenter scheduling. Coat-dry
//  alerts are scheduled automatically when a coat is applied; here the user can
//  enable notifications, schedule "buy paint" / "remove tape" reminders, and
//  send a test.
//

import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var notifications: NotificationManager

    @State private var preset = 0
    @State private var customTitle = ""
    @State private var body_ = ""
    @State private var when = Date().addingTimeInterval(3600)
    @State private var confirmation: String?

    private let presets = ["Buy more paint", "Remove masking tape", "Custom reminder"]

    var body: some View {
        ScreenScaffold("Reminders", subtitle: "Local notifications") {
            VStack(spacing: Theme.Space.m) {
                authCard

                if let msg = confirmation {
                    CardView(tint: Theme.ready) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(Theme.ready)
                            Text(msg).font(Theme.caption(13)).foregroundColor(Theme.textPrimary)
                            Spacer()
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Schedule a reminder", systemImage: "bell.badge.fill")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presets.indices, id: \.self) { i in
                                    Chip(title: presets[i], isSelected: preset == i) { preset = i }
                                }
                            }
                        }
                        if preset == 2 {
                            LabeledTextField(label: "Title", text: $customTitle, placeholder: "Reminder title")
                        }
                        LabeledTextField(label: "Note", text: $body_, placeholder: "Optional details")
                        VStack(alignment: .leading, spacing: 5) {
                            Text("WHEN").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                            DatePicker("", selection: $when, in: Date()...,
                                       displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                                .accentColor(Theme.accent)
                        }
                        ActionButton(title: "Schedule Reminder", systemImage: "alarm.fill") {
                            schedule()
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Automatic", systemImage: "sparkles")
                        Text("Coat-dry alerts are scheduled for you whenever you apply a coat in the Layer Scheduler.")
                            .font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                        ActionButton(title: "Send Test Notification", systemImage: "paperplane.fill", kind: .secondary) {
                            notifications.sendTest()
                            flash("Test notification will arrive in ~3 seconds.")
                        }
                    }
                }
            }
        }
        .onAppear { notifications.refreshAuthorization() }
    }

    private var authCard: some View {
        CardView(tint: notifications.isAuthorized ? Theme.ready : Theme.attention) {
            HStack(spacing: 14) {
                Image(systemName: notifications.isAuthorized ? "bell.fill" : "bell.slash.fill")
                    .font(.system(size: 22)).foregroundColor(notifications.isAuthorized ? Theme.ready : Theme.attention)
                VStack(alignment: .leading, spacing: 2) {
                    Text(notifications.isAuthorized ? "Notifications enabled" : "Notifications off")
                        .font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                    Text(notifications.isAuthorized ? "You'll get coat-dry and reminder alerts."
                                                     : "Enable to receive alerts.")
                        .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                if !notifications.isAuthorized {
                    Button(action: { notifications.requestAuthorization { _ in } }) {
                        Text("Enable").font(Theme.heading(14)).foregroundColor(Theme.onAccent)
                            .padding(.vertical, 8).padding(.horizontal, 14)
                            .background(Theme.primaryButtonGradient)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func schedule() {
        UIApplication.shared.dismissKeyboard()
        let title = preset == 2
            ? (customTitle.isEmpty ? "Reminder" : customTitle)
            : presets[preset]
        let note = body_.isEmpty ? "Coat Cast reminder" : body_
        notifications.scheduleReminder(title: title, body: note, at: when)
        flash("“\(title)” scheduled for \(Formatters.dayTime(when)).")
    }

    private func flash(_ message: String) {
        withAnimation { confirmation = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { confirmation = nil }
        }
    }
}
