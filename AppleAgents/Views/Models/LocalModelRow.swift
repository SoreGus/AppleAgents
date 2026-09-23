import AppleAgentKit
import SwiftUI

struct LocalModelRow: View {
    @Bindable var app: AppViewModel
    let entry: LocalModelCatalogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.displayName)
                        .font(.headline)
                    Text(entry.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(AppFormatters.bytes(entry.expectedDownloadSize)) · \(entry.baseModel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusLabel
            }

            Text(entry.compatibilityDescription)
                .font(.caption)
                .foregroundStyle(entry.isSupportedOnCurrentDevice ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))

            stateContent
        }
        .padding(.vertical, 6)
    }

    private var state: LocalModelInstallationState {
        app.localModels.state(for: entry)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch state {
        case .notInstalled:
            Label("Not Installed", systemImage: "arrow.down.circle")
                .foregroundStyle(.secondary)
        case .downloading:
            Label("Downloading", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(.secondary)
        case .installed:
            Label("Installed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .updateAvailable:
            Label("Update", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                .foregroundStyle(.orange)
        case .invalid:
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch state {
        case .notInstalled:
            HStack {
                Button("Download") {
                    app.install(entry)
                }
                .disabled(!entry.isSupportedOnCurrentDevice)
                Spacer()
            }

        case .downloading(let progress):
            DownloadProgressView(progress: progress)
            HStack {
                Button("Cancel", role: .destructive) {
                    Task { await app.cancel(entry) }
                }
                Spacer()
            }

        case .installed(let installation):
            installationActions(revision: installation.resolvedRevision)

        case .updateAvailable(let installation, let availableRevision):
            VStack(alignment: .leading, spacing: 8) {
                Text("Installed: \(shortRevision(installation.resolvedRevision)) · Available: \(shortRevision(availableRevision))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Update") {
                        app.install(entry)
                    }
                    Button("Remove", role: .destructive) {
                        Task { await app.remove(entry) }
                    }
                    Spacer()
                    selectButton
                }
            }

        case .invalid(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                HStack {
                    Button("Retry") {
                        app.install(entry)
                    }
                    .disabled(!entry.isSupportedOnCurrentDevice)
                    Button("Remove", role: .destructive) {
                        Task { await app.remove(entry) }
                    }
                    Spacer()
                }
            }
        }
    }

    private func installationActions(revision: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Revision \(shortRevision(revision))")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Remove", role: .destructive) {
                    Task { await app.remove(entry) }
                }
                Spacer()
                selectButton
            }
        }
    }

    private var selectButton: some View {
        Button(app.selectedModel == .local(entry.id) ? "Selected" : "Select") {
            app.select(.local(entry.id))
        }
        .buttonStyle(.borderedProminent)
        .disabled(app.selectedModel == .local(entry.id))
    }

    private func shortRevision(_ value: String) -> String {
        value.count > 10 ? String(value.prefix(10)) : value
    }
}
