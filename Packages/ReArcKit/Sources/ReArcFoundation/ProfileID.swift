import Foundation

/// Identifies a browsing profile: its own cookies, storage and logins.
/// Each Space will point at one profile.
public struct ProfileID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    public static let `default` = ProfileID(rawValue: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
}
