import CoreAI
import Foundation

struct LocalCoreAIModelPreparer {
    private let cache: AIModelCache
    private let options: SpecializationOptions

    init(
        cache: AIModelCache = .default,
        options: SpecializationOptions = .default
    ) {
        self.cache = cache
        self.options = options
    }

    func prepare(resourcesAt resourcesURL: URL) async throws {
        let modelURL = try mainModelURL(in: resourcesURL)

        if try cache.model(for: modelURL, options: options) != nil {
            return
        }

        try await AIModel.specialize(
            contentsOf: modelURL,
            options: options,
            cache: cache,
            cachePolicy: .persistent
        )

        guard try cache.model(for: modelURL, options: options) != nil else {
            throw LocalCoreAIModelPreparationError.specializationNotCached
        }
    }

    func isPrepared(resourcesAt resourcesURL: URL) throws -> Bool {
        let modelURL = try mainModelURL(in: resourcesURL)
        return try cache.model(for: modelURL, options: options) != nil
    }

    /// Intentionally not used after specialization.
    ///
    /// CoreAILanguageModel still needs the resource bundle at runtime because it
    /// contains metadata, the tokenizer, and the model asset path. Removing the
    /// Hugging Face installation here would make the current
    /// CoreAILanguageModel(resourcesAt:) integration unusable.
    ///
    /// Keep this operation explicit so it can be enabled later if
    /// CoreAILanguageModel gains a way to initialize directly from a cached
    /// AIModel/bookmark while retaining the tokenizer and bundle metadata.
    func deleteSourceResources(at resourcesURL: URL) throws {
        guard FileManager.default.fileExists(atPath: resourcesURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: resourcesURL)
    }

    private func mainModelURL(in resourcesURL: URL) throws -> URL {
        let metadataURL = resourcesURL.appending(path: "metadata.json")

        if FileManager.default.fileExists(atPath: metadataURL.path) {
            let data = try Data(contentsOf: metadataURL)
            let object = try JSONSerialization.jsonObject(with: data)

            if let dictionary = object as? [String: Any],
               let assets = dictionary["assets"] as? [String: Any],
               let main = assets["main"] as? String {
                let declaredURL = resourcesURL.appending(path: main)

                if FileManager.default.fileExists(atPath: declaredURL.path) {
                    return declaredURL
                }

                if main.hasSuffix(".aimodel") {
                    let compiledURL = resourcesURL.appending(path: main + "c")
                    if FileManager.default.fileExists(atPath: compiledURL.path) {
                        return compiledURL
                    }
                }
            }
        }

        let children = try FileManager.default.contentsOfDirectory(
            at: resourcesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        if let modelURL = children.first(where: { $0.pathExtension == "aimodel" }) {
            return modelURL
        }

        if let modelURL = children.first(where: { $0.pathExtension == "aimodelc" }) {
            return modelURL
        }

        throw LocalCoreAIModelPreparationError.modelAssetNotFound
    }
}

enum LocalCoreAIModelPreparationError: LocalizedError {
    case modelAssetNotFound
    case specializationNotCached

    var errorDescription: String? {
        switch self {
        case .modelAssetNotFound:
            "The Core AI model asset could not be found in the downloaded resources."
        case .specializationNotCached:
            "Core AI finished preparing the model, but the specialized model was not found in the persistent cache."
        }
    }
}

enum LocalModelPreparationState: Equatable {
    case idle
    case checking
    case preparing
    case ready
    case failed(String)

    var isPreparing: Bool {
        switch self {
        case .checking, .preparing:
            true
        default:
            false
        }
    }
}
