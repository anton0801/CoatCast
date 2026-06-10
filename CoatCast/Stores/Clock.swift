//
//  Clock.swift
//  CoatCast
//
//  A single shared 1-second tick that drives every live countdown (Layer
//  Scheduler, Dry Timer, dashboards). One timer for all consumers avoids drift
//  and wasted cycles. Correctness is date-derived (we recompute remaining time
//  from persisted dates each tick), so a missed tick while backgrounded never
//  causes drift. iOS 14 safe — no TimelineView.
//

import Foundation
import Combine

final class Clock: ObservableObject {
    @Published var now = Date()
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        now = Date()
        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.now = Date()
        }
        RunLoop.main.add(t, forMode: .common)   // keep ticking during scroll
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
