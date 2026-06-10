//
//  DryTimerView.swift
//  CoatCast
//
//  Feature 04 (Dry Timer): a full-screen live countdown for the coat that is
//  currently drying in a room, with readiness state. Driven by the shared Clock;
//  all time is recomputed from persisted dates so it survives relaunch.
//

import SwiftUI

struct DryTimerView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var clock: Clock
    let roomID: UUID

    var body: some View {
        let now = clock.now
        let room = store.room(roomID)
        let drying = store.dryingCoat(for: roomID, asOf: now)
        // The most recently applied coat (drying, or just-finished) to display.
        let display = drying ?? store.coats(for: roomID)
            .filter { $0.dryStartedAt != nil }
            .max(by: { $0.index < $1.index })

        return ScreenScaffold("Dry Timer", subtitle: room?.name) {
            VStack(spacing: Theme.Space.l) {
                if let coat = display {
                    let ready = coat.isDry(asOf: now)
                    CardView(tint: ready ? Theme.ready : Theme.drying) {
                        VStack(spacing: Theme.Space.m) {
                            ZStack {
                                ProgressRing(progress: coat.progress(asOf: now), size: 190, lineWidth: 14,
                                             tint: ready ? Theme.ready : Theme.drying)
                                VStack(spacing: 4) {
                                    Text(ready ? "READY" : "DRYING").font(Theme.caption(12))
                                        .foregroundColor(ready ? Theme.ready : Theme.drying).tracking(2)
                                    Text(ready ? "Done" : Formatters.countdown(coat.remainingSeconds(asOf: now)))
                                        .font(Theme.mono(34)).foregroundColor(Theme.textPrimary)
                                }
                            }
                            Text(coat.label).font(Theme.heading(18)).foregroundColor(Theme.textPrimary)
                        }
                    }

                    CardView {
                        VStack(spacing: 10) {
                            infoRow("Started", coat.dryStartedAt.map { Formatters.dayTime($0) } ?? "—")
                            infoRow("Dry at", coat.dryEndsAt.map { Formatters.dayTime($0) } ?? "—")
                            infoRow("Window", Formatters.minutesShort(coat.dryMinutes))
                            if let r = room {
                                infoRow("Climate basis", "\(Int(store.prefs.temperatureC))°C · \(Int(store.prefs.humidityPct))% · \(r.paintType.displayName)")
                            }
                        }
                    }

                    if ready {
                        NavigationLink(destination: LayerSchedulerView(roomID: roomID)) {
                            HStack {
                                Image(systemName: "paintbrush.pointed.fill")
                                Text("Back to scheduler — apply next coat")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(Theme.heading(15)).foregroundColor(Theme.onAccent)
                            .padding(16).background(Theme.primaryButtonGradient)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else {
                    EmptyStateCard(icon: "hourglass.bottomhalf.filled",
                                   title: "Nothing drying",
                                   message: "Apply a coat in the Layer Scheduler to start a dry timer.")
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
        }
    }
}
