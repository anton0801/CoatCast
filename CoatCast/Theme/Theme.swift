//
//  Theme.swift
//  CoatCast
//
//  Design system: turquoise "painter's studio" palette (light-first with
//  intentional dark variants), rounded typography, spacing/radius scales,
//  and iOS 14-safe formatters. No iOS 15+ APIs (.formatted(), Material, etc.).
//

import SwiftUI
import UIKit

// MARK: - Hex color helpers

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hex & 0x0000FF) / 255.0
        self = Color(UIColor(red: r, green: g, blue: b, alpha: CGFloat(alpha)))
    }

    /// Adapts between light & dark appearance using the trait collection.
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - Theme namespace

enum Theme {

    // Backgrounds (light → dark)
    static let bg        = Color.dynamic(light: 0xF6FAFB, dark: 0x0B1E1C)
    static let bgDepth   = Color.dynamic(light: 0xE8F0F2, dark: 0x0F2A27)
    static let surface   = Color.dynamic(light: 0xFFFFFF, dark: 0x12302C)
    static let surfaceAlt = Color.dynamic(light: 0xF2F8F9, dark: 0x163A35)
    static let stroke    = Color.dynamic(light: 0xD8E6E9, dark: 0x1E443E)

    // Accent (paint turquoise)
    static let accent    = Color(hex: 0x14B8A6)
    static let accentActive = Color(hex: 0x0D9488)
    static let accentSoft = Color(hex: 0x5EEAD4)

    // Secondary paint swatches
    static let pink      = Color(hex: 0xF472B6)
    static let orange    = Color(hex: 0xFB923C)

    // Status
    static let ready     = Color(hex: 0x22C55E)
    static let drying    = Color(hex: 0x14B8A6)
    static let attention = Color(hex: 0xF59E0B)
    static let defect    = Color(hex: 0xEF4444)

    // Text
    static let textPrimary   = Color.dynamic(light: 0x0E3A36, dark: 0xE6F4F1)
    static let textSecondary = Color.dynamic(light: 0x4A6B66, dark: 0x9FC4BD)
    static let textInactive  = Color.dynamic(light: 0x8FA9A4, dark: 0x5E7C77)

    // Button text
    static let onAccent  = Color(hex: 0x062B27)
    static let onSecondary = Color.dynamic(light: 0x0F3D38, dark: 0xCDEBE5)

    // Effects
    static let glow      = Color(hex: 0x14B8A6, alpha: 0.25)
    static let shadow    = Color.dynamic(light: 0x0E3C37, dark: 0x000000).opacity(0.10)

    // MARK: Gradients

    static var background: LinearGradient {
        LinearGradient(colors: [bg, bgDepth],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accentSoft, accent, accentActive],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var primaryButtonGradient: LinearGradient {
        LinearGradient(colors: [accent, accentActive],
                       startPoint: .top, endPoint: .bottom)
    }

    // MARK: Spacing & radius

    enum Space {
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 22
        static let xl: CGFloat = 32
    }
    enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let pill: CGFloat = 100
    }

    // MARK: Typography (rounded system — no custom font files required)

    static func title(_ size: CGFloat = 26) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func heading(_ size: CGFloat = 18) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    static func mono(_ size: CGFloat = 30) -> Font { .system(size: size, weight: .heavy, design: .rounded).monospacedDigit() }
    static func caption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

// MARK: - Formatters (iOS 14 safe — no .formatted())

enum Formatters {

    private static let decimalFmt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    static func decimal(_ value: Double, max: Int = 2) -> String {
        decimalFmt.maximumFractionDigits = max
        return decimalFmt.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func currency(_ value: Double, symbol: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        let n = f.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(symbol)\(n)"
    }

    static func percent(_ value: Double) -> String { "\(Int(value.rounded()))%" }

    /// Human duration from seconds, e.g. "2h 05m", "47m 12s", "Ready".
    static func countdown(_ seconds: Int) -> String {
        if seconds <= 0 { return "Ready" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }

    /// Compact dry-window estimate from minutes, e.g. "3h 0m" or "45m".
    static func minutesShort(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        let h = total / 60
        let m = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    static func date(_ date: Date) -> String { dateFmt.string(from: date) }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()
    static func dayTime(_ date: Date) -> String { dayFmt.string(from: date) }
}

// MARK: - Keyboard dismissal (no @FocusState on iOS 14)

extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
