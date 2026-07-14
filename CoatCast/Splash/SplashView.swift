import SwiftUI
import Combine
import Network

struct SplashView: View {
    
    @StateObject private var floor = Floor()

    // Lifecycle guard
    @State private var isVisible = true

    // Staged reveal flags
    @State private var bgIn = false
    @State private var dropSpread: CGFloat = 0
    @State private var strokeSweep = false
    @State private var logoIn = false
    @State private var exiting = false
    @State private var cancellables = Set<AnyCancellable>()

    // Looping flags
    @State private var shimmer = false
    @State private var ripple = false

    // Coordinator
    @State private var timer: Timer?
    @State private var networkMonitor = NWPathMonitor()
    @State private var elapsed: Double = 0

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                ZStack {
                    // ---- Layer 1: background gradient + drifting shimmer highlight ----
                    Color.black.ignoresSafeArea()

                    LinearGradient(colors: [.clear, Theme.accentSoft.opacity(0.35), .clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 280)
                        .rotationEffect(.degrees(26))
                        .offset(x: shimmer ? 340 : -340, y: shimmer ? 240 : -240)
                        .opacity(bgIn ? 1 : 0)
                        .ignoresSafeArea()
                    
                    Image(geo.size.width > geo.size.height ? "splash_imgl" : "splash_img")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                        .opacity(0.55)
                        .blur(radius: 6)
                    
                    NavigationLink(
                        destination: RootView().navigationBarBackButtonHidden(true),
                        isActive: $floor.navigateToMain
                    ) { EmptyView() }

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
                    
                    NavigationLink(
                        destination: SheenView().navigationBarHidden(true),
                        isActive: $floor.navigateToWeb
                    ) { EmptyView() }

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
                            Image("coat_cast_icon")
                                .resizable()
                                .frame(width: 92, height: 92)
                                .cornerRadius(92)
                        }
                        .scaleEffect(logoIn ? (exiting ? 1.6 : 1) : 0.3)
                        .opacity(logoIn ? (exiting ? 0 : 1) : 0)

                        VStack(spacing: 6) {
                            Text("COAT CAST")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .tracking(3)
                            Text("Loading application.")
                                .font(Theme.caption(14))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .opacity(logoIn ? (exiting ? 0 : 1) : 0)
                        .offset(y: logoIn ? 0 : 20)
                    }
                }
                .fullScreenCover(isPresented: $floor.showOfflineView) {
                    OfflineStation()
                }
                .onAppear {
                    wireStreams()
                    floor.ignite()
                    start()
                }
                .onDisappear { teardown() }
                .fullScreenCover(isPresented: $floor.showPermissionPrompt) {
                    ConsentStation(floor: floor)
                }
            }
            .ignoresSafeArea()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func wireStreams() {
        NotificationCenter.default.publisher(for: .pourArrived)
            .compactMap { $0.userInfo?["conversionData"] as? [String: Any] }
            .sink { data in
                floor.ingestPour(data)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .runnersArrived)
            .compactMap { $0.userInfo?["deeplinksData"] as? [String: Any] }
            .sink { data in
                floor.ingestRunners(data)
            }
            .store(in: &cancellables)
    }

    private func start() {
        isVisible = true
        elapsed = 0
        wireNetworkMonitoring()

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
    }

    private func teardown() {
        isVisible = false
        timer?.invalidate(); timer = nil
        shimmer = false
        ripple = false
        bgIn = false
        dropSpread = 0
        strokeSweep = false
        logoIn = false
        exiting = false
    }
    
    private func wireNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            Task { @MainActor in
                floor.networkConnectivityChanged(path.status == .satisfied)
            }
        }
        networkMonitor.start(queue: .global(qos: .background))
    }
    
}

struct ConsentStation: View {
    let floor: Floor

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(geometry.size.width > geometry.size.height ? "castingsl" : "castings")
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea().opacity(0.9)

                VStack(spacing: 12) {
                    Spacer()
                    Text("ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS")
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .multilineTextAlignment(.center)
                    Text("STAY TUNED WITH BEST OFFERS FROM OUR CASINO")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 12)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        floor.acceptConsent()
                    } label: {
                        Image("castings_btn")
                            .resizable()
                            .frame(width: 300, height: 55)
                    }
                    .padding(.horizontal, 12)

                    Button {
                        floor.skipConsent()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
    
}


struct OfflineStation: View {
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(geometry.size.width > geometry.size.height ? "application_error_imgl" : "application_error_img")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .opacity(0.85)
                    .blur(radius: 5)
                
                Image("application_error")
                    .resizable()
                    .frame(width: 245, height: 245)
            }
        }
        .ignoresSafeArea()
    }
    
}
