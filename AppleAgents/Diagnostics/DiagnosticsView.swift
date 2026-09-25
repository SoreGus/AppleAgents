//
//  DiagnosticsView.swift
//  AppleAgents
//
//  Created by Gustavo Soré on 25/09/26.
//


#if DEBUG

import SwiftUI

struct DiagnosticsView: View {
    @State private var diagnostics =
        DiagnosticsManager.shared

    @State private var exportURL: URL?

    @State private var presentedError: String?

    var body: some View {
        List {
            Section {
                LabeledContent(
                    "Session",
                    value: diagnostics.currentSession.id
                        .uuidString
                )

                LabeledContent(
                    "Records",
                    value: "\(diagnostics.records.count)"
                )
            } header: {
                Text("Current Run")
            }

            Section {
                if diagnostics.records.isEmpty {
                    ContentUnavailableView(
                        "No Diagnostics",
                        systemImage: "waveform.path.ecg",
                        description: Text(
                            "Diagnostic events will appear here."
                        )
                    )
                } else {
                    ForEach(
                        diagnostics.records.reversed()
                    ) { record in
                        NavigationLink {
                            DiagnosticRecordView(
                                record: record
                            )
                        } label: {
                            DiagnosticRecordRow(
                                record: record
                            )
                        }
                    }
                }
            } header: {
                Text("Records")
            }
        }
        .navigationTitle("Diagnostics")
        .toolbar {
            ToolbarItemGroup(
                placement: .primaryAction
            ) {
                Button {
                    diagnostics.reload()
                } label: {
                    Label(
                        "Refresh",
                        systemImage: "arrow.clockwise"
                    )
                }

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label(
                            "Share",
                            systemImage: "square.and.arrow.up"
                        )
                    }
                } else {
                    Button {
                        prepareExport()
                    } label: {
                        Label(
                            "Export",
                            systemImage: "square.and.arrow.up"
                        )
                    }
                }

                Button(
                    role: .destructive
                ) {
                    diagnostics.clear()
                    exportURL = nil
                } label: {
                    Label(
                        "Clear",
                        systemImage: "trash"
                    )
                }
            }
        }
        .alert(
            "Diagnostics Error",
            isPresented: Binding(
                get: {
                    presentedError != nil
                },
                set: { isPresented in
                    if !isPresented {
                        presentedError = nil
                    }
                }
            )
        ) {
            Button("OK") {
                presentedError = nil
            }
        } message: {
            Text(presentedError ?? "")
        }
    }

    private func prepareExport() {
        do {
            exportURL =
                try diagnostics.prepareExport()
        } catch {
            presentedError =
                error.localizedDescription
        }
    }
}

// MARK: - Record Row

private struct DiagnosticRecordRow: View {
    let record: DiagnosticRecord

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            HStack {
                Image(
                    systemName: levelSymbol
                )

                Text(record.event)
                    .font(.headline)

                Spacer()

                Text(
                    record.timestamp,
                    format: .dateTime
                        .hour()
                        .minute()
                        .second()
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack {
                Text(record.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let message = record.message {
                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var levelSymbol: String {
        switch record.level {
        case .debug:
            "ladybug"

        case .info:
            "info.circle"

        case .warning:
            "exclamationmark.triangle"

        case .error:
            "xmark.circle"
        }
    }
}

// MARK: - Record Details

private struct DiagnosticRecordView: View {
    let record: DiagnosticRecord

    var body: some View {
        List {
            Section("Event") {
                LabeledContent(
                    "Level",
                    value: record.level.rawValue
                )

                LabeledContent(
                    "Category",
                    value: record.category
                )

                LabeledContent(
                    "Event",
                    value: record.event
                )

                LabeledContent(
                    "Time",
                    value: record.timestamp.formatted(
                        date: .abbreviated,
                        time: .standard
                    )
                )
            }

            if let message = record.message {
                Section("Message") {
                    Text(message)
                        .textSelection(.enabled)
                }
            }

            if !record.metadata.isEmpty {
                Section("Metadata") {
                    ForEach(
                        record.metadata.keys.sorted(),
                        id: \.self
                    ) { key in
                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {
                            Text(key)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(
                                record.metadata[key] ?? ""
                            )
                            .textSelection(.enabled)
                        }
                    }
                }
            }

            Section("Identity") {
                LabeledContent(
                    "Record ID",
                    value: record.id.uuidString
                )

                LabeledContent(
                    "Session ID",
                    value: record.sessionID.uuidString
                )
            }
        }
        .navigationTitle("Diagnostic")
    }
}

#endif