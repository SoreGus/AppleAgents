import AppleAgentKit
import CoreAI
import CoreAILanguageModels
import Foundation
import FoundationModels
import Observation

@MainActor
@Observable
final class AppViewModel {
    var destination: AppDestination? = .chat

    private(set) var selectedModel: ModelSelection?

    private(set) var localModelPreparationStates: [
        String: LocalModelPreparationState
    ] = [:]

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

    #if os(iOS)
    @ObservationIgnored
    private let localModelPreparationCoordinator =
        LocalCoreAIModelPreparationCoordinator.shared
    #else
    @ObservationIgnored
    private let localModelPreparer = LocalCoreAIModelPreparer()
    #endif

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
                  localModels.isInstalled(entry.id) else {
                return nil
            }

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
        guard let selectedModel else {
            return nil
        }

        return selectableModels.first {
            $0.selection == selectedModel
        }
    }

    var isSelectedModelReady: Bool {
        guard let selectedModel,
              selectedDescriptor != nil else {
            return false
        }

        if case .local(let id) = selectedModel {
            return localModelPreparationState(for: id) == .ready
        }

        return true
    }

    var isSelectedModelPreparing: Bool {
        guard case .local(let id) = selectedModel else {
            return false
        }

        switch localModelPreparationState(for: id) {
        case .checking, .preparing:
            return true

        default:
            return false
        }
    }

    var selectedModelUnavailableMessage: String? {
        guard selectedDescriptor != nil else {
            return "Choose an available model to start a conversation."
        }

        guard case .local(let id) = selectedModel else {
            return nil
        }

        switch localModelPreparationState(for: id) {
        case .checking:
            return "Checking whether this model is ready for this device…"

        case .preparing:
            return """
            Preparing this model for your device. \
            You can continue using other apps while preparation completes.
            """

        case .failed(let message):
            return "The local model could not be prepared. \(message)"

        case .idle:
            return """
            This local model still needs to be prepared before it can be used.
            """

        case .ready:
            return nil
        }
    }

    var canSendMessage: Bool {
        isSelectedModelReady && chat.canSend
    }

    var canComposeMessage: Bool {
        isSelectedModelReady && !chat.isResponding
    }

    func localModelPreparationState(
        for id: String
    ) -> LocalModelPreparationState {
        localModelPreparationStates[id] ?? .idle
    }

    func prepare() async {
        guard !didPrepare else {
            return
        }

        didPrepare = true

        await localModels.prepare()
        await refreshInstalledLocalModelPreparationStates()

        validateSelection()

        await prepareSelectedModelIfNeeded()
    }

    func select(_ selection: ModelSelection) {
        guard selectableModels.contains(
            where: { $0.selection == selection }
        ) else {
            return
        }

        guard selectedModel != selection else {
            return
        }

        selectedModel = selection
        selectionStore.save(selection)

        resetSessionAndConversation()

        Task { [weak self] in
            await self?.prepareSelectedModelIfNeeded()
        }
    }

    func sendMessage() async {
        guard selectedDescriptor != nil else {
            presentedError =
                "Choose an available model before starting a conversation."
            return
        }

        guard isSelectedModelReady else {
            presentedError =
                selectedModelUnavailableMessage
                ?? "The selected model is not ready yet."
            return
        }

        do {
            let activeSession = try await languageModelSession()

            try await chat.send(
                using: activeSession
            )
        } catch {
            presentedError = userFacingMessage(for: error)
        }
    }

    func newConversation() {
        resetSessionAndConversation()
    }

    func install(_ entry: LocalModelCatalogEntry) {
        localModelPreparationStates[entry.id] = .idle

        localModels.install(entry)
    }

    func cancel(_ entry: LocalModelCatalogEntry) async {
        do {
            try await localModels.cancel(entry)

            localModelPreparationStates[entry.id] = .idle
        } catch {
            presentedError = userFacingMessage(for: error)
        }
    }

    func remove(_ entry: LocalModelCatalogEntry) async {
        do {
            try await localModels.remove(entry)

            localModelPreparationStates[entry.id] = .idle

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

        await refreshInstalledLocalModelPreparationStates()
    }

    func saveRemoteSettings() {
        do {
            try remoteSettings.save()

            confirmationMessage =
                "OpenAI configuration saved securely in Keychain."

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

            confirmationMessage =
                "OpenAI configuration removed."
        } catch {
            presentedError = userFacingMessage(for: error)
        }
    }

    func openSettings() {
        destination = .settings
    }

    private func validateSelection() {
        if let selectedModel,
           selectableModels.contains(
               where: { $0.selection == selectedModel }
           ) {
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

    private func refreshInstalledLocalModelPreparationStates() async {
        for entry in localModels.catalog
        where entry.isSupportedOnCurrentDevice
            && localModels.isInstalled(entry.id) {

            localModelPreparationStates[entry.id] = .checking

            do {
                let resourcesURL =
                    try await localResourcesURL(for: entry)

                let prepared =
                    try isLocalModelPrepared(
                        resourcesAt: resourcesURL
                    )

                localModelPreparationStates[entry.id] =
                    prepared ? .ready : .idle
            } catch {
                localModelPreparationStates[entry.id] =
                    .failed(
                        userFacingMessage(for: error)
                    )
            }
        }
    }

    private func prepareSelectedModelIfNeeded() async {
        guard case .local = selectedModel else {
            return
        }

        do {
            _ = try await languageModelSession()
        } catch {
            presentedError = userFacingMessage(for: error)
        }
    }

    private func prepareLocalModel(
        _ entry: LocalModelCatalogEntry
    ) async throws -> URL {
        let resourcesURL =
            try await localResourcesURL(for: entry)

        localModelPreparationStates[entry.id] = .checking

        if try isLocalModelPrepared(
            resourcesAt: resourcesURL
        ) {
            return resourcesURL
        }

        localModelPreparationStates[entry.id] = .preparing

        do {
            #if os(iOS)
            try await localModelPreparationCoordinator.prepare(
                resourcesAt: resourcesURL,
                modelName: entry.displayName
            )
            #else
            try await localModelPreparer.prepare(
                resourcesAt: resourcesURL
            )
            #endif

            return resourcesURL
        } catch {
            localModelPreparationStates[entry.id] =
                .failed(
                    userFacingMessage(for: error)
                )

            throw error
        }
    }

    private func isLocalModelPrepared(
        resourcesAt resourcesURL: URL
    ) throws -> Bool {
        #if os(iOS)
        return try localModelPreparationCoordinator.isPrepared(
            resourcesAt: resourcesURL
        )
        #else
        return try localModelPreparer.isPrepared(
            resourcesAt: resourcesURL
        )
        #endif
    }

    private func localResourcesURL(
        for entry: LocalModelCatalogEntry
    ) async throws -> URL {
        let installation =
            try await localModels.installation(
                for: entry.id
            )

        return installation.localURL.appending(
            path: entry.resourcePath,
            directoryHint: .isDirectory
        )
    }

    private func languageModelSession() async throws
        -> LanguageModelSession {

        guard let selectedModel else {
            throw SessionCreationError.noModelSelected
        }

        if let session,
           sessionSelection == selectedModel {
            return session
        }

        let instructions =
            "You are a helpful, clear, and concise assistant."

        let newSession: LanguageModelSession

        switch selectedModel {
        case .appleSystem:
            guard systemModel.isAvailable else {
                throw SessionCreationError.modelUnavailable
            }

            newSession = LanguageModelSession(
                model: systemModel,
                instructions: instructions
            )

        case .applePrivateCloud:
            guard privateCloudModel.isAvailable else {
                throw SessionCreationError.modelUnavailable
            }

            newSession = LanguageModelSession(
                model: privateCloudModel,
                instructions: instructions
            )

        case .openAI:
            let configuration =
                try remoteSettings.configuration()

            let model = OpenAILanguageModel(
                modelID: configuration.modelID,
                apiKey: configuration.apiKey
            )

            newSession = LanguageModelSession(
                model: model,
                instructions: instructions
            )

        case .local(let id):
            guard let entry = localModels.entry(for: id),
                  entry.isSupportedOnCurrentDevice else {
                throw SessionCreationError.modelUnavailable
            }

            do {
                let resourcesURL =
                    try await prepareLocalModel(entry)

                let model =
                    try await CoreAILanguageModel(
                        resourcesAt: resourcesURL
                    )

                newSession = LanguageModelSession(
                    model: model,
                    instructions: instructions
                )

                localModelPreparationStates[id] = .ready
            } catch {
                localModelPreparationStates[id] =
                    .failed(
                        userFacingMessage(for: error)
                    )

                throw error
            }
        }

        session = newSession
        sessionSelection = selectedModel

        return newSession
    }

    private func userFacingMessage(
        for error: any Error
    ) -> String {
        if let localized =
            error as? any LocalizedError,
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
