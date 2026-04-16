import Foundation

enum AppVersion {
    static let current = "0.3.4"

    // Build timestamp - updated during compilation
    static let buildDate: String = {
        // This will be replaced by build script, or use compile date as fallback
        #if DEBUG
        return "Debug Build"
        #else
        return "Release Build"
        #endif
    }()

    static var fullVersion: String {
        return "v\(current) (\(buildDate))"
    }
}
