enum AppDestination: String, CaseIterable, Identifiable {
    case chat
    case models
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: "Chat"
        case .models: "Models"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .models: "cpu"
        case .settings: "gearshape"
        }
    }
}
