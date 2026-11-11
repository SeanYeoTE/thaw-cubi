import Foundation

enum WantRowTone: Equatable {
    case neutral, accent, timer
}

/// Plain values for one want row, shared by Cooling and Saved.
struct WantRowModel: Equatable {
    let title: String
    let priceText: String
    /// nil draws the lean single-line row: symbol · title, then price · trailing.
    let status: String?
    let statusTone: WantRowTone
    let trailing: String?
    /// 0...1 draws a thin strip along the bottom edge of the card; nil draws none.
    let progress: Double?
    let progressTone: WantRowTone
    let accessibilityLabel: String
    let accessibilityValue: String
    /// Small SF Symbol before the title (`timer`, `calendar`, `checkmark.circle`), tinted by `statusTone`.
    let leadingSymbol: String?

    init(
        title: String, priceText: String, status: String?, statusTone: WantRowTone, trailing: String?,
        progress: Double?, progressTone: WantRowTone, accessibilityLabel: String, accessibilityValue: String,
        leadingSymbol: String? = nil
    ) {
        self.title = title
        self.priceText = priceText
        self.status = status
        self.statusTone = statusTone
        self.trailing = trailing
        self.progress = progress
        self.progressTone = progressTone
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
        self.leadingSymbol = leadingSymbol
    }

    /// Lean row with no status line.
    init(
        title: String, priceText: String, leadingSymbol: String? = nil, tone: WantRowTone = .neutral,
        trailing: String? = nil, progress: Double? = nil, progressTone: WantRowTone = .accent,
        accessibilityLabel: String, accessibilityValue: String
    ) {
        self.init(
            title: title, priceText: priceText, status: nil, statusTone: tone, trailing: trailing,
            progress: progress, progressTone: progressTone,
            accessibilityLabel: accessibilityLabel, accessibilityValue: accessibilityValue,
            leadingSymbol: leadingSymbol)
    }
}
