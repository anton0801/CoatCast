//
//  LayerSchedulerView.swift
//  CoatCast
//
//  Feature 03 (Layer Scheduler): coats with inter-coat dry windows. The
//  "Apply next coat" button is locked while the most-recently-applied coat is
//  still drying; a live countdown shows the remaining time and a notification
//  is scheduled for when it's dry.
//

import SwiftUI

// MARK: - Schedule tab home

struct ScheduleHomeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var clock: Clock

    var body: some View {
        ScreenScaffold("Layer Scheduler",
                       subtitle: "Coats, dry windows & timers") {
            VStack(spacing: Theme.Space.m) {
                if store.rooms.isEmpty {
                    EmptyStateCard(icon: "timer", title: "No rooms to schedule",
                                   message: "Add a room in the Studio tab to plan its coats.")
                } else {
                    ForEach(store.rooms) { room in
                        NavigationLink(destination: LayerSchedulerView(roomID: room.id)) {
                            roomScheduleCard(room)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                NavRow(icon: "clock.arrow.circlepath", title: "History",
                       subtitle: "Painted · dried · fixed", tint: Theme.textSecondary) { HistoryView() }
                NavRow(icon: "bell.badge.fill", title: "Reminders",
                       subtitle: "Coat dry · buy paint · remove tape", tint: Theme.attention) { RemindersView() }
            }
        }
    }

    private func roomScheduleCard(_ room: PaintRoom) -> some View {
        let now = clock.now
        let drying = store.dryingCoat(for: room.id, asOf: now)
        return CardView(tint: drying != nil ? Theme.drying : nil) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ColorDot(hex: room.colorHex, size: 30)
                    Text(room.name).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text("\(store.coatsDone(for: room.id))/\(store.coatsTotal(for: room.id)) coats")
                        .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                }
                ProgressBar(progress: store.roomProgress(for: room.id))
                if let d = drying {
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass").foregroundColor(Theme.drying)
                        Text("\(d.label) drying — \(Formatters.countdown(d.remainingSeconds(asOf: now)))")
                            .font(Theme.caption(13)).foregroundColor(Theme.drying)
                    }
                } else if store.nextApplicableCoat(for: room.id) != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.ready)
                        Text("Ready for next coat").font(Theme.caption(13)).foregroundColor(Theme.ready)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered").foregroundColor(Theme.textSecondary)
                        Text("All coats complete").font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Layer scheduler detail

struct LayerSchedulerView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var clock: Clock
    let roomID: UUID

    private var lastAppliedID: UUID? {
        store.coats(for: roomID)
            .filter { $0.dryStartedAt != nil }
            .max(by: { $0.index < $1.index })?.id
    }

    var body: some View {
        let now = clock.now
        ScreenScaffold(store.room(roomID)?.name ?? "Schedule", subtitle: "Apply coats in order") {
            VStack(spacing: Theme.Space.m) {
                // Active dry timer (if any) — links to the full Dry Timer screen
                if let drying = store.dryingCoat(for: roomID, asOf: now) {
                    NavigationLink(destination: DryTimerView(roomID: roomID)) {
                        activeTimerCard(coat: drying, now: now)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Coats
                CardView {
                    VStack(spacing: 12) {
                        ForEach(store.coats(for: roomID)) { coat in
                            coatRow(coat, now: now)
                        }
                    }
                }

                applyButton(now: now)
            }
        }
    }

    private func activeTimerCard(coat: Coat, now: Date) -> some View {
        CardView(tint: Theme.drying) {
            HStack(spacing: 16) {
                ProgressRing(progress: coat.progress(asOf: now), size: 64, lineWidth: 7, tint: Theme.drying)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(coat.label) drying").font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                    Text(Formatters.countdown(coat.remainingSeconds(asOf: now)))
                        .font(Theme.mono(26)).foregroundColor(Theme.drying)
                    Text("Tap for the full timer").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Theme.textInactive)
            }
        }
    }

    private func coatRow(_ coat: Coat, now: Date) -> some View {
        let isDrying = coat.dryStartedAt != nil && !coat.isDry(asOf: now)
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(statusColor(coat, now: now).opacity(0.16)).frame(width: 40, height: 40)
                Image(systemName: coat.isPrimer ? "square.layers.3d.up.fill" : "paintbrush.fill")
                    .foregroundColor(statusColor(coat, now: now))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(coat.label).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                if isDrying {
                    Text("Drying — \(Formatters.countdown(coat.remainingSeconds(asOf: now)))")
                        .font(Theme.caption(12)).foregroundColor(Theme.drying)
                } else {
                    Text(statusText(coat, now: now)).font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
            if coat.id == lastAppliedID {
                Button(action: { store.revertCoat(coat) }) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundColor(Theme.attention).font(.system(size: 22))
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                statusPill(coat, now: now)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func applyButton(now: Date) -> some View {
        let locked = store.isNextCoatLocked(for: roomID, asOf: now)
        let next = store.nextApplicableCoat(for: roomID)
        if next == nil {
            CardView(tint: Theme.ready) {
                HStack {
                    Image(systemName: "flag.checkered").foregroundColor(Theme.ready)
                    Text("All coats applied & dried.").font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                    Spacer()
                }
            }
        } else if locked {
            let drying = store.dryingCoat(for: roomID, asOf: now)
            ActionButton(title: "Locked — dry in \(Formatters.countdown(drying?.remainingSeconds(asOf: now) ?? 0))",
                         systemImage: "lock.fill", kind: .secondary, enabled: false) {}
        } else {
            ActionButton(title: "Apply \(next!.label)", systemImage: "paintbrush.pointed.fill") {
                store.applyNextCoat(for: roomID, now: Date())
            }
        }
    }

    private func statusColor(_ coat: Coat, now: Date) -> Color {
        if coat.status == .done || coat.isDry(asOf: now) && coat.dryStartedAt != nil { return Theme.ready }
        if coat.dryStartedAt != nil { return Theme.drying }
        return Theme.textInactive
    }
    private func statusText(_ coat: Coat, now: Date) -> String {
        if coat.dryStartedAt != nil && (coat.status == .done || coat.isDry(asOf: now)) {
            return "Dry · done"
        }
        return "Pending"
    }
    private func statusPill(_ coat: Coat, now: Date) -> some View {
        let done = coat.dryStartedAt != nil && (coat.status == .done || coat.isDry(asOf: now))
        return TagChip(text: done ? "Done" : "Pending",
                       color: done ? Theme.ready : Theme.textInactive, filled: done)
    }
}
