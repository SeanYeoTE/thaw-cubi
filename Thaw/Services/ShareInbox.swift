import Foundation
import os

/// A want captured in the share extension, waiting to be ingested by the app.
nonisolated struct SharedDraft: Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var price: Decimal
    var reason: String
    var link: URL?
    var createdAt: Date
}

/// Hand-off queue between the share extension and the app: one `inbox.json` in the app-group container,
/// read and written through `NSFileCoordinator` because both processes may touch it.
nonisolated final class ShareInbox: @unchecked Sendable {
    static let appGroupID = "group.com.tinkercademy.thaw"
    static let fileName = "inbox.json"

    private static let logger = Logger(subsystem: "app.thaw", category: "ShareInbox")

    static var shared: ShareInbox {
        ShareInbox(directory: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID))
    }

    /// nil when there is no app-group container; every operation is then a no-op.
    let fileURL: URL?

    init(directory: URL?) {
        fileURL = directory?.appendingPathComponent(Self.fileName)
    }

    func append(_ draft: SharedDraft) throws {
        try mutate { drafts in
            if !drafts.contains(where: { $0.id == draft.id }) { drafts.append(draft) }
        }
    }

    func pending() -> [SharedDraft] {
        guard let fileURL else { return [] }
        var result: [SharedDraft] = []
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
            result = Self.read(url)
        }
        if let coordinationError {
            Self.logger.error("Could not read inbox: \(coordinationError.localizedDescription, privacy: .public)")
        }
        return result
    }

    func remove(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        do {
            try mutate { drafts in drafts.removeAll { ids.contains($0.id) } }
        } catch {
            Self.logger.error("Could not update inbox: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func mutate(_ change: (inout [SharedDraft]) -> Void) throws {
        guard let fileURL else { return }
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: [], error: &coordinationError) { url in
            var drafts = Self.read(url)
            change(&drafts)
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try JSONEncoder().encode(drafts).write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
    }

    private static func read(_ url: URL) -> [SharedDraft] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode([SharedDraft].self, from: data)
        } catch {
            logger.error("Could not decode inbox: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
