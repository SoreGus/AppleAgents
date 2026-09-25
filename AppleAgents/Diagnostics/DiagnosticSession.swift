//
//  DiagnosticSession.swift
//  AppleAgents
//
//  Created by Gustavo Soré on 25/09/26.
//


import Foundation

struct DiagnosticSession: Codable, Identifiable, Sendable {
    let id: UUID
    let startedAt: Date

    init(
        id: UUID = UUID(),
        startedAt: Date = Date()
    ) {
        self.id = id
        self.startedAt = startedAt
    }
}