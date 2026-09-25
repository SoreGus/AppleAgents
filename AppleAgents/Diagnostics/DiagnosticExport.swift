//
//  DiagnosticExport.swift
//  AppleAgents
//
//  Created by Gustavo Soré on 25/09/26.
//


import Foundation

struct DiagnosticExport: Codable, Sendable {
    let exportedAt: Date
    let application: Application
    let environment: Environment
    let sessions: [DiagnosticSession]
    let records: [DiagnosticRecord]

    struct Application: Codable, Sendable {
        let name: String
        let version: String
        let build: String
        let bundleIdentifier: String
    }

    struct Environment: Codable, Sendable {
        let operatingSystem: String
        let operatingSystemVersion: String
    }
}