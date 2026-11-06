import Foundation

enum WantRowTone: Equatable {
    case neutral, accent, timer
}

/// Plain values for one want row, shared by Cooling and Saved.
struct WantRowModel: Equatable {
    let title: String
    let priceText: String
    let status: String
    let statusTone: WantRowTone
    let trailing: String?
    /// 0...1 draws a thin strip along the bottom edge of the card; nil draws none.
    let progress: Double?
    let progressTone: WantRowTone
    let accessibilityLabel: String
    let accessibilityValue: String
}
