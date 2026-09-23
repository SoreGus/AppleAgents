import AppleAgentKit
import SwiftUI

struct DownloadProgressView: View {
    let progress: LocalModelDownloadProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(phaseTitle)
                    .font(.caption.weight(.medium))
                Spacer()
                if let fraction = progress.fractionCompleted {
                    Text(fraction, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                }
            }

            if let fraction = progress.fractionCompleted {
                ProgressView(value: fraction, total: 1)
            } else {
                ProgressView()
            }

            Text(AppFormatters.progress(received: progress.receivedBytes, total: progress.totalBytes))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var phaseTitle: String {
        switch progress.phase {
        case .preparing:
            "Preparing…"
        case .downloading:
            "Downloading…"
        case .installing:
            "Installing…"
        }
    }
}
