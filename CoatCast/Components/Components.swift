//
//  Components.swift
//  CoatCast
//
//  Reusable UI building blocks: buttons, cards, stat tiles, progress, chips,
//  inputs, nav rows and the screen scaffold. All iOS 14 safe (custom ButtonStyle,
//  no .bordered, no @FocusState, no .formatted()).
//

import SwiftUI

// MARK: - Curated paint palette (used by swatch pickers)

enum PaintPalette {
    static let swatches: [UInt] = [
        0xFFFFFF, 0xF2F8F9, 0xE8F0F2, 0x5EEAD4, 0x14B8A6, 0x0D9488,
        0x0E3A36, 0x4A6B66, 0xF472B6, 0xFB923C, 0xF59E0B, 0x22C55E,
        0xEF4444, 0x60A5FA, 0xA78BFA, 0xFBBF24, 0x111827, 0x9CA3AF
    ]
}

// MARK: - Buttons

struct ActionButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .primary
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.heading(15))
            .foregroundColor(foreground)
            .padding(.vertical, 14).padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .stroke(kind == .secondary ? Theme.accent.opacity(0.5) : Color.clear, lineWidth: 1.4)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
            .shadow(color: kind == .primary ? Theme.glow : .clear,
                    radius: configuration.isPressed ? 4 : 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.onAccent
        case .secondary: return Theme.onSecondary
        case .danger: return .white
        }
    }
    @ViewBuilder private var background: some View {
        switch kind {
        case .primary: Theme.primaryButtonGradient
        case .secondary: Theme.surfaceAlt
        case .danger: Theme.defect
        }
    }
}

struct ActionButton: View {
    let title: String
    var systemImage: String? = nil
    var kind: ActionButtonStyle.Kind = .primary
    var fullWidth: Bool = true
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 8) {
                if let s = systemImage { Image(systemName: s) }
                Text(title)
            }
        }
        .buttonStyle(ActionButtonStyle(kind: kind, fullWidth: fullWidth))
        .opacity(enabled ? 1 : 0.45)
        .disabled(!enabled)
    }
}

// MARK: - Card

struct CardView<Content: View>: View {
    var padding: CGFloat = Theme.Space.m
    var tint: Color? = nil
    let content: () -> Content

    init(padding: CGFloat = Theme.Space.m, tint: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding; self.tint = tint; self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .stroke(tint?.opacity(0.4) ?? Theme.stroke, lineWidth: 1)
            )
            .shadow(color: Theme.shadow, radius: 10, x: 0, y: 5)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var systemImage: String? = nil
    var body: some View {
        HStack(spacing: 8) {
            if let s = systemImage {
                Image(systemName: s).foregroundColor(Theme.accent).font(.system(size: 15, weight: .bold))
            }
            Text(title.uppercased())
                .font(Theme.caption(12))
                .foregroundColor(Theme.textSecondary)
                .tracking(1.2)
            Spacer()
        }
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let label: String
    var systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(tint)
            Text(value).font(Theme.title(22)).foregroundColor(Theme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.m)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(tint.opacity(0.25), lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 8, x: 0, y: 4)
    }
}

// MARK: - Progress ring & bar

struct ProgressRing: View {
    var progress: Double            // 0...1
    var size: CGFloat = 64
    var lineWidth: CGFloat = 8
    var tint: Color = Theme.accent

    var body: some View {
        ZStack {
            Circle().stroke(Theme.stroke, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(width: size, height: size)
    }
}

struct ProgressBar: View {
    var progress: Double            // 0...1
    var tint: Color = Theme.accent
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.stroke)
                Capsule().fill(tint)
                    .frame(width: max(0, geo.size.width * CGFloat(min(max(progress, 0), 1))))
                    .animation(.easeInOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Chips

struct Chip: View {
    let title: String
    var icon: String? = nil
    var isSelected: Bool
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let i = icon { Image(systemName: i).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(Theme.caption(13))
            }
            .padding(.vertical, 9).padding(.horizontal, 14)
            .foregroundColor(isSelected ? Theme.onAccent : Theme.textSecondary)
            .background(
                Capsule().fill(isSelected ? tint : Theme.surfaceAlt)
            )
            .overlay(Capsule().stroke(isSelected ? Color.clear : Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TagChip: View {
    let text: String
    var color: Color = Theme.accent
    var filled: Bool = false
    var body: some View {
        Text(text)
            .font(Theme.caption(11))
            .padding(.vertical, 4).padding(.horizontal, 9)
            .foregroundColor(filled ? .white : color)
            .background(Capsule().fill(filled ? color : color.opacity(0.14)))
    }
}

// MARK: - Color swatch

struct ColorDot: View {
    let hex: UInt
    var size: CGFloat = 28
    var selected: Bool = false
    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
            .overlay(
                Circle().stroke(Theme.accent, lineWidth: selected ? 3 : 0)
                    .padding(-3)
            )
    }
}

struct SwatchPicker: View {
    @Binding var hex: UInt
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PaintPalette.swatches, id: \.self) { s in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { hex = s }
                    }) {
                        ColorDot(hex: s, size: 34, selected: s == hex)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 4).padding(.horizontal, 2)
        }
    }
}

// MARK: - Inputs

struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            TextField(placeholder, text: $text)
                .font(Theme.body())
                .foregroundColor(Theme.textPrimary)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
        }
    }
}

struct LabeledNumberField: View {
    let label: String
    @Binding var value: Double
    var placeholder: String = "0"
    var suffix: String = ""
    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            HStack(spacing: 6) {
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(Theme.body())
                    .foregroundColor(Theme.textPrimary)
                    .onChange(of: text) { newVal in
                        let cleaned = newVal.replacingOccurrences(of: ",", with: ".")
                        value = Double(cleaned) ?? 0
                    }
                if !suffix.isEmpty {
                    Text(suffix).font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
        }
        .onAppear { text = value == 0 ? "" : Formatters.decimal(value) }
    }
}

struct Stepper2: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...10
    var body: some View {
        HStack {
            Text(label).font(Theme.body()).foregroundColor(Theme.textPrimary)
            Spacer()
            HStack(spacing: 0) {
                stepButton("minus") { if value > range.lowerBound { value -= 1 } }
                Text("\(value)")
                    .font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                    .frame(minWidth: 38)
                stepButton("plus") { if value < range.upperBound { value += 1 } }
            }
            .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
        }
    }
    private func stepButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.accent)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Nav row (card-style NavigationLink)

struct NavRow<Destination: View>: View {
    let icon: String
    let title: String
    var subtitle: String = ""
    var tint: Color = Theme.accent
    var badge: Int = 0
    let destination: Destination

    init(icon: String, title: String, subtitle: String = "", tint: Color = Theme.accent,
         badge: Int = 0, @ViewBuilder destination: () -> Destination) {
        self.icon = icon; self.title = title; self.subtitle = subtitle
        self.tint = tint; self.badge = badge; self.destination = destination()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.16)).frame(width: 44, height: 44)
                    Image(systemName: icon).foregroundColor(tint).font(.system(size: 18, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if badge > 0 { TagChip(text: "\(badge)", color: Theme.attention, filled: true) }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textInactive)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
            .shadow(color: Theme.shadow, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty state

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundColor(Theme.accent)
            Text(title).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
            Text(message).font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Space.l)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
            .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [6, 5])).foregroundColor(Theme.stroke))
    }
}

// MARK: - Screen scaffold

struct ScreenScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil
    let content: () -> Content

    init(_ title: String, subtitle: String? = nil, trailing: AnyView? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.subtitle = subtitle; self.trailing = trailing; self.content = content
    }

    var body: some View {
        ZStack {
            PaintBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title).font(Theme.title(28)).foregroundColor(Theme.textPrimary)
                            if let s = subtitle {
                                Text(s).font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        if let t = trailing { t }
                    }
                    content()
                }
                .padding(Theme.Space.m)
                .padding(.bottom, 120)   // clear the custom tab bar
            }
            .simultaneousGesture(DragGesture().onChanged { _ in UIApplication.shared.dismissKeyboard() })
        }
    }
}
