//
//  SplashView.swift
//  CoatCast
//
//  Thematic splash: a paint drop spreads into the logo while a brush stroke
//  sweeps up from the bottom. Three simultaneous layers (background gradient
//  shift, midground drop+stroke loop, foreground logo entrance). A single
//  coordinator Timer drives the staged sequence; all looping state is reset in
//  .onDisappear to prevent animation leaks. iOS 14 safe.
//

import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    // Lifecycle guard
    @State private var isVisible = true

    // Staged reveal flags
    @State private var bgIn = false
    @State private var dropSpread: CGFloat = 0
    @State private var strokeSweep = false
    @State private var logoIn = false
    @State private var exiting = false

    // Looping flags
    @State private var shimmer = false
    @State private var ripple = false

    // Coordinator
    @State private var timer: Timer?
    @State private var elapsed: Double = 0

    var body: some View {
        ZStack {
            // ---- Layer 1: background gradient + drifting shimmer highlight ----
            Theme.background.ignoresSafeArea()

            LinearGradient(colors: [.clear, Theme.accentSoft.opacity(0.35), .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 280)
                .rotationEffect(.degrees(26))
                .offset(x: shimmer ? 340 : -340, y: shimmer ? 240 : -240)
                .opacity(bgIn ? 1 : 0)
                .ignoresSafeArea()

            // ---- Layer 2: expanding ripple + paint drop + brush stroke ----
            ZStack {
                // Looping ripples behind the drop
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Theme.accent.opacity(0.4), lineWidth: 2)
                        .frame(width: 90, height: 90)
                        .scaleEffect(ripple ? 2.6 : 0.6)
                        .opacity(ripple ? 0 : 0.7)
                        .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.6), value: ripple)
                }

                // The drop that "spreads"
                PaintDrop()
                    .fill(Theme.accentGradient)
                    .frame(width: 70, height: 96)
                    .scaleEffect(dropSpread, anchor: .center)
                    .opacity(logoIn ? 0 : 1)              // hands off to the logo
            }
            .scaleEffect(exiting ? 1.7 : 1)
            .opacity(exiting ? 0 : 1)

            // Brush stroke sweeping up from the bottom
            BrushStroke()
                .fill(Theme.accent.opacity(0.9))
                .frame(width: 260, height: 60)
                .scaleEffect(x: strokeSweep ? 1 : 0, anchor: .leading)
                .opacity(strokeSweep ? 0.9 : 0)
                .offset(y: 150)
                .opacity(exiting ? 0 : 1)

            // ---- Layer 3: logo + title + tagline ----
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.accentGradient)
                        .frame(width: 104, height: 104)
                        .shadow(color: Theme.glow, radius: 18, x: 0, y: 8)
                    PaintDrop()
                        .fill(Color.white)
                        .frame(width: 34, height: 48)
                        .offset(y: -2)
                }
                .scaleEffect(logoIn ? (exiting ? 1.6 : 1) : 0.3)
                .opacity(logoIn ? (exiting ? 0 : 1) : 0)

                VStack(spacing: 6) {
                    Text("COAT CAST")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .tracking(3)
                    Text("Plan the paint, not the mess.")
                        .font(Theme.caption(14))
                        .foregroundColor(Theme.textSecondary)
                }
                .opacity(logoIn ? (exiting ? 0 : 1) : 0)
                .offset(y: logoIn ? 0 : 20)
            }
        }
        .onAppear { start() }
        .onDisappear { teardown() }
    }

    // MARK: Sequencing

    private func start() {
        isVisible = true
        elapsed = 0

        // Looping background + ripple animations
        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) { shimmer = true }
        ripple = true   // drives the .repeatForever ripple animation declared above

        let t = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            elapsed += 0.05
            tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard isVisible else { return }
        if elapsed >= 0.1 && !bgIn {
            withAnimation(.easeOut(duration: 0.6)) { bgIn = true }
        }
        if elapsed >= 0.6 && dropSpread == 0 {
            withAnimation(.easeInOut(duration: 0.8)) { dropSpread = 1 }
            withAnimation(.easeInOut(duration: 0.9)) { strokeSweep = true }
        }
        if elapsed >= 1.4 && !logoIn {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { logoIn = true }
        }
        if elapsed >= 2.2 && !exiting {
            withAnimation(.easeIn(duration: 0.5)) { exiting = true }
        }
        if elapsed >= 2.75 {
            timer?.invalidate(); timer = nil
            onFinish()
        }
    }

    private func teardown() {
        isVisible = false
        timer?.invalidate(); timer = nil
        // Reset every loop/animation flag to its initial value (no leaks).
        shimmer = false
        ripple = false
        bgIn = false
        dropSpread = 0
        strokeSweep = false
        logoIn = false
        exiting = false
    }
}
