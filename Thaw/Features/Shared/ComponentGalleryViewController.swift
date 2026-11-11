#if DEBUG
import UIKit

/// DEBUG-only screen for checking shared components; not linked from the tabs. `page` splits it into
/// screen-sized parts: 0 filter chips; 1 want rows; 2 empty state; 3 section headers and stat chips.
final class ComponentGalleryViewController: ScrollStackViewController {
    private let page: Int

    init(page: Int = 0) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
        title = "Gallery"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        switch page {
        case 1: buildRows()
        case 2: buildEmptyState()
        case 3: buildHeadersAndStats()
        default: buildControls()
        }
    }

    private func buildControls() {
        stack.addArrangedSubview(SectionHeaderView(title: "Filter chips"))
        stack.addArrangedSubview(FilterChipBar(titles: ["All", "Payday", "Quick thaw"], selectedIndex: 0))
        stack.addArrangedSubview(FilterChipBar(titles: ["All", "Let go", "Bought"], selectedIndex: 1))
        stack.addArrangedSubview(FilterChipBar(
            titles: ["Newest", "Oldest", "Price high", "Price low", "Name"], selectedIndex: 4))
    }

    private func buildHeadersAndStats() {
        stack.addArrangedSubview(SectionHeaderView(title: "This payday", detail: "S$320"))
        stack.addArrangedSubview(SectionHeaderView(title: "November", detail: "S$120 saved"))
        stack.addArrangedSubview(SectionHeaderView(title: "Later"))

        let streak = StatChipView(symbol: "flame.fill", value: "3", caption: "streak", spoken: "3 payday streak")
        streak.addAction(UIAction { _ in }, for: .touchUpInside)
        let rate = StatChipView(symbol: "percent", value: "60%", caption: "let go", spoken: "Let go of 60 percent")
        let months = StatChipView(symbol: "banknote", value: "1.4", caption: "months", spoken: "1.4 months of fun money")
        let chips = AdaptiveStackView(arrangedSubviews: [streak, rate, months, UIView()])
        chips.spacing = 8
        stack.addArrangedSubview(chips)
    }

    private func buildRows() {
        stack.addArrangedSubview(SectionHeaderView(title: "This payday", detail: "S$320"))
        stack.addArrangedSubview(WantRowView(model: WantRowModel(
            title: "Noise-cancelling headphones", priceText: "S$420", leadingSymbol: "calendar", tone: .accent,
            trailing: "14d", progress: 0.4, progressTone: .accent,
            accessibilityLabel: "Noise-cancelling headphones, S$420", accessibilityValue: "Thaws on payday, 14 days")))
        stack.addArrangedSubview(WantRowView(model: WantRowModel(
            title: "Coffee grinder", priceText: "S$89", leadingSymbol: "timer", tone: .timer,
            trailing: "2d", progress: 0.8, progressTone: .timer,
            accessibilityLabel: "Coffee grinder, S$89", accessibilityValue: "Quick thaw, 2 days left")))
        stack.addArrangedSubview(SectionHeaderView(title: "November", detail: "S$120 saved"))
        stack.addArrangedSubview(WantRowView(model: WantRowModel(
            title: "Running shoes", priceText: "S$120", leadingSymbol: "xmark.circle", tone: .accent,
            trailing: "12 Nov",
            accessibilityLabel: "Running shoes, S$120", accessibilityValue: "Let go, 12 November")))
        stack.addArrangedSubview(WantRowView(model: WantRowModel(
            title: "Desk lamp", priceText: "S$45", leadingSymbol: "checkmark.circle",
            trailing: "3 Nov",
            accessibilityLabel: "Desk lamp, S$45", accessibilityValue: "Bought, 3 November")))
        stack.addArrangedSubview(SectionHeaderView(title: "Existing row (unchanged)"))
        stack.addArrangedSubview(WantRowView(model: WantRowModel(
            title: "Mechanical keyboard", priceText: "S$180", status: "Thaws on payday",
            statusTone: .neutral, trailing: "14 days left", progress: 0.3, progressTone: .accent,
            accessibilityLabel: "Mechanical keyboard, S$180", accessibilityValue: "Thaws on payday, 14 days left")))
    }

    private func buildEmptyState() {
        stack.addArrangedSubview(EmptyStateView(mood: .frozen, line: "Nothing cooling.", actionTitle: "Add a want"))
        stack.addArrangedSubview(EmptyStateView(mood: .proud, line: "No decisions yet.", actionTitle: nil))
    }
}
#endif
