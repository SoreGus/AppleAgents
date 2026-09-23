import Foundation

enum AppFormatters {
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    static func progress(received: Int64, total: Int64?) -> String {
        guard let total else {
            return bytes(received)
        }
        return "\(bytes(received)) of \(bytes(total))"
    }
}
