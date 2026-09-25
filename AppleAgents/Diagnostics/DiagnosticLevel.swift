//
//  DiagnosticLevel.swift
//  AppleAgents
//
//  Created by Gustavo Soré on 25/09/26.
//

import Foundation

enum DiagnosticLevel: String, Codable, CaseIterable, Sendable {
    case debug
    case info
    case warning
    case error
}
