//
//  LocalCoreAIModelPreparationCoordinator.swift
//  AppleAgents
//
//  Created by Gustavo Soré on 25/09/26.
//

#if os(iOS)

import BackgroundTasks
import Foundation

@MainActor
final class LocalCoreAIModelPreparationCoordinator {
    static let shared = LocalCoreAIModelPreparationCoordinator()

    private let scheduler: BGTaskScheduler
    private let preparer: LocalCoreAIModelPreparer

    private var pendingResourcesURL: URL?
    private var preparationTask: Task<Void, Never>?

    private init(
        scheduler: BGTaskScheduler = .shared
    ) {
        self.scheduler = scheduler
        self.preparer = LocalCoreAIModelPreparer()
    }

    // MARK: - Registration

    func register() {
        let registered = scheduler.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGContinuedProcessingTask else {
                Task { @MainActor in
                    DiagnosticsManager.shared.record(
                        category: "background",
                        event: "handler.invalid-task",
                        level: .error,
                        message: "Received an unexpected background task type.",
                        metadata: [
                            "identifier": Self.taskIdentifier,
                            "taskType": String(describing: type(of: task))
                        ]
                    )
                }

                task.setTaskCompleted(success: false)
                return
            }

            Task { @MainActor in
                self.handle(task)
            }
        }

        DiagnosticsManager.shared.record(
            category: "background",
            event: registered
                ? "handler.registered"
                : "handler.registration-failed",
            level: registered ? .info : .error,
            message: registered
                ? "Background task handler registered."
                : "Background task handler could not be registered.",
            metadata: [
                "identifier": Self.taskIdentifier
            ]
        )
    }

    // MARK: - Preparation

    func isPrepared(resourcesAt resourcesURL: URL) throws -> Bool {
        try preparer.isPrepared(resourcesAt: resourcesURL)
    }

    func prepare(
        resourcesAt resourcesURL: URL,
        modelName: String
    ) async throws {
        DiagnosticsManager.shared.record(
            category: "background",
            event: "preparation.requested",
            message: "Local model preparation requested.",
            metadata: [
                "modelName": modelName,
                "resourcesPath": resourcesURL.path,
                "identifier": Self.taskIdentifier
            ]
        )

        if try preparer.isPrepared(resourcesAt: resourcesURL) {
            DiagnosticsManager.shared.record(
                category: "coreai",
                event: "preparation.already-prepared",
                message: "The local model is already prepared.",
                metadata: [
                    "modelName": modelName,
                    "resourcesPath": resourcesURL.path
                ]
            )

            return
        }

        pendingResourcesURL = resourcesURL

        let request = BGContinuedProcessingTaskRequest(
            identifier: Self.taskIdentifier,
            title: "Preparing \(modelName)",
            subtitle: "Preparing the model for this device"
        )

        request.strategy = .fail

        DiagnosticsManager.shared.record(
            category: "background",
            event: "request.submitting",
            message: "Submitting continued processing task.",
            metadata: [
                "identifier": Self.taskIdentifier,
                "modelName": modelName
            ]
        )

        do {
            try await scheduler.submitTaskRequest(request)

            DiagnosticsManager.shared.record(
                category: "background",
                event: "request.submitted",
                message: "Continued processing task submitted.",
                metadata: [
                    "identifier": Self.taskIdentifier,
                    "modelName": modelName
                ]
            )
        } catch {
            pendingResourcesURL = nil

            DiagnosticsManager.shared.record(
                error: error,
                category: "background",
                event: "request.submission-failed",
                message: "Continued processing task submission failed.",
                metadata: [
                    "identifier": Self.taskIdentifier,
                    "modelName": modelName
                ]
            )

            throw LocalCoreAIModelPreparationCoordinatorError
                .submissionFailed(error.localizedDescription)
        }

        do {
            try await waitUntilPrepared(
                resourcesAt: resourcesURL
            )

            DiagnosticsManager.shared.record(
                category: "background",
                event: "preparation.wait-completed",
                message: "Preparation wait completed.",
                metadata: [
                    "modelName": modelName
                ]
            )
        } catch {
            DiagnosticsManager.shared.record(
                error: error,
                category: "background",
                event: "preparation.wait-failed",
                message: "Preparation wait failed.",
                metadata: [
                    "modelName": modelName
                ]
            )

            throw error
        }
    }

    // MARK: - Background Task

    private func handle(
        _ backgroundTask: BGContinuedProcessingTask
    ) {
        DiagnosticsManager.shared.record(
            category: "background",
            event: "handler.started",
            message: "Continued processing task handler started.",
            metadata: [
                "identifier": Self.taskIdentifier
            ]
        )

        guard let resourcesURL = pendingResourcesURL else {
            DiagnosticsManager.shared.record(
                category: "background",
                event: "handler.missing-resources",
                level: .error,
                message: "The background task started without pending resources.",
                metadata: [
                    "identifier": Self.taskIdentifier
                ]
            )

            backgroundTask.setTaskCompleted(success: false)
            return
        }

        backgroundTask.progress.totalUnitCount = 1
        backgroundTask.progress.completedUnitCount = 0

        backgroundTask.updateTitle(
            "Preparing Local Model",
            subtitle: "Starting model preparation"
        )

        if preparationTask != nil {
            DiagnosticsManager.shared.record(
                category: "background",
                event: "previous-task.cancelled",
                level: .warning,
                message: "A previous preparation task was cancelled before starting a new one."
            )

            preparationTask?.cancel()
        }

        let work = Task { @MainActor [weak self] in
            guard let self else {
                DiagnosticsManager.shared.record(
                    category: "background",
                    event: "coordinator.unavailable",
                    level: .error,
                    message: "The preparation coordinator became unavailable."
                )

                backgroundTask.setTaskCompleted(success: false)
                return
            }

            do {
                backgroundTask.updateTitle(
                    "Preparing Local Model",
                    subtitle: "Specializing the model for this device"
                )

                DiagnosticsManager.shared.record(
                    category: "coreai",
                    event: "specialization.started",
                    message: "Core AI model specialization started.",
                    metadata: [
                        "resourcesPath": resourcesURL.path
                    ]
                )

                try await preparer.prepare(
                    resourcesAt: resourcesURL
                )

                DiagnosticsManager.shared.record(
                    category: "coreai",
                    event: "specialization.completed",
                    message: "Core AI model specialization completed.",
                    metadata: [
                        "resourcesPath": resourcesURL.path
                    ]
                )

                try Task.checkCancellation()

                backgroundTask.updateTitle(
                    "Preparing Local Model",
                    subtitle: "Validating prepared model"
                )

                DiagnosticsManager.shared.record(
                    category: "coreai",
                    event: "validation.started",
                    message: "Prepared model validation started."
                )

                guard try preparer.isPrepared(
                    resourcesAt: resourcesURL
                ) else {
                    DiagnosticsManager.shared.record(
                        category: "coreai",
                        event: "validation.failed",
                        level: .error,
                        message: "The specialized model was not found in the persistent cache."
                    )

                    throw LocalCoreAIModelPreparationCoordinatorError
                        .preparationFailed
                }

                DiagnosticsManager.shared.record(
                    category: "coreai",
                    event: "validation.completed",
                    message: "Prepared model validation completed."
                )

                backgroundTask.progress.completedUnitCount = 1

                backgroundTask.updateTitle(
                    "Model Ready",
                    subtitle: "The local model is ready to use"
                )

                pendingResourcesURL = nil
                preparationTask = nil

                DiagnosticsManager.shared.record(
                    category: "background",
                    event: "task.completed",
                    message: "Continued processing task completed successfully.",
                    metadata: [
                        "identifier": Self.taskIdentifier
                    ]
                )

                backgroundTask.setTaskCompleted(success: true)
            } catch is CancellationError {
                pendingResourcesURL = nil
                preparationTask = nil

                DiagnosticsManager.shared.record(
                    category: "background",
                    event: "task.cancelled",
                    level: .warning,
                    message: "Model preparation was cancelled.",
                    metadata: [
                        "identifier": Self.taskIdentifier
                    ]
                )

                backgroundTask.setTaskCompleted(success: false)
            } catch {
                pendingResourcesURL = nil
                preparationTask = nil

                DiagnosticsManager.shared.record(
                    error: error,
                    category: "background",
                    event: "task.failed",
                    message: "Model preparation failed.",
                    metadata: [
                        "identifier": Self.taskIdentifier,
                        "resourcesPath": resourcesURL.path
                    ]
                )

                backgroundTask.setTaskCompleted(success: false)
            }
        }

        preparationTask = work

        backgroundTask.expirationHandler = { [weak self] in
            Task { @MainActor in
                DiagnosticsManager.shared.record(
                    category: "background",
                    event: "task.expired",
                    level: .warning,
                    message: "The system expired the continued processing task.",
                    metadata: [
                        "identifier": Self.taskIdentifier
                    ]
                )

                self?.preparationTask?.cancel()
                self?.preparationTask = nil
            }
        }
    }

    // MARK: - Waiting

    private func waitUntilPrepared(
        resourcesAt resourcesURL: URL
    ) async throws {
        while true {
            try Task.checkCancellation()

            if try preparer.isPrepared(
                resourcesAt: resourcesURL
            ) {
                return
            }

            if pendingResourcesURL == nil {
                throw LocalCoreAIModelPreparationCoordinatorError
                    .preparationFailed
            }

            try await Task.sleep(
                for: .milliseconds(500)
            )
        }
    }

    // MARK: - Identifier

    static var taskIdentifier: String {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            preconditionFailure(
                "The application bundle identifier is unavailable."
            )
        }

        return "\(bundleIdentifier).coreai-preparation"
    }
}

enum LocalCoreAIModelPreparationCoordinatorError: LocalizedError {
    case submissionFailed(String)
    case preparationFailed

    var errorDescription: String? {
        switch self {
        case .submissionFailed(let message):
            "Unable to start background model preparation: \(message)"

        case .preparationFailed:
            "The local model could not be prepared for this device."
        }
    }
}

#endif
