import Foundation
import CryptoKit

// MARK: - License Key Format
//
// A CorrectMe license key is an HMAC-SHA256 derived token that encodes the
// purchaser's email address. This allows offline validation with no server
// round-trip after the first activation.
//
// Format:  XXXXX-XXXXX-XXXXX-XXXXX  (20 uppercase alphanumeric chars in 4×5 groups)
// Algorithm:
//   1. Compute HMAC-SHA256(LICENSE_SECRET, email.lowercased() + "|correctme")
//   2. Take the first 10 bytes of the MAC
//   3. Base32-encode those 10 bytes → 16 chars
//   4. Group as XXXX-XXXX-XXXX-XXXX
//
// The secret is embedded in the binary — security through obscurity is
// acceptable for a solo indie app at this price point. For higher assurance
// use online validation (see license-server/api/validate.js).
//
// ⚠️  IMPORTANT: Change LICENSE_SECRET before shipping. Generate a random
//     32-byte hex string and keep it in sync with the backend.
private let LICENSE_SECRET = "CHANGE_ME_BEFORE_SHIPPING_32BYTE_SECRET_KEY_HERE"

// MARK: - LicenseInfo

enum LicenseError: Error, LocalizedError {
    case invalidEmail
    case emptyKey
    case invalidKey

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return "Please enter a valid email address."
        case .emptyKey:     return "Please enter your license key."
        case .invalidKey:   return "Invalid license key. Check that the email matches your purchase."
        }
    }
}

struct LicenseInfo: Codable {
    let email: String
    let licenseKey: String
    let activatedAt: Date
}

// MARK: - LicenseManager

final class LicenseManager {
    static let shared = LicenseManager()

    private let keychainAccount = "correctme_license"

    private var _cachedInfo: LicenseInfo?

    private init() {}

    // MARK: - Public API

    /// Whether the app is activated with a valid license.
    var isActivated: Bool { licenseInfo != nil }

    /// The current license info (email + key), nil if not activated.
    var licenseInfo: LicenseInfo? {
        if let cached = _cachedInfo { return cached }
        guard let jsonString = KeychainHelper.load(account: keychainAccount),
              let data = jsonString.data(using: .utf8),
              let info = try? JSONDecoder().decode(LicenseInfo.self, from: data) else {
            return nil
        }
        _cachedInfo = info
        return info
    }

    /// Validate and store a license key for the given email.
    /// Returns `.success` if the key is valid, `.failure` with a user-facing message otherwise.
    @discardableResult
    func activate(email: String, licenseKey: String) -> Result<LicenseInfo, LicenseError> {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard !normalizedEmail.isEmpty, normalizedEmail.contains("@") else {
            return .failure(.invalidEmail)
        }
        guard !normalizedKey.isEmpty else {
            return .failure(.emptyKey)
        }
        guard validateKey(normalizedKey, forEmail: normalizedEmail) else {
            return .failure(.invalidKey)
        }

        let info = LicenseInfo(
            email: normalizedEmail,
            licenseKey: formatKey(normalizedKey),
            activatedAt: Date()
        )

        if let data = try? JSONEncoder().encode(info),
           let jsonString = String(data: data, encoding: .utf8) {
            KeychainHelper.save(account: keychainAccount, value: jsonString)
        }
        _cachedInfo = info
        return .success(info)
    }

    /// Remove the stored license (deactivate).
    func deactivate() {
        KeychainHelper.delete(account: keychainAccount)
        _cachedInfo = nil
    }

    // MARK: - Key Generation (used by backend — kept here for parity)

    /// Generate a license key for a given email. This is the same algorithm
    /// used by the Node.js backend. Keep in sync with license-server/lib/license.js.
    static func generateKey(forEmail email: String) -> String {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let raw = computeMAC(normalized)
        return formatKey(raw)
    }

    // MARK: - Private

    private func validateKey(_ strippedKey: String, forEmail email: String) -> Bool {
        let expected = Self.computeMAC(email)
        let expectedStripped = Self.formatKey(expected).replacingOccurrences(of: "-", with: "")
        return strippedKey == expectedStripped
    }

    private static func computeMAC(_ email: String) -> String {
        guard let secretData = LICENSE_SECRET.data(using: .utf8),
              let msgData = (email + "|correctme").data(using: .utf8) else {
            return ""
        }
        let key = SymmetricKey(data: secretData)
        let mac = HMAC<SHA256>.authenticationCode(for: msgData, using: key)
        let bytes = Array(mac.prefix(10))
        return base32Encode(bytes)
    }

    private static func formatKey(_ raw: String) -> String {
        // Group into XXXX-XXXX-XXXX-XXXX from a 16-char base32 string
        let clean = raw.replacingOccurrences(of: "-", with: "")
        guard clean.count >= 16 else { return clean }
        let s = String(clean.prefix(16))
        return stride(from: 0, to: s.count, by: 4).map { i -> String in
            let start = s.index(s.startIndex, offsetBy: i)
            let end = s.index(start, offsetBy: min(4, s.count - i))
            return String(s[start..<end])
        }.joined(separator: "-")
    }

    private func formatKey(_ raw: String) -> String { Self.formatKey(raw) }

    // MARK: - Base32 (RFC 4648, no padding)

    private static let base32Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    private static func base32Encode(_ bytes: [UInt8]) -> String {
        var result = ""
        var buffer: UInt64 = 0
        var bitsLeft = 0

        for byte in bytes {
            buffer = (buffer << 8) | UInt64(byte)
            bitsLeft += 8
            while bitsLeft >= 5 {
                bitsLeft -= 5
                let index = Int((buffer >> bitsLeft) & 0x1F)
                result.append(base32Alphabet[index])
            }
        }

        if bitsLeft > 0 {
            let index = Int((buffer << (5 - bitsLeft)) & 0x1F)
            result.append(base32Alphabet[index])
        }

        return result
    }
}

