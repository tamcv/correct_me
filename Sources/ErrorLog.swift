import Foundation

// MARK: - Error Log Entry
struct ErrorEntry: Codable {
    let timestamp: Date
    let message: String
    let category: ErrorCategory

    enum ErrorCategory: String, Codable {
        case aiError = "AI Error"
        case networkError = "Network Error"
        case systemError = "System Error"
        case userError = "User Error"
    }

    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
}

// MARK: - Error Log Singleton
class ErrorLog {
    static let shared = ErrorLog()

    private var errors: [ErrorEntry] = []
    private let maxErrors = 10
    private let queue = DispatchQueue(label: "com.correctme.errorlog")

    private init() {}

    func log(_ message: String, category: ErrorEntry.ErrorCategory = .systemError) {
        queue.async {
            let entry = ErrorEntry(timestamp: Date(), message: message, category: category)
            self.errors.insert(entry, at: 0)

            // Keep only the last maxErrors
            if self.errors.count > self.maxErrors {
                self.errors = Array(self.errors.prefix(self.maxErrors))
            }

            // Notify observers
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .errorLogUpdated, object: nil)
            }
        }
    }

    func getErrors() -> [ErrorEntry] {
        return queue.sync {
            return errors
        }
    }

    func clearErrors() {
        queue.async {
            self.errors.removeAll()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .errorLogUpdated, object: nil)
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let errorLogUpdated = Notification.Name("errorLogUpdated")
    static let statusChanged = Notification.Name("statusChanged")
}

// MARK: - App Status
enum AppStatus: String {
    case idle = "Ready"
    case processing = "Processing..."
    case success = "Success"
    case error = "Error"

    var icon: String {
        switch self {
        case .idle: return "✓"
        case .processing: return "⏳"
        case .success: return "✅"
        case .error: return "⚠️"
        }
    }
}

// MARK: - Status Manager
class StatusManager {
    static let shared = StatusManager()

    private(set) var currentStatus: AppStatus = .idle
    private(set) var lastCorrectionTime: Date?

    private init() {}

    func setStatus(_ status: AppStatus) {
        currentStatus = status

        if status == .success {
            lastCorrectionTime = Date()
        }

        NotificationCenter.default.post(name: .statusChanged, object: status)

        // Auto-reset success status after 2 seconds
        if status == .success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                if self?.currentStatus == .success {
                    self?.setStatus(.idle)
                }
            }
        }
    }

    var lastCorrectionTimeAgo: String? {
        guard let time = lastCorrectionTime else { return nil }
        let interval = Date().timeIntervalSince(time)
        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "Long time ago"
        }
    }
}
