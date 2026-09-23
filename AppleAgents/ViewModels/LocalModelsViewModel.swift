import AppleAgentKit
import Foundation
import Observation

@MainActor
@Observable
final class LocalModelsViewModel {
    private(set) var catalog: [LocalModelCatalogEntry] = []
    private(set) var states: [String: LocalModelInstallationState] = [:]
    private(set) var isRefreshingUpdates = false
    private(set) var catalogError: String?

    @ObservationIgnored
    private var provider: HuggingFaceModelProvider?

    @ObservationIgnored
    private var installationTasks: [String: Task<Void, Never>] = [:]

    init() {
        do {
            let entries = try LocalModelCatalogLoader.load()
            catalog = entries
            provider = try HuggingFaceModelProvider(models: entries.map(\.huggingFaceModel))
            states = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, .notInstalled) })
        } catch {
            catalogError = error.localizedDescription
        }
    }

    func state(for entry: LocalModelCatalogEntry) -> LocalModelInstallationState {
        states[entry.id] ?? .notInstalled
    }

    func prepare() async {
        guard let provider else { return }

        for entry in catalog {
            do {
                let state = try await provider.state(for: entry.id)
                states[entry.id] = state
            } catch {
                states[entry.id] = .invalid(error.localizedDescription)
            }
        }

        for entry in catalog {
            if case .downloading = state(for: entry), entry.isSupportedOnCurrentDevice {
                install(entry)
            }
        }
    }

    func install(_ entry: LocalModelCatalogEntry) {
        guard entry.isSupportedOnCurrentDevice,
              provider != nil,
              installationTasks[entry.id] == nil else { return }

        installationTasks[entry.id] = Task { [weak self] in
            await self?.performInstallation(entry)
        }
    }

    func cancel(_ entry: LocalModelCatalogEntry) async throws {
        guard let provider else { return }
        installationTasks[entry.id]?.cancel()
        installationTasks[entry.id] = nil
        try await provider.cancelInstallation(of: entry.id)
        states[entry.id] = .notInstalled
    }

    func remove(_ entry: LocalModelCatalogEntry) async throws {
        guard let provider else { return }
        installationTasks[entry.id]?.cancel()
        installationTasks[entry.id] = nil
        try await provider.removeModel(identifiedBy: entry.id)
        states[entry.id] = .notInstalled
    }

    func refreshUpdates() async {
        guard let provider, !isRefreshingUpdates else { return }
        isRefreshingUpdates = true
        defer { isRefreshingUpdates = false }

        for entry in catalog where entry.isSupportedOnCurrentDevice {
            switch state(for: entry) {
            case .installed, .updateAvailable:
                do {
                    states[entry.id] = try await provider.refreshedState(for: entry.id)
                } catch {
                    states[entry.id] = .invalid(error.localizedDescription)
                }
            default:
                continue
            }
        }
    }

    func installation(for id: String) async throws -> LocalModelInstallation {
        guard let provider,
              let installation = try await provider.installedModel(identifiedBy: id) else {
            throw LocalModelAccessError.notInstalled
        }
        return installation
    }

    func entry(for id: String) -> LocalModelCatalogEntry? {
        catalog.first { $0.id == id }
    }

    func isInstalled(_ id: String) -> Bool {
        guard let state = states[id] else { return false }
        switch state {
        case .installed, .updateAvailable:
            return true
        default:
            return false
        }
    }

    private func performInstallation(_ entry: LocalModelCatalogEntry) async {
        guard let provider else { return }

        do {
            let installation = try await provider.install(entry.id) { [weak self] progress in
                self?.states[entry.id] = .downloading(progress)
            }
            states[entry.id] = .installed(installation)
        } catch {
            if Task.isCancelled {
                states[entry.id] = .notInstalled
            } else {
                states[entry.id] = .invalid(error.localizedDescription)
            }
        }
        installationTasks[entry.id] = nil
    }
}

enum LocalModelAccessError: LocalizedError {
    case notInstalled

    var errorDescription: String? {
        "Install the local model before selecting it."
    }
}
