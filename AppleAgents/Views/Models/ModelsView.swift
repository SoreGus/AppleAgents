import SwiftUI

struct ModelsView: View {
    @Bindable var app: AppViewModel

    var body: some View {
        Form {
            nativeSection
            remoteSection
            localSection
        }
        .formStyle(.grouped)
        .navigationTitle("Models")
        .toolbar {
            ToolbarItem {
                Button {
                    Task {
                        await app.refreshLocalUpdates()
                    }
                } label: {
                    if app.localModels.isRefreshingUpdates {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(
                            "Check for Updates",
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
                .disabled(app.localModels.isRefreshingUpdates)
            }
        }
    }

    // MARK: - Native

    @ViewBuilder
    private var nativeSection: some View {
        if !app.nativeModels.isEmpty {
            Section {
                ForEach(app.nativeModels) { model in
                    modelRow(model)
                }
            } header: {
                Text("Apple Native")
            }
        }
    }

    // MARK: - Remote

    private var remoteSection: some View {
        Section {
            if app.remoteSettings.isConfigured {
                ModelDescriptorRow(
                    name: app.remoteSettings.modelID,
                    detail: "OpenAI",
                    symbol: "network",
                    selected: app.selectedModel == .openAI
                ) {
                    app.select(.openAI)
                }
            } else {
                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {
                    Label(
                        "OpenAI",
                        systemImage: "network"
                    )
                    .font(.headline)

                    Text(
                        "Add an API key and model ID in Settings to enable the remote model."
                    )
                    .foregroundStyle(.secondary)

                    Button("Configure OpenAI") {
                        app.openSettings()
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Remote")
        }
    }

    // MARK: - Local

    private var localSection: some View {
        Section {
            LocalModelsView(app: app)

            if case .local(let id) = app.selectedModel {
                LocalModelPreparationStatusView(
                    state: app.localModelPreparationState(for: id)
                )
            }
        } header: {
            Text("Local")
        } footer: {
            Text(
                "Local models are downloaded through Hugging Face. Core AI prepares the selected model for this device before the first session."
            )
        }
    }

    // MARK: - Rows

    private func modelRow(
        _ model: ModelDescriptor
    ) -> some View {
        ModelDescriptorRow(
            name: model.name,
            detail: model.detail,
            symbol: model.symbol,
            selected: app.selectedModel == model.selection
        ) {
            app.select(model.selection)
        }
    }
}

private struct LocalModelPreparationStatusView: View {
    let state: LocalModelPreparationState

    var body: some View {
        switch state {
        case .idle:
            Label(
                "The model will be prepared for this device when it is first used.",
                systemImage: "cpu"
            )
            .foregroundStyle(.secondary)

        case .checking:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)

                Text("Checking device preparation…")
            }

        case .preparing:
            HStack(alignment: .top, spacing: 10) {
                ProgressView()
                    .controlSize(.small)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Preparing model for this device…")
                    Text("This can take a while the first time. Keep the app open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        case .ready:
            Label(
                "Ready for this device",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 3) {
                Label(
                    "Model preparation failed",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.red)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ModelDescriptorRow: View {
    let name: String
    let detail: String
    let symbol: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(
            action: action
        ) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .frame(width: 22)

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(name)
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selected {
                    Image(
                        systemName: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
