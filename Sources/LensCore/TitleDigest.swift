import CryptoKit
import Foundation

/// Stands in for window titles in remembered layouts.
///
/// Matching only ever asks "is this the same title?", so Lens never needs the titles
/// themselves, and they shouldn't sit in a preferences file that any process of the user can
/// read: titles carry document names, email subjects and page titles. A keyed hash (HMAC-SHA256)
/// answers the same question. The key is random per Mac, so a digest can't be looked up in a
/// table of common titles computed elsewhere.
public struct TitleDigest: Sendable {
    private let key: SymmetricKey

    public init(key: Data) {
        self.key = SymmetricKey(data: key)
    }

    /// A fresh random key.
    public static func makeKey() -> Data {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }

    /// The digest of `title`. Empty stays empty: matching treats untitled windows specially.
    public func digest(_ title: String) -> String {
        guard !title.isEmpty, !Self.isDigest(title) else { return title }
        let mac = HMAC<SHA256>.authenticationCode(for: Data(title.utf8), using: key)
        return Self.prefix + mac.map { String(format: "%02x", $0) }.joined()
    }

    private static let prefix = "h1:"

    /// Whether `text` is already a digest (from this version's format), not a raw title.
    public static func isDigest(_ text: String) -> Bool {
        text.hasPrefix(prefix) && text.count == prefix.count + 64
            && text.dropFirst(prefix.count).allSatisfy(\.isHexDigit)
    }
}

extension CGRect {
    /// A frame worth acting on: finite, non-negative size, and within a few million points.
    /// Other apps report their windows' geometry, and a NaN or astronomically large value would
    /// trap integer conversions or poison saved layouts.
    public var isReasonable: Bool {
        let values = [origin.x, origin.y, size.width, size.height]
        return values.allSatisfy { $0.isFinite && abs($0) < 1_000_000 } && size.width >= 0 && size.height >= 0
    }
}
