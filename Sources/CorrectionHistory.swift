import Foundation

// MARK: - Correction Entry

struct CorrectionEntry: Codable {
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
    private let maxEntries = 50
    private let queue = DispatchQueue(label: "com.correctme.history")

    static var historyFilePath: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".correctme/history.json")
    }

    private init() {
        loadFromDisk()
    }

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
            self.saveToDisk()
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
            self.saveToDisk()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .correctionHistoryUpdated, object: nil)
            }
        }
    }

    // MARK: - Persistence

    /// Must be called on `queue`.
    private func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(entries) else { return }
        let dir = Self.historyFilePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: Self.historyFilePath, options: .atomic)
    }

    private func loadFromDisk() {
        queue.sync {
            guard FileManager.default.fileExists(atPath: Self.historyFilePath.path),
                  let data = try? Data(contentsOf: Self.historyFilePath) else { return }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let loaded = try? decoder.decode([CorrectionEntry].self, from: data) {
                entries = Array(loaded.prefix(maxEntries))
            }
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let correctionHistoryUpdated = Notification.Name("correctionHistoryUpdated")
}
