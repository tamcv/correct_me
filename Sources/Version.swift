import Foundation

enum AppVersion {
    static let current = "0.5.3"

    // Build timestamp - updated during compilation
    static let buildDate: String = {
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
