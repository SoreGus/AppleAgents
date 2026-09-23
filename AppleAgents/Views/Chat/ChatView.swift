import SwiftUI

struct ChatView: View {
    @Bindable var app: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            conversation

            Divider()

            composer
        }
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem {
                Button {
                    app.newConversation()
                } label: {
                    Label(
                        "New Conversation",
                        systemImage: "square.and.pencil"
                    )
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if let descriptor = app.selectedDescriptor {
                ModelBadge(descriptor: descriptor)
            } else {
                Button {
                    app.destination = .models
                } label: {
                    Label(
                        "Choose a model",
                        systemImage: "cpu"
                    )
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Conversation

    @ViewBuilder
    private var conversation: some View {
        if app.chat.messages.isEmpty {
            ContentUnavailableView {
                Label(
                    "Start a Conversation",
                    systemImage: "bubble.left.and.bubble.right"
                )
            } description: {
                if app.selectedDescriptor == nil {
                    Text(
                        "Choose an available model before sending a message."
                    )
                } else {
                    Text(
                        "Messages are sent through the currently selected model."
                    )
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(app.chat.messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }

                        if app.chat.isResponding {
                            HStack(spacing: 8) {
                                ProgressView()

                                Text("Thinking…")
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }
                            .id("responding")
                        }
                    }
                    .padding()
                }
                .onChange(of: app.chat.messages.count) {
                    guard let last = app.chat.messages.last else {
                        return
                    }

                    withAnimation {
                        proxy.scrollTo(
                            last.id,
                            anchor: .bottom
                        )
                    }
                }
                .onChange(of: app.chat.isResponding) {
                    guard app.chat.isResponding else {
                        return
                    }

                    withAnimation {
                        proxy.scrollTo(
                            "responding",
                            anchor: .bottom
                        )
                    }
                }
            }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(
            alignment: .bottom,
            spacing: 10
        ) {
            TextField(
                "Message…",
                text: draftBinding,
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...6)
            .onSubmit {
                guard app.canSendMessage else {
                    return
                }

                Task {
                    await app.sendMessage()
                }
            }

            Button {
                Task {
                    await app.sendMessage()
                }
            } label: {
                if app.chat.isResponding {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(
                        systemName: "arrow.up.circle.fill"
                    )
                    .font(.title2)
                }
            }
            .buttonStyle(.plain)
            .disabled(!app.canSendMessage)
            .help("Send")
        }
        .padding()
    }

    // MARK: - Bindings

    private var draftBinding: Binding<String> {
        Binding(
            get: {
                app.chat.draft
            },
            set: { value in
                app.chat.draft = value
            }
        )
    }
}
