//
//  OnboardingView.swift
//  CoatCast
//
//  Four interactive setup screens that write PaintPrefs (the engine's input bus).
//  Each screen uses a distinct gesture: O1 tap-to-burst, O2 drag-to-reveal,
//  O3 sliders + scroll parallax, O4 long-press polish. Skip + Next always
//  visible, custom dot indicator. All looping animations stop on .onDisappear.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    let onComplete: () -> Void

    @State private var page = 0
    @State private var paintType: PaintType = .water
    @State private var surface: Surface = .walls
    @State private var temperature: Double = 20
    @State private var humidity: Double = 50
    @State private var finish: Finish = .matte

    var body: some View {
        ZStack {
            PaintBackground(animated: true).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: progress + skip
                HStack {
                    Text("Set up your paint")
                        .font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                    Spacer()
                    Button("Skip") { completeSetup() }
                        .font(Theme.caption(14)).foregroundColor(Theme.accentActive)
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.top, Theme.Space.m)

                TabView(selection: $page) {
                    PaintTypePage(selected: $paintType).tag(0)
                    SurfacePage(selected: $surface).tag(1)
                    ClimatePage(temperature: $temperature, humidity: $humidity, paintType: paintType).tag(2)
                    FinishPage(selected: $finish).tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i == page ? Theme.accent : Theme.stroke)
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                    }
                }
                .padding(.vertical, 14)

                ActionButton(title: primaryTitle,
                             systemImage: page == 3 ? "paintbrush.pointed.fill" : "arrow.right") {
                    advance()
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.bottom, Theme.Space.l)
            }
        }
        .onAppear {
            let p = store.prefs
            paintType = p.paintType
            surface = p.surface
            temperature = p.temperatureC
            humidity = p.humidityPct
            finish = p.finish
        }
    }

    private var primaryTitle: String {
        switch page {
        case 0: return "Set Paint"
        case 1: return "Set Surface"
        case 2: return "Set Climate"
        default: return "Start Casting"
        }
    }

    private func advance() {
        if page < 3 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { page += 1 }
        } else {
            completeSetup()
        }
    }

    private func completeSetup() {
        store.updatePrefs { p in
            p.paintType = paintType
            p.surface = surface
            p.temperatureC = temperature
            p.humidityPct = humidity
            p.finish = finish
        }
        onComplete()
    }
}

// MARK: - Shared select card

private struct SelectCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(isSelected ? Theme.onAccent : tint)
                Text(title).font(Theme.heading(15))
                    .foregroundColor(isSelected ? Theme.onAccent : Theme.textPrimary)
                Text(subtitle).font(Theme.caption(11))
                    .foregroundColor(isSelected ? Theme.onAccent.opacity(0.8) : Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18).padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m)
                .fill(isSelected ? tint : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
                .stroke(isSelected ? Color.clear : Theme.stroke, lineWidth: 1))
            .shadow(color: isSelected ? Theme.glow : Theme.shadow, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct PageHeader: View {
    let step: String
    let title: String
    let blurb: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(step).font(Theme.caption(12)).foregroundColor(Theme.accentActive).tracking(1.5)
            Text(title).font(Theme.title(26)).foregroundColor(Theme.textPrimary)
            Text(blurb).font(Theme.caption(14)).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - O1 Paint Type (tap-to-burst)

private struct PaintTypePage: View {
    @Binding var selected: PaintType
    @State private var pulse = false
    @State private var bursts: [Burst] = []

    struct Burst: Identifiable { let id = UUID(); let angle: Double; var go = false }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Space.l) {
                PageHeader(step: "STEP 1 OF 4", title: "Paint Type",
                           blurb: "Tap the can to feel it, then pick a type. This sets coverage and base drying time.")

                ZStack {
                    ForEach(bursts) { b in
                        Circle().fill(Theme.accent)
                            .frame(width: 9, height: 9)
                            .offset(x: b.go ? CGFloat(cos(b.angle)) * 95 : 0,
                                    y: b.go ? CGFloat(sin(b.angle)) * 95 : 0)
                            .opacity(b.go ? 0 : 1)
                    }
                    Circle()
                        .fill(Theme.accentGradient)
                        .frame(width: 118, height: 118)
                        .scaleEffect(pulse ? 1.05 : 0.96)
                        .overlay(Image(systemName: selected.icon)
                            .font(.system(size: 46, weight: .bold)).foregroundColor(.white))
                        .shadow(color: Theme.glow, radius: 16, x: 0, y: 8)
                }
                .frame(height: 150)
                .contentShape(Rectangle())
                .onTapGesture { burst() }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(PaintType.allCases) { t in
                        SelectCard(title: t.displayName,
                                   subtitle: "\(Formatters.decimal(t.baseCoverage)) m²/L",
                                   icon: t.icon,
                                   isSelected: selected == t) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selected = t }
                            burst()
                        }
                    }
                }

                CardView {
                    HStack {
                        Image(systemName: "timer").foregroundColor(Theme.accent)
                        Text("Base recoat time")
                            .font(Theme.caption(13)).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(Formatters.minutesShort(selected.baseRecoatMinutes))
                            .font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                    }
                }
            }
            .padding(Theme.Space.l)
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true } }
        .onDisappear { pulse = false; bursts.removeAll() }
    }

    private func burst() {
        bursts = (0..<12).map { Burst(angle: Double($0) / 12 * 2 * .pi) }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.6)) { for i in bursts.indices { bursts[i].go = true } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { bursts.removeAll() }
    }
}

// MARK: - O2 Surface (drag-to-reveal coverage)

private struct SurfacePage: View {
    @Binding var selected: Surface
    @State private var reveal: CGFloat = 0     // 0...1 painted fraction

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Space.l) {
                PageHeader(step: "STEP 2 OF 4", title: "Surface",
                           blurb: "Drag the roller across the wall to paint it. Surface sets absorption and default coats.")

                // Drag-to-reveal swatch
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surfaceAlt)
                            .overlay(Text("Drag to paint →").font(Theme.caption(13))
                                .foregroundColor(Theme.textInactive))
                        RoundedRectangle(cornerRadius: Theme.Radius.m)
                            .fill(Color(hex: selected == .metal ? 0x9CA3AF : 0x5EEAD4))
                            .frame(width: max(0, w * reveal))
                        // Roller knob
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Theme.accentActive)
                            .frame(width: 16, height: 70)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.5), lineWidth: 1))
                            .offset(x: max(0, w * reveal - 8))
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in reveal = min(1, max(0, v.location.x / w)) })
                }
                .frame(height: 96)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Surface.allCases) { s in
                        SelectCard(title: s.displayName,
                                   subtitle: "\(s.defaultCoats) coats · ×\(Formatters.decimal(s.absorptionFactor))",
                                   icon: s.icon,
                                   isSelected: selected == s) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selected = s }
                        }
                    }
                }
            }
            .padding(Theme.Space.l)
        }
        .onDisappear { reveal = 0 }
    }
}

// MARK: - O3 Climate (sliders + scroll parallax)

private struct ClimatePage: View {
    @Binding var temperature: Double
    @Binding var humidity: Double
    let paintType: PaintType
    @State private var scrollY: CGFloat = 0

    private struct OffsetKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }

    private var dryMinutes: Double {
        PaintEngine.dryMinutes(type: paintType, temperatureC: temperature, humidityPct: humidity)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .top) {
                // Parallax drips that drift with scroll
                DripShape().fill(Theme.accentSoft.opacity(0.5))
                    .frame(width: 26, height: 90)
                    .offset(x: -120, y: -scrollY * 0.35 + 30)
                DripShape().fill(Theme.pink.opacity(0.4))
                    .frame(width: 20, height: 70)
                    .offset(x: 130, y: -scrollY * 0.2 + 60)

                VStack(spacing: Theme.Space.l) {
                    GeometryReader { proxy in
                        Color.clear.preference(key: OffsetKey.self,
                                               value: proxy.frame(in: .named("climate")).minY)
                    }.frame(height: 0)

                    PageHeader(step: "STEP 3 OF 4", title: "Room Climate",
                               blurb: "Colder and more humid rooms dry slower. Set the conditions — the dry window updates live.")

                    CardView {
                        VStack(alignment: .leading, spacing: 18) {
                            sliderRow(title: "Temperature",
                                      value: $temperature, range: 5...35, unit: "°C",
                                      icon: "thermometer.medium", tint: Theme.orange)
                            sliderRow(title: "Humidity",
                                      value: $humidity, range: 10...95, unit: "%",
                                      icon: "humidity.fill", tint: Theme.accent)
                        }
                    }

                    CardView(tint: Theme.drying) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Theme.drying.opacity(0.16)).frame(width: 54, height: 54)
                                Image(systemName: "hourglass").foregroundColor(Theme.drying)
                                    .font(.system(size: 22, weight: .bold))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Estimated dry window").font(Theme.caption(12))
                                    .foregroundColor(Theme.textSecondary)
                                Text(Formatters.minutesShort(dryMinutes))
                                    .font(Theme.title(24)).foregroundColor(Theme.textPrimary)
                            }
                            Spacer()
                            Text("×\(Formatters.decimal(PaintEngine.climateMultiplier(temperatureC: temperature, humidityPct: humidity)))")
                                .font(Theme.heading(15)).foregroundColor(Theme.drying)
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding(Theme.Space.l)
            }
        }
        .coordinateSpace(name: "climate")
        .onPreferenceChange(OffsetKey.self) { scrollY = $0 }
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>,
                           unit: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundColor(tint)
                Text(title).font(Theme.body()).foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))\(unit)")
                    .font(Theme.heading(16)).foregroundColor(tint)
            }
            Slider(value: value, in: range).accentColor(tint)
        }
    }
}

// MARK: - O4 Finish (long-press polish)

private struct FinishPage: View {
    @Binding var selected: Finish
    @State private var shineX: CGFloat = -1   // -1 hidden left, 1 swept right
    @State private var polishing = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Space.l) {
                PageHeader(step: "STEP 4 OF 4", title: "Finish Goal",
                           blurb: "Press and hold the swatch to polish it to a shine. The finish sets your recommended coats.")

                // Long-press to polish (shine sweep)
                GeometryReader { geo in
                    ZStack {
                        RoundedRectangle(cornerRadius: Theme.Radius.l)
                            .fill(Color(hex: selected.colorPreviewHex))
                        // Shine highlight that sweeps across on long-press
                        LinearGradient(colors: [.clear, Color.white.opacity(0.85), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 90)
                            .rotationEffect(.degrees(18))
                            .offset(x: shineX * (geo.size.width / 2 + 60))
                            .opacity(selected == .gloss ? 1 : 0.5)
                        Text(polishing ? "Polishing…" : "Hold to polish")
                            .font(Theme.caption(13)).foregroundColor(Theme.textPrimary.opacity(0.7))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l))
                    .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
                        polishing = pressing
                        if pressing { sweep() }
                    }, perform: {})
                }
                .frame(height: 120)

                VStack(spacing: 12) {
                    ForEach(Finish.allCases) { f in
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selected = f }
                            sweep()
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: f.icon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(selected == f ? Theme.onAccent : Theme.accent)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.displayName).font(Theme.heading(16))
                                        .foregroundColor(selected == f ? Theme.onAccent : Theme.textPrimary)
                                    Text(f.subtitle).font(Theme.caption(12))
                                        .foregroundColor(selected == f ? Theme.onAccent.opacity(0.8) : Theme.textSecondary)
                                }
                                Spacer()
                                TagChip(text: "\(f.recommendedCoats) coats",
                                        color: selected == f ? Theme.onAccent : Theme.accent,
                                        filled: false)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.m)
                                .fill(selected == f ? Theme.accent : Theme.surface))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
                                .stroke(selected == f ? Color.clear : Theme.stroke, lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(Theme.Space.l)
        }
        .onDisappear { shineX = -1; polishing = false }
    }

    private func sweep() {
        shineX = -1
        withAnimation(.easeInOut(duration: 0.7)) { shineX = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { shineX = -1 }
    }
}

private extension Finish {
    var colorPreviewHex: UInt {
        switch self {
        case .matte: return 0xE8F0F2
        case .satin: return 0x5EEAD4
        case .gloss: return 0x14B8A6
        }
    }
}
