//
//  DiagnosticRecord.swift
//  AppleAgents
//
//  Created by Gustavo Soré on 25/09/26.
//


import Foundation

struct DiagnosticRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let sessionID: UUID

    let level: DiagnosticLevel
    let category: String
    let event: String
    let message: String?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionID: UUID,
        level: DiagnosticLevel = .info,
        category: String,
        event: String,
        message: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.level = level
        self.category = category
        self.event = event
        self.message = message
        self.metadata = metadata
    }
}
