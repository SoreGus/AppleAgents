import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble
            }
        }
    }

    private var bubble: some View {
        Text(message.content)
            .textSelection(.enabled)
            .padding(12)
            .background(
                message.role == .user ? AnyShapeStyle(.tint.opacity(0.14)) : AnyShapeStyle(.quaternary),
                in: RoundedRectangle(cornerRadius: 14)
            )
    }
}
