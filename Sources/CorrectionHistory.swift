import Foundation

// MARK: - Correction Entry

struct CorrectionEntry {
    let id: UUID
    let timestamp: Date
    let originalText: String
    let correctedText: String

    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
}

// MARK: - Correction History Singleton

class CorrectionHistory {
    static let shared = CorrectionHistory()

    private var entries: [CorrectionEntry] = []
    private let maxEntries = 10
    private let queue = DispatchQueue(label: "com.correctme.history")

    private init() {}

    /// Record a new correction. Trims history to `maxEntries`.
    func record(original: String, corrected: String) {
        queue.async {
            let entry = CorrectionEntry(
                id: UUID(),
                timestamp: Date(),
                originalText: original,
                correctedText: corrected
            )
            self.entries.insert(entry, at: 0)
            if self.entries.count > self.maxEntries {
                self.entries = Array(self.entries.prefix(self.maxEntries))
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .correctionHistoryUpdated, object: nil)
            }
        }
    }

    func getEntries() -> [CorrectionEntry] {
        return queue.sync { entries }
    }

    func clear() {
        queue.async {
            self.entries.removeAll()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .correctionHistoryUpdated, object: nil)
            }
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let correctionHistoryUpdated = Notification.Name("correctionHistoryUpdated")
}
