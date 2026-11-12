import UIKit

/// Single-select row of pill chips, e.g. "All · Payday · Quick thaw". Scrolls horizontally when the chips
/// don't fit and stacks vertically at accessibility sizes. `onChange` fires only for user taps.
final class FilterChipBar: UIView {
    private static let chipHeight: CGFloat = 44

    var onChange: ((Int) -> Void)?

    var selectedIndex: Int {
        didSet {
            selectedIndex = min(max(selectedIndex, 0), max(chips.count - 1, 0))
            updateSelection()
        }
    }

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var chips: [UIButton] = []
    private var verticalConstraints: [NSLayoutConstraint] = []
    private let feedback = UISelectionFeedbackGenerator()

    init(titles: [String], selectedIndex: Int) {
        self.selectedIndex = min(max(selectedIndex, 0), max(titles.count - 1, 0))
        super.init(frame: .zero)

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        chips = titles.enumerated().map { index, title in makeChip(title: title, index: index) }
        chips.forEach(stack.addArrangedSubview)

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            // The bar is as tall as its chips; horizontally it scrolls, vertically it fills the width.
            stack.heightAnchor.constraint(equalTo: frame.heightAnchor),
        ])
        verticalConstraints = [stack.widthAnchor.constraint(equalTo: frame.widthAnchor)]

        isAccessibilityElement = false
        accessibilityContainerType = .semanticGroup
        shouldGroupAccessibilityChildren = true

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: FilterChipBar, _) in
            self.updateAxis()
        }
        updateAxis()
        updateSelection()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollSelectedChipIntoView(animated: false)
    }

    private func makeChip(title: String, index: Int) -> UIButton {
        let chip = UIButton(type: .custom)
        chip.tag = index
        chip.accessibilityLabel = title
        chip.configurationUpdateHandler = { button in
            var config = UIButton.Configuration.filled()
            config.title = title
            config.titleLineBreakMode = .byWordWrapping
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
            config.background.cornerRadius = Theme.Radius.pill
            config.cornerStyle = .fixed
            if button.isSelected {
                config.baseBackgroundColor = Theme.accent
                config.baseForegroundColor = .white
                config.background.strokeWidth = 0
            } else {
                config.baseBackgroundColor = Theme.surface
                config.baseForegroundColor = Theme.ink
                config.background.strokeColor = Theme.controlBorder
                config.background.strokeWidth = 1
            }
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var updated = attributes
                updated.font = ThawFont.body(15, weight: .semibold)
                return updated
            }
            button.configuration = config
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.alpha = button.isHighlighted ? 0.7 : 1
        }
        chip.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.chipHeight).isActive = true
        chip.setContentCompressionResistancePriority(.required, for: .horizontal)
        chip.setContentHuggingPriority(.required, for: .horizontal)
        chip.addAction(UIAction { [weak self] _ in self?.tapChip(at: index) }, for: .touchUpInside)
        return chip
    }

    private func tapChip(at index: Int) {
        guard index != selectedIndex else { return }
        selectedIndex = index
        feedback.selectionChanged()
        scrollSelectedChipIntoView(animated: true)
        onChange?(index)
    }

    private func updateSelection() {
        for (index, chip) in chips.enumerated() {
            // `isSelected` also gives VoiceOver the `.selected` trait.
            chip.isSelected = index == selectedIndex
            chip.setNeedsUpdateConfiguration()
        }
    }

    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        if !large { NSLayoutConstraint.deactivate(verticalConstraints) }
        stack.axis = large ? .vertical : .horizontal
        stack.alignment = large ? .leading : .fill
        scrollView.isScrollEnabled = !large
        if large { NSLayoutConstraint.activate(verticalConstraints) }
    }

    private func scrollSelectedChipIntoView(animated: Bool) {
        guard scrollView.isScrollEnabled, chips.indices.contains(selectedIndex) else { return }
        let frame = chips[selectedIndex].frame.insetBy(dx: -Theme.Spacing.gap, dy: 0)
        scrollView.scrollRectToVisible(frame, animated: animated)
    }
}
