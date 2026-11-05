import Foundation

// Stub owned by backend (sprint 10); replaced with the real implementation per the contract.
nonisolated struct SharedDraft: Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var price: Decimal
    var reason: String
    var link: URL?
    var createdAt: Date
}
