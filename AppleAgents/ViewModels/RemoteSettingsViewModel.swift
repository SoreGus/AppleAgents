import Foundation
import Observation

@MainActor
@Observable
final class RemoteSettingsViewModel {
    private enum Keys {
        static let apiKey = "openai-api-key"
        static let modelID = "openai-model-id"
    }

    var apiKey = ""
    var modelID: String
    var validationMessage: String?

    private(set) var isConfigured = false
    private let keychain: KeychainStore
    private let defaults: UserDefaults

    init(
        keychain: KeychainStore = KeychainStore(),
        defaults: UserDefaults = .standard
    ) {
        self.keychain = keychain
        self.defaults = defaults
        modelID = defaults.string(forKey: Keys.modelID) ?? "gpt-5.6"

        do {
            apiKey = try keychain.value(for: Keys.apiKey) ?? ""
            isConfigured = !apiKey.isEmpty && !modelID.isEmpty
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    func save() throws {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanKey.isEmpty else {
            throw RemoteConfigurationError.missingAPIKey
        }
        guard !cleanModelID.isEmpty else {
            throw RemoteConfigurationError.missingModelID
        }

        try keychain.set(cleanKey, for: Keys.apiKey)
        defaults.set(cleanModelID, forKey: Keys.modelID)
        apiKey = cleanKey
        modelID = cleanModelID
        isConfigured = true
        validationMessage = nil
    }

    func remove() throws {
        try keychain.removeValue(for: Keys.apiKey)
        defaults.removeObject(forKey: Keys.modelID)
        apiKey = ""
        modelID = "gpt-5.6"
        isConfigured = false
        validationMessage = nil
    }

    func configuration() throws -> (modelID: String, apiKey: String) {
        guard isConfigured, !apiKey.isEmpty else {
            throw RemoteConfigurationError.missingAPIKey
        }
        return (modelID, apiKey)
    }
}

enum RemoteConfigurationError: LocalizedError {
    case missingAPIKey
    case missingModelID

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add an OpenAI API key in Settings before using this model."
        case .missingModelID:
            "Enter an OpenAI model ID."
        }
    }
}
