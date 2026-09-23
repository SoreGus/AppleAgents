import AppleAgentKit
import Foundation

#if os(iOS)
import UIKit
#endif

struct LocalModelCatalogEntry: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let description: String
    let repositoryID: String
    let revision: String
    let verifiedRevision: String
    let matchingFiles: [String]
    let expectedDownloadSize: Int64
    let resourcePath: String
    let runtime: String
    let supportedPlatforms: [String]
    let minimumOSVersion: String
    let supportedArchitectures: [String]
    let baseModel: String
    let license: String

    var huggingFaceModel: HuggingFaceModel {
        HuggingFaceModel(
            id: id,
            displayName: displayName,
            repositoryID: repositoryID,
            revision: revision,
            matchingFiles: matchingFiles,
            expectedDownloadSize: expectedDownloadSize,
            compatibility: .coreAI
        )
    }

    var isSupportedOnCurrentDevice: Bool {
        supportsCurrentPlatform && supportsCurrentArchitecture && supportsCurrentOS && runtime == "coreAI"
    }

    var compatibilityDescription: String {
        if isSupportedOnCurrentDevice {
            return "Compatible with this device"
        }

        let platformText = supportedPlatforms.joined(separator: ", ")
        let architectureText = supportedArchitectures.joined(separator: ", ")
        return "Requires \(platformText) \(minimumOSVersion)+ · \(architectureText)"
    }

    private var supportsCurrentPlatform: Bool {
        #if os(macOS)
        supportedPlatforms.contains("macOS")
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            supportedPlatforms.contains("iPadOS") || supportedPlatforms.contains("iOS")
        } else {
            supportedPlatforms.contains("iOS")
        }
        #else
        false
        #endif
    }

    private var supportsCurrentArchitecture: Bool {
        #if arch(arm64)
        supportedArchitectures.contains("arm64")
        #elseif arch(x86_64)
        supportedArchitectures.contains("x86_64")
        #else
        false
        #endif
    }

    private var supportsCurrentOS: Bool {
        guard let required = Self.operatingSystemVersion(from: minimumOSVersion) else {
            return true
        }
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(required)
    }

    private static func operatingSystemVersion(from value: String) -> OperatingSystemVersion? {
        let components = value.split(separator: ".").compactMap { Int($0) }
        guard let major = components.first else { return nil }
        return OperatingSystemVersion(
            majorVersion: major,
            minorVersion: components.count > 1 ? components[1] : 0,
            patchVersion: components.count > 2 ? components[2] : 0
        )
    }
}
