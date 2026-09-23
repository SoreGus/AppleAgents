import Foundation
import FoundationModels
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var draft = ""
    private(set) var messages: [ChatMessage] = []
    private(set) var isResponding = false

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isResponding
    }

    func send(using session: LanguageModelSession) async throws {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isResponding else { return }

        draft = ""
        messages.append(ChatMessage(role: .user, content: prompt))
        isResponding = true
        defer { isResponding = false }

        let response = try await session.respond(to: prompt)
        messages.append(ChatMessage(role: .assistant, content: response.content))
    }

    func reset() {
        messages.removeAll()
        draft = ""
        isResponding = false
    }
}
