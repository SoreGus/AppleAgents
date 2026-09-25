import SwiftUI

struct ChatView: View {
    @Bindable var app: AppViewModel
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            conversation

            composer
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                Button {
                    isComposerFocused = false
                    app.newConversation()
                } label: {
                    Label(
                        "New Conversation",
                        systemImage: "square.and.pencil"
                    )
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    isComposerFocused = false
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            if let descriptor = app.selectedDescriptor {
                ModelBadge(descriptor: descriptor)

                if app.isSelectedModelPreparing {
                    ProgressView()
                        .controlSize(.small)
                }
            } else {
                Button {
                    isComposerFocused = false
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

            if app.selectedDescriptor != nil {
                Button {
                    isComposerFocused = false
                    app.destination = .models
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)
                .help("Models")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Conversation

    @ViewBuilder
    private var conversation: some View {
        if app.chat.messages.isEmpty {
            emptyConversation
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if !app.isSelectedModelReady {
                            modelStatusCard
                        }

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
                .scrollDismissesKeyboard(.interactively)
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

    // MARK: - Empty State

    private var emptyConversation: some View {
        Group {
            if app.isSelectedModelPreparing {
                preparingView
            } else if !app.isSelectedModelReady {
                unavailableView
            } else {
                readyView
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding()
    }

    private var preparingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)

            VStack(spacing: 8) {
                Text("Preparing Model")
                    .font(.title3.weight(.semibold))

                Text(
                    "The local model is being prepared for this device."
                )
                .foregroundStyle(.secondary)

                Text(
                    "You can continue using other apps while preparation completes."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)
        }
    }

    private var unavailableView: some View {
        ContentUnavailableView {
            Label(
                "Model Not Ready",
                systemImage: "cpu"
            )
        } description: {
            Text(
                app.selectedModelUnavailableMessage
                    ?? "Choose an available model to start a conversation."
            )
        } actions: {
            Button("Choose Model") {
                isComposerFocused = false
                app.destination = .models
            }
        }
    }

    private var readyView: some View {
        ContentUnavailableView {
            Label(
                "Start a Conversation",
                systemImage: "bubble.left.and.bubble.right"
            )
        } description: {
            Text(
                "Messages are sent through the currently selected model."
            )
        }
    }

    // MARK: - Status

    private var modelStatusCard: some View {
        HStack(alignment: .top, spacing: 12) {
            if app.isSelectedModelPreparing {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 2)
            } else {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(
                    app.isSelectedModelPreparing
                        ? "Preparing Model"
                        : "Model Not Ready"
                )
                .font(.subheadline.weight(.semibold))

                Text(
                    app.selectedModelUnavailableMessage
                        ?? "The selected model is not ready to use."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(
            .quaternary,
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(
            alignment: .bottom,
            spacing: 10
        ) {
            TextField(
                composerPlaceholder,
                text: draftBinding,
                axis: .vertical
            )
            .focused($isComposerFocused)
            .textFieldStyle(.plain)
            .lineLimit(1...6)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                .quaternary,
                in: RoundedRectangle(cornerRadius: 18)
            )
            .disabled(!app.canComposeMessage)
            .submitLabel(.send)
            .onSubmit {
                send()
            }

            Button {
                send()
            } label: {
                Group {
                    if app.chat.isResponding {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(
                            systemName: "arrow.up.circle.fill"
                        )
                        .font(.system(size: 30))
                    }
                }
                .frame(
                    width: 32,
                    height: 32
                )
            }
            .buttonStyle(.plain)
            .disabled(!app.canSendMessage)
            .help("Send")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var composerPlaceholder: String {
        if app.isSelectedModelPreparing {
            return "Preparing model…"
        }

        if !app.isSelectedModelReady {
            return "Choose a ready model to chat"
        }

        return "Message…"
    }

    // MARK: - Actions

    private func send() {
        guard app.canSendMessage else {
            return
        }

        Task {
            await app.sendMessage()
        }
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
