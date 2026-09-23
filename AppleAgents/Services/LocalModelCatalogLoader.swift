import Foundation

enum LocalModelCatalogLoader {
    static func load() throws -> [LocalModelCatalogEntry] {
        let url = Bundle.main.url(
            forResource: "local-models",
            withExtension: "json",
            subdirectory: "Resources"
        ) ?? Bundle.main.url(
            forResource: "local-models",
            withExtension: "json"
        )

        guard let url else {
            throw CatalogError.missingResource
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([LocalModelCatalogEntry].self, from: data)
        } catch let error as CatalogError {
            throw error
        } catch {
            throw CatalogError.invalidResource(error.localizedDescription)
        }
    }
}

enum CatalogError: LocalizedError {
    case missingResource
    case invalidResource(String)

    var errorDescription: String? {
        switch self {
        case .missingResource:
            "The bundled local model catalog could not be found."
        case .invalidResource(let detail):
            "The local model catalog is invalid. \(detail)"
        }
    }
}
