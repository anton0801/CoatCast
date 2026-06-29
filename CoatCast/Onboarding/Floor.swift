import Foundation
import Combine

@MainActor
final class Floor: ObservableObject {
    
    @Published var showOfflineView = false
    private var cancellables = Set<AnyCancellable>()
    @Published var showPermissionPrompt = false

    private let foundry: Foundry
    @Published var navigateToMain = false {
        didSet {
            if navigateToMain {
                deadlineTask?.cancel()
                uiLocked = true
            }
        }
    }
    private var deadlineTask: Task<Void, Never>?

    private var uiLocked: Bool = false

    init() {
        self.foundry = Works.shared.cast(Foundry.self)
        bindTaps()
    }

    deinit {
        deadlineTask?.cancel()
    }
    
    @Published var navigateToWeb = false {
        didSet {
            if navigateToWeb {
                deadlineTask?.cancel()
                uiLocked = true
            }
        }
    }

    private func bindTaps() {
        foundry.tapPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tap in
                self?.handleTap(tap)
            }
            .store(in: &cancellables)
    }
    
    private func handleTap(_ tap: Tap) {
        guard !uiLocked else { return }

        switch tap {
        case .idle:
            break
        case .askSeal:
            showPermissionPrompt = true
        case .cast:
            navigateToWeb = true
        case .scrap:
            navigateToMain = true
        }
    }

    func ingestRunners(_ data: [String: Any]) {
        foundry.loadRunners(data)
    }

    func acceptConsent() {
        foundry.sealMold {
            self.showPermissionPrompt = false
        }
    }

    func skipConsent() {
        showPermissionPrompt = false
        foundry.skipSeal()
    }

    func networkConnectivityChanged(_ connected: Bool) {
        if !connected {
            showOfflineView = true
        }
    }
    
    func ignite() {
        foundry.warmUp()
        armDeadline()
    }

    func ingestPour(_ data: [String: Any]) {
        Task {
            foundry.loadPour(data)
            await foundry.castBatch()
        }
    }

    private func armDeadline() {
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)

            guard let self = self else { return }

            if self.foundry.reportColdEnd() {
                self.handleTap(.scrap)
            }
        }
    }
}
