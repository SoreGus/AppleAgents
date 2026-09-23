import Foundation

enum ModelSelection: Hashable, Codable, Sendable, Identifiable {
    case appleSystem
    case applePrivateCloud
    case openAI
    case local(String)

    var id: String {
        switch self {
        case .appleSystem:
            "apple.system"
        case .applePrivateCloud:
            "apple.private-cloud"
        case .openAI:
            "openai"
        case .local(let id):
            "local.\(id)"
        }
    }
}

struct ModelDescriptor: Identifiable, Hashable, Sendable {
    enum Category: String, Sendable {
        case apple = "Apple"
        case remote = "Remote"
        case local = "Local"
    }

    let selection: ModelSelection
    let name: String
    let detail: String
    let symbol: String
    let category: Category

    var id: String { selection.id }
}
