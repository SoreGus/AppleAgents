import SwiftUI

struct RemoteSettingsView: View {
    @Bindable var app: AppViewModel
    @State private var showsAPIKey = false
    @State private var confirmRemoval = false

    var body: some View {
        @Bindable var remote = app.remoteSettings

        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Provider", value: "OpenAI")

            TextField("Model ID", text: $remote.modelID)
                .textFieldStyle(.roundedBorder)

            HStack {
                Group {
                    if showsAPIKey {
                        TextField("API Key", text: $remote.apiKey)
                    } else {
                        SecureField("API Key", text: $remote.apiKey)
                    }
                }
                .textFieldStyle(.roundedBorder)

                Button {
                    showsAPIKey.toggle()
                } label: {
                    Image(systemName: showsAPIKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(showsAPIKey ? "Hide API key" : "Show API key")
            }

            if let message = remote.validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button(remote.isConfigured ? "Update API Key" : "Save API Key") {
                    app.saveRemoteSettings()
                }
                .buttonStyle(.borderedProminent)

                if remote.isConfigured {
                    Button("Remove API Key", role: .destructive) {
                        confirmRemoval = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Remove OpenAI configuration?",
            isPresented: $confirmRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                app.removeRemoteSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The API key will be removed from Keychain and OpenAI will no longer be selectable.")
        }
    }
}
