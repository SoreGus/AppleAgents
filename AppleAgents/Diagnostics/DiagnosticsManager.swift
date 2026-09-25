//
//  DiagnosticsManager.swift
//  AppleAgents
//
//  Created by Gustavo Soré on 25/09/26.
//


import Foundation
import Observation

@MainActor
@Observable
final class DiagnosticsManager {
    static let shared = DiagnosticsManager()

    private(set) var records: [DiagnosticRecord] = []
    private(set) var sessions: [DiagnosticSession] = []

    let currentSession: DiagnosticSession

    @ObservationIgnored
    private let fileManager: FileManager

    @ObservationIgnored
    private let encoder: JSONEncoder

    @ObservationIgnored
    private let decoder: JSONDecoder

    @ObservationIgnored
    private let storageURL: URL

    private init(
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.currentSession = DiagnosticSession()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let applicationSupportURL =
            fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!

        let diagnosticsDirectoryURL =
            applicationSupportURL
                .appending(path: "Diagnostics", directoryHint: .isDirectory)

        self.storageURL =
            diagnosticsDirectoryURL
                .appending(path: "diagnostics.json")

        load()

        sessions.append(currentSession)
        persist()

        record(
            category: "app",
            event: "session.started",
            message: "Diagnostic session started"
        )
    }

    // MARK: - Recording

    func record(
        category: String,
        event: String,
        level: DiagnosticLevel = .info,
        message: String? = nil,
        metadata: [String: String] = [:]
    ) {
        let record = DiagnosticRecord(
            sessionID: currentSession.id,
            level: level,
            category: category,
            event: event,
            message: message,
            metadata: metadata
        )

        records.append(record)
        persist()
    }

    func record(
        error: Error,
        category: String,
        event: String,
        message: String? = nil,
        metadata: [String: String] = [:]
    ) {
        let nsError = error as NSError

        var errorMetadata = metadata

        errorMetadata["error.domain"] = nsError.domain
        errorMetadata["error.code"] = String(nsError.code)
        errorMetadata["error.description"] = nsError.localizedDescription

        if !nsError.userInfo.isEmpty {
            errorMetadata["error.userInfo"] =
                String(describing: nsError.userInfo)
        }

        record(
            category: category,
            event: event,
            level: .error,
            message: message ?? nsError.localizedDescription,
            metadata: errorMetadata
        )
    }

    // MARK: - Queries

    var currentSessionRecords: [DiagnosticRecord] {
        records.filter {
            $0.sessionID == currentSession.id
        }
    }

    func records(
        for session: DiagnosticSession
    ) -> [DiagnosticRecord] {
        records.filter {
            $0.sessionID == session.id
        }
    }

    // MARK: - Management

    func clear() {
        records.removeAll()
        sessions.removeAll()

        sessions.append(currentSession)

        persist()

        record(
            category: "diagnostics",
            event: "records.cleared",
            message: "Diagnostic records were cleared"
        )
    }

    func reload() {
        load()
    }

    // MARK: - Export

    func prepareExport() throws -> URL {
        let export = DiagnosticExport(
            exportedAt: Date(),
            application: applicationInformation(),
            environment: environmentInformation(),
            sessions: sessions,
            records: records
        )

        let data = try encoder.encode(export)

        let fileName =
            "AppleAgents-Diagnostics-\(exportFileTimestamp()).json"

        let url =
            fileManager.temporaryDirectory
                .appending(path: fileName)

        try data.write(
            to: url,
            options: .atomic
        )

        return url
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let directoryURL =
                storageURL.deletingLastPathComponent()

            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let storage = Storage(
                sessions: sessions,
                records: records
            )

            let data = try encoder.encode(storage)

            try data.write(
                to: storageURL,
                options: .atomic
            )
        } catch {
            print(
                "Diagnostics persistence failed:",
                error.localizedDescription
            )
        }
    }

    private func load() {
        guard fileManager.fileExists(
            atPath: storageURL.path
        ) else {
            return
        }

        do {
            let data = try Data(
                contentsOf: storageURL
            )

            let storage = try decoder.decode(
                Storage.self,
                from: data
            )

            sessions = storage.sessions
            records = storage.records
        } catch {
            print(
                "Diagnostics loading failed:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Information

    private func applicationInformation()
        -> DiagnosticExport.Application {
        let bundle = Bundle.main

        return DiagnosticExport.Application(
            name:
                bundle.object(
                    forInfoDictionaryKey: "CFBundleName"
                ) as? String ?? "Unknown",

            version:
                bundle.object(
                    forInfoDictionaryKey:
                        "CFBundleShortVersionString"
                ) as? String ?? "Unknown",

            build:
                bundle.object(
                    forInfoDictionaryKey: "CFBundleVersion"
                ) as? String ?? "Unknown",

            bundleIdentifier:
                bundle.bundleIdentifier ?? "Unknown"
        )
    }

    private func environmentInformation()
        -> DiagnosticExport.Environment {
        let version = ProcessInfo.processInfo.operatingSystemVersion

        let versionString =
            "\(version.majorVersion)." +
            "\(version.minorVersion)." +
            "\(version.patchVersion)"

        #if os(iOS)
        let operatingSystem = "iOS"
        #elseif os(macOS)
        let operatingSystem = "macOS"
        #else
        let operatingSystem = "Unknown"
        #endif

        return DiagnosticExport.Environment(
            operatingSystem: operatingSystem,
            operatingSystemVersion: versionString
        )
    }

    private func exportFileTimestamp() -> String {
        let formatter = DateFormatter()

        formatter.locale =
            Locale(identifier: "en_US_POSIX")

        formatter.dateFormat =
            "yyyy-MM-dd-HHmmss"

        return formatter.string(
            from: Date()
        )
    }
}

// MARK: - Storage

private extension DiagnosticsManager {
    struct Storage: Codable {
        let sessions: [DiagnosticSession]
        let records: [DiagnosticRecord]
    }
}