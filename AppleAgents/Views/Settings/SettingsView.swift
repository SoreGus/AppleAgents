import SwiftUI

struct SettingsView: View {
    @Bindable var app: AppViewModel

    var body: some View {
        Form {
            Section("Model Provider") {
                ModelPickerView(
                    title: "Current Model",
                    models: app.selectableModels,
                    selectedModel: app.selectedModel,
                    select: app.select
                )
            }

            Section("Remote") {
                RemoteSettingsView(app: app)
            }

            if !app.nativeModels.isEmpty {
                Section("Apple Native") {
                    ForEach(app.nativeModels) { model in
                        LabeledContent(model.name, value: model.detail)
                    }
                }
            }

            Section("Local Models") {
                if app.localModels.catalog.isEmpty {
                    Text("No models in the bundled catalog.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(app.localModels.catalog) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayName)
                                Text(entry.compatibilityDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if app.localModels.isInstalled(entry.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    Button("Manage Local Models") {
                        app.destination = .models
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
