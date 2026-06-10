//
//  PaintBackground.swift
//  CoatCast
//
//  The light turquoise "studio" backdrop plus the custom paint Shapes (drop,
//  brush stroke, paint can with drip) reused by the splash, onboarding and
//  every screen scaffold. Pure SwiftUI Shapes — iOS 14 safe.
//

import SwiftUI

// MARK: - Shapes

/// A classic teardrop / paint-drop shape (point at top, round bottom).
struct PaintDrop: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let tip = CGPoint(x: rect.midX, y: rect.minY)
        p.move(to: tip)
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                   control1: CGPoint(x: rect.minX, y: h * 0.45),
                   control2: CGPoint(x: rect.minX, y: rect.maxY))
        p.addCurve(to: tip,
                   control1: CGPoint(x: rect.maxX, y: rect.maxY),
                   control2: CGPoint(x: rect.maxX, y: h * 0.45))
        _ = w
        return p
    }
}

/// A horizontal brush-stroke band with slightly ragged ends.
struct BrushStroke: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let h = rect.height
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY - h * 0.12),
                       control: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + h * 0.32))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY + h * 0.46),
                       control: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Paint-can outline with a handle and a single drip on the rim.
struct PaintCanShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let bodyTop = rect.minY + rect.height * 0.22
        // Body
        let body = CGRect(x: rect.minX, y: bodyTop,
                          width: rect.width, height: rect.height - (bodyTop - rect.minY))
        p.addRoundedRect(in: body, cornerSize: CGSize(width: rect.width * 0.10, height: rect.width * 0.10))
        // Rim ellipse
        let rim = CGRect(x: rect.minX, y: rect.minY + rect.height * 0.10,
                         width: rect.width, height: rect.height * 0.22)
        p.addEllipse(in: rim)
        return p
    }
}

/// A small drip blob — a rounded rectangle that ends in a bulb.
struct DripShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        p.move(to: CGPoint(x: rect.midX - w/2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX + w/2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX + w/2, y: rect.maxY - w))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY - w),
                 radius: w/2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - Background

struct PaintBackground: View {
    var animated: Bool = false
    @State private var drift = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            // Soft paint blobs in the corners (palette swatches as ambience).
            blob(color: Theme.accentSoft, size: 320)
                .offset(x: -140, y: drift ? -260 : -230)
            blob(color: Theme.pink, size: 220)
                .offset(x: 150, y: drift ? 380 : 360)
            blob(color: Theme.orange, size: 180)
                .offset(x: -150, y: drift ? 430 : 410)
            blob(color: Theme.accent, size: 240)
                .offset(x: 160, y: drift ? -300 : -280)
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { drift = true }
        }
        .onDisappear { drift = false }
    }

    private func blob(color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.18))
            .frame(width: size, height: size)
            .blur(radius: 60)
    }
}

// MARK: - Screen modifier

extension View {
    /// Places content over the paint backdrop, ignoring safe area on the background only.
    func paintScreen() -> some View {
        ZStack {
            PaintBackground()
            self
        }
    }
}
