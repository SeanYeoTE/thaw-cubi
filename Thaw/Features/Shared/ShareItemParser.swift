import Foundation

/// Turns what the share sheet hands over (title, content text, URLs, plain text) into a want name and link.
/// Pure so it can be unit tested from the app's test target; the extension does the item-provider loading.
nonisolated enum ShareItemParser {
    struct Input: Equatable, Sendable {
        /// `NSExtensionItem.attributedTitle`.
        var title: String?
        /// `NSExtensionItem.attributedContentText` (Safari puts the page title here).
        var contentText: String?
        /// `public.url` attachments.
        var urls: [URL] = []
        /// `public.plain-text` attachments.
        var texts: [String] = []

        init(title: String? = nil, contentText: String? = nil, urls: [URL] = [], texts: [String] = []) {
            self.title = title
            self.contentText = contentText
            self.urls = urls
            self.texts = texts
        }
    }

    struct Result: Equatable, Sendable {
        var name: String
        var link: URL?
    }

    static let maxNameLength = 40

    static func parse(_ input: Input) -> Result {
        let candidates = [input.title, input.contentText].compactMap { $0 } + input.texts
        let link = input.urls.first(where: isWeb) ?? candidates.lazy.compactMap { webURLs(in: $0).first }.first
        let name = candidates.lazy.map(cleanName).first { !$0.isEmpty } ?? link.map(humanised) ?? ""
        return Result(name: name, link: link)
    }

    /// Host without a leading "www.", e.g. "example.com".
    static func displayHost(_ url: URL) -> String {
        guard let host = url.host(), !host.isEmpty else { return url.absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// A readable name from a URL: the last meaningful path segment ("noise-cancelling-headphones" ->
    /// "Noise cancelling headphones"), else the host.
    static func humanised(_ url: URL) -> String {
        let segment = url.pathComponents.reversed().lazy
            .map { ($0 as NSString).deletingPathExtension }
            .map { $0.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ") }
            .map(collapseWhitespace)
            .first { segment in segment != "/" && segment.contains(where: \.isLetter) }
        guard let segment else { return displayHost(url) }
        return truncated(segment.prefix(1).uppercased() + segment.dropFirst())
    }

    private static func isWeb(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return false }
        return url.host() != nil
    }

    private static func webURLs(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap(\.url).filter(isWeb)
    }

    /// Removes any URLs from `text`, collapses whitespace and caps the length.
    private static func cleanName(_ text: String) -> String {
        var stripped = text
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range).reversed() {
                if let swiftRange = Range(match.range, in: stripped) { stripped.replaceSubrange(swiftRange, with: " ") }
            }
        }
        return truncated(collapseWhitespace(stripped))
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Shortens a title: drops marketing suffixes after " - ", " | " or ": ", then cuts at a word boundary.
    private static func truncated(_ text: String) -> String {
        var result = text
        for separator in [" | ", " - ", " – ", " — ", ": ", ", "] {
            if let range = result.range(of: separator), result[..<range.lowerBound].count >= 3 {
                result = String(result[..<range.lowerBound])
            }
        }
        guard result.count > maxNameLength else { return result }
        let hardCut = String(result.prefix(maxNameLength - 1))
        let wordCut = hardCut.lastIndex(of: " ").map { String(hardCut[..<$0]) }
        let base = (wordCut?.count ?? 0) >= maxNameLength / 2 ? wordCut! : hardCut
        return base.trimmingCharacters(in: .whitespaces) + "…"
    }
}
