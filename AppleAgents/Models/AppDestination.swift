enum AppDestination: String, CaseIterable, Identifiable {
    case chat
    case models
    case settings

    #if DEBUG
    case diagnostics
    #endif

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .chat:
            "Chat"

        case .models:
            "Models"

        case .settings:
            "Settings"

        #if DEBUG
        case .diagnostics:
            "Diagnostics"
        #endif
        }
    }

    var symbol: String {
        switch self {
        case .chat:
            "bubble.left.and.bubble.right"

        case .models:
            "cpu"

        case .settings:
            "gearshape"

        #if DEBUG
        case .diagnostics:
            "waveform.path.ecg"
        #endif
        }
    }
}
