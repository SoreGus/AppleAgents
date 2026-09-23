import AppleAgentKit
import CoreAILanguageModels
import Foundation
import FoundationModels
import Observation

@MainActor
@Observable
final class AppViewModel {
    var destination: AppDestination? = .chat
    private(set) var selectedModel: ModelSelection?
    var presentedError: String?
    var confirmationMessage: String?

    let chat = ChatViewModel()
    let localModels = LocalModelsViewModel()
    let remoteSettings = RemoteSettingsViewModel()

    @ObservationIgnored
    private let selectionStore = SelectionStore()

    @ObservationIgnored
    private let systemModel = SystemLanguageModel.default

    @ObservationIgnored
    private let privateCloudModel = PrivateCloudComputeLanguageModel()

    @ObservationIgnored
    private var session: LanguageModelSession?

    @ObservationIgnored
    private var sessionSelection: ModelSelection?

    private var didPrepare = false

    init() {
        selectedModel = selectionStore.load()
    }

    var nativeModels: [ModelDescriptor] {
        var models: [ModelDescriptor] = []
        if systemModel.isAvailable {
            models.append(
                ModelDescriptor(
                    selection: .appleSystem,
                    name: "On-Device Model",
                    detail: "Private, fast, and available offline",
                    symbol: "apple.intelligence",
                    category: .apple
                )
            )
        }
        if privateCloudModel.isAvailable {
            models.append(
                ModelDescriptor(
                    selection: .applePrivateCloud,
                    name: "Private Cloud Compute",
                    detail: "Apple intelligence with private cloud processing",
                    symbol: "cloud",
                    category: .apple
                )
            )
        }
        return models
    }

    var selectableModels: [ModelDescriptor] {
        var models = nativeModels

        if remoteSettings.isConfigured {
            models.append(
                ModelDescriptor(
                    selection: .openAI,
                    name: remoteSettings.modelID,
                    detail: "OpenAI",
                    symbol: "network",
                    category: .remote
                )
            )
        }

        models += localModels.catalog.compactMap { entry in
            guard entry.isSupportedOnCurrentDevice,
                  localModels.isInstalled(entry.id) else { return nil }
            return ModelDescriptor(
                selection: .local(entry.id),
                name: entry.displayName,
                detail: "Runs locally with CoreAI",
                symbol: "cpu",
                category: .local
            )
        }
        return models
    }

    var selectedDescriptor: ModelDescriptor? {
        guard let selectedModel else { return nil }
        return selectableModels.first { $0.selection == selectedModel }
    }

    var canSendMessage: Bool {
        selectedDescriptor != nil && chat.canSend
    }

    func prepare() async {
        guard !didPrepare else { return }
        didPrepare = true
        await localModels.prepare()
        validateSelection()
    }

    func select(_ selection: ModelSelection) {
        guard selectableModels.contains(where: { $0.selection == selection }) else { return }
        guard selectedModel != selection else { return }
        selectedModel = selection
        selectionStore.save(selection)
        resetSessionAndConversation()
    }

    func sendMessage() async {
        guard selectedDescriptor != nil else {
            presentedError = "Choose an available model before starting a conversation."
            return
        }

        do {
            let activeSession = try await languageModelSession()
            try await chat.send(using: activeSession)
        } catch {
            presentedError = userFacingMessage(for: error)
        }
    }

    func newConversation() {
        resetSessionAndConversation()
    }

    func install(_ entry: LocalModelCatalogEntry) {
        localModels.install(entry)
    }

    func cancel(_ entry: LocalModelCatalogEntry) async {
        do {
            try await localModels.cancel(entry)
        } catch {
            presentedError = userFacingMessage(for: error)
        }
    }

    func remove(_ entry: LocalModelCatalogEntry) async {
        do {
            try await localModels.remove(entry)
            if selectedModel == .local(entry.id) {
                selectedModel = nil
                selectionStore.save(nil)
                resetSessionAndConversation()
            }
        } catch {
            presentedError = userFacingMessage(for: error)
        }
    }

    func refreshLocalUpdates() async {
        await localModels.refreshUpdates()
    }

    func saveRemoteSettings() {
        do {
            try remoteSettings.save()
            confirmationMessage = "OpenAI configuration saved securely in Keychain."
            if selectedModel == .openAI {
                resetSessionAndConversation()
            } else {
                session = nil
                sessionSelection = nil
            }
            validateSelection()
        } catch {
            presentedError = userFacingMessage(for: error)
        }
    }

    func removeRemoteSettings() {
        do {
            try remoteSettings.remove()
            if selectedModel == .openAI {
                selectedModel = nil
                selectionStore.save(nil)
                resetSessionAndConversation()
            }
            confirmationMessage = "OpenAI configuration removed."
        } catch {
            presentedError = userFacingMessage(for: error)
        }
    }

    func openSettings() {
        destination = .settings
    }

    private func validateSelection() {
        if let selectedModel,
           selectableModels.contains(where: { $0.selection == selectedModel }) {
            return
        }

        selectedModel = selectableModels.first?.selection
        selectionStore.save(selectedModel)
    }

    private func resetSessionAndConversation() {
        session = nil
        sessionSelection = nil
        chat.reset()
    }

    private func languageModelSession() async throws -> LanguageModelSession {
        guard let selectedModel else {
            throw SessionCreationError.noModelSelected
        }
        if let session, sessionSelection == selectedModel {
            return session
        }

        let instructions = "You are a helpful, clear, and concise assistant."
        let newSession: LanguageModelSession

        switch selectedModel {
        case .appleSystem:
            guard systemModel.isAvailable else {
                throw SessionCreationError.modelUnavailable
            }
            newSession = LanguageModelSession(model: systemModel, instructions: instructions)

        case .applePrivateCloud:
            guard privateCloudModel.isAvailable else {
                throw SessionCreationError.modelUnavailable
            }
            newSession = LanguageModelSession(model: privateCloudModel, instructions: instructions)

        case .openAI:
            let configuration = try remoteSettings.configuration()
            let model = OpenAILanguageModel(
                modelID: configuration.modelID,
                apiKey: configuration.apiKey
            )
            newSession = LanguageModelSession(model: model, instructions: instructions)

        case .local(let id):
            guard let entry = localModels.entry(for: id),
                  entry.isSupportedOnCurrentDevice else {
                throw SessionCreationError.modelUnavailable
            }
            let installation = try await localModels.installation(for: id)
            let resourcesURL = installation.localURL.appending(
                path: entry.resourcePath,
                directoryHint: .isDirectory
            )
            let model = try await CoreAILanguageModel(resourcesAt: resourcesURL)
            newSession = LanguageModelSession(model: model, instructions: instructions)
        }

        session = newSession
        sessionSelection = selectedModel
        return newSession
    }

    private func userFacingMessage(for error: any Error) -> String {
        if let localized = error as? any LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return error.localizedDescription
    }
}

enum SessionCreationError: LocalizedError {
    case noModelSelected
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .noModelSelected:
            "Choose a model before starting a conversation."
        case .modelUnavailable:
            "The selected model is no longer available on this device."
        }
    }
}
