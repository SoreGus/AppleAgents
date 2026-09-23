import AppleAgentKit
import SwiftUI

#if os(iOS)
import UIKit

nonisolated private final class BackgroundCompletionHandlerBox: @unchecked Sendable {
    let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }
}

final class AppleAgentsAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        let box = BackgroundCompletionHandlerBox(completionHandler)
        _ = HuggingFaceModelProvider.handleEvents(
            forBackgroundURLSession: identifier,
            completionHandler: { box.handler() }
        )
    }
}
#endif

@main
struct AppleAgentsApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppleAgentsAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
