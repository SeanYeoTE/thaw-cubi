import Charts
import SwiftUI
import UIKit

/// Stats tab: header (total, chips, chart, filter) and month-grouped History rows in a collection view list,
/// so History rows get swipe actions. Visually matches the `ScrollStackViewController` screens.
final class SavedViewController: ThawListViewController, SavedViewProtocol {
    private nonisolated enum Section: Hashable, Sendable {
        case top
        case note
        case month(Date)
    }

    private nonisolated enum Item: Hashable, Sendable {
        case top
        case note
        case monthHeader(Date)
        case row(UUID)
    }

    /// Everything the top cell draws, except the filter selection, which the chip bar already shows after a tap.
    private struct TopContent: Equatable {
        let hero: SavedHeroViewModel
        let chips: [SavedStatChip]
        let chart: SavedChartViewModel
        let empty: SavedEmptyViewModel?
        let filterTitles: [String]?

        init(_ model: SavedViewModel) {
            hero = model.hero
            chips = model.chips
            chart = model.chart
            empty = model.empty
            filterTitles = model.history?.filterTitles
        }
    }

    private static let rowGap = WantListStyle.rowGap

    var presenter: SavedPresenterProtocol?

    private var model: SavedViewModel?
    private var rows: [UUID: SavedHistoryRow] = [:]
    private var sections: [Date: SavedHistorySection] = [:]
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Stats"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var titleInsets: ThawListTitleInsets { ThawListTitleInsets(top: 16, bottom: Theme.Spacing.gap) }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        collectionView.delegate = self
        dataSource = makeDataSource()
        // The range picker and chart take fixed fonts, so rebuild the top cell when the text size changes.
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: SavedViewController, _) in
            self.reconfigureTop()
        }
    }

    private func reconfigureTop() {
        guard let dataSource else { return }
        var snapshot = dataSource.snapshot()
        guard snapshot.itemIdentifiers.contains(.top) else { return }
        snapshot.reconfigureItems([.top])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
    }

    // MARK: - SavedViewProtocol

    func render(_ model: SavedViewModel) {
        let topChanged = self.model.map { TopContent($0) != TopContent(model) } ?? true
        self.model = model
        let history = model.history?.sections ?? []
        rows = Dictionary(history.flatMap(\.rows).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        sections = Dictionary(history.map { ($0.month, $0) }, uniquingKeysWith: { first, _ in first })
        guard let dataSource else { return }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.top])
        snapshot.appendItems([.top])
        if model.history?.emptyText != nil {
            snapshot.appendSections([.note])
            snapshot.appendItems([.note])
        }
        var seen = Set<UUID>()
        for section in history {
            snapshot.appendSections([.month(section.month)])
            let ids = section.rows.map(\.id).filter { seen.insert($0).inserted }
            snapshot.appendItems([.monthHeader(section.month)] + ids.map { .row($0) })
        }
        let existing = Set(dataSource.snapshot().itemIdentifiers)
        let reconfigure = snapshot.itemIdentifiers.filter { existing.contains($0) && ($0 != .top || topChanged) }
        snapshot.reconfigureItems(reconfigure)
        dataSource.apply(snapshot, animatingDifferences: view.window != nil)
    }

    func showDeleteConfirmation(id: UUID, confirmation: SavedDeleteConfirmation) {
        let alert = UIAlertController(title: confirmation.title, message: confirmation.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: confirmation.cancelTitle, style: .cancel))
        alert.addAction(UIAlertAction(title: confirmation.deleteTitle, style: .destructive) { [weak self] _ in
            self?.presenter?.confirmDelete(id: id)
        })
        present(alert, animated: true)
    }

    func showChipExplanation(_ explanation: SavedChipExplanation) {
        let alert = UIAlertController(title: nil, message: explanation.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: explanation.dismissTitle, style: .default))
        present(alert, animated: true)
    }

    // MARK: - Layout

    override func sectionLayout(at index: Int, environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? {
        let snapshot = dataSource?.snapshot()
        let section = dataSource?.sectionIdentifier(for: index) ?? .top
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.showsSeparators = false
        config.backgroundColor = .clear
        if case .month = section {
            config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                self?.swipeActions(at: indexPath)
            }
        }
        let layoutSection = NSCollectionLayoutSection.list(using: config, layoutEnvironment: environment)
        layoutSection.contentInsetsReference = .none
        let top: CGFloat
        switch section {
        case .top:
            top = 0
        case .note:
            top = Self.rowGap
        case .month:
            WantListStyle.applyRowSpacing(to: layoutSection)
            top = 24
        }
        let isLast = index == (snapshot?.numberOfSections ?? 1) - 1
        layoutSection.contentInsets = columnInsets(environment: environment, top: top, bottom: isLast ? 24 : 0)
        return layoutSection
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let topRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, _ in
            guard let self, let model = self.model else { return }
            self.configureTop(cell, model: model)
        }
        let noteRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, _ in
            guard let self, let text = self.model?.history?.emptyText else { return }
            cell.resetForReuse()
            cell.embed(self.makeLabel(text, font: ThawFont.body(15), color: Theme.inkSecondary))
        }
        let headerRegistration = UICollectionView.CellRegistration<MonthHeaderCell, Date> { [weak self] cell, _, month in
            guard let self, let section = self.sections[month] else { return }
            cell.configure(title: section.title, detail: section.detail)
        }
        let rowRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, UUID> { [weak self] cell, _, id in
            guard let self, let row = self.rows[id] else { return }
            self.configureRow(cell, row: row)
        }
        let dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .top:
                collectionView.dequeueConfiguredReusableCell(using: topRegistration, for: indexPath, item: item)
            case .note:
                collectionView.dequeueConfiguredReusableCell(using: noteRegistration, for: indexPath, item: item)
            case .monthHeader(let month):
                collectionView.dequeueConfiguredReusableCell(using: headerRegistration, for: indexPath, item: month)
            case .row(let id):
                collectionView.dequeueConfiguredReusableCell(using: rowRegistration, for: indexPath, item: id)
            }
        }
        installTitle(on: dataSource)
        return dataSource
    }

    // MARK: - Cells

    private func configureTop(_ cell: UICollectionViewListCell, model: SavedViewModel) {
        cell.resetForReuse()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20

        if let empty = model.empty {
            stack.addArrangedSubview(EmptyStateView(mood: empty.mood, line: empty.line, actionTitle: nil))
            // The empty state sits further below the title than the stats do.
            cell.embed(stack, top: 48 - Theme.Spacing.gap)
            return
        }

        stack.addArrangedSubview(heroView(model.hero))
        if !model.chips.isEmpty {
            stack.addArrangedSubview(chipRow(model.chips))
        }
        if model.chart.showsChart {
            let chart = model.chart
            if chart.showsRangePicker {
                let picker = rangePicker(chart)
                stack.addArrangedSubview(picker)
                stack.setCustomSpacing(Theme.Spacing.gap, after: picker)
            }
            stack.addArrangedSubview(savedChart(chart))
        }
        if let history = model.history {
            let filter = FilterChipBar(titles: history.filterTitles, selectedIndex: history.selectedFilter)
            filter.accessibilityIdentifier = "stats.filter"
            filter.onChange = { [weak self] index in self?.presenter?.selectHistoryFilter(at: index) }
            stack.addArrangedSubview(filter)
        }
        cell.embed(stack)
    }

    private func configureRow(_ cell: UICollectionViewListCell, row: SavedHistoryRow) {
        cell.resetForReuse()
        let card = WantRowView(model: WantRowModel(
            title: row.name, priceText: row.priceText,
            leadingSymbol: row.isSkipped ? "xmark.circle" : "checkmark.circle",
            tone: row.isSkipped ? .accent : .neutral,
            accessibilityLabel: row.accessibilityLabel,
            accessibilityValue: row.accessibilityValue))
        cell.embed(card)

        let id = row.id
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = row.accessibilityLabel
        cell.accessibilityValue = row.accessibilityValue
        cell.accessibilityTraits = .button
        cell.accessibilityHint = "Opens Edit"
        cell.accessibilityCustomActions = WantListStyle.accessibilityActions(
            onEdit: { [weak self] in self?.presenter?.tapEdit(id: id) },
            onDelete: { [weak self] in self?.presenter?.tapDelete(id: id) })
    }

    /// Cubi beside the total saved, on the same dark card as Payday; stacks at accessibility sizes.
    private func heroView(_ hero: SavedHeroViewModel) -> UIView {
        let avatar = CubiView(mood: hero.mood, size: .card)
        avatar.spokenLine = hero.spokenLine
        avatar.setContentHuggingPriority(.required, for: .horizontal)
        avatar.setContentCompressionResistancePriority(.required, for: .horizontal)

        let amount = makeLabel(hero.savedText, font: ThawFont.display(44), color: .white)
        let caption = makeLabel(hero.caption, font: ThawFont.body(15), color: Theme.paydayLabel)
        let column = UIStackView(arrangedSubviews: [amount, caption])
        column.axis = .vertical
        column.spacing = 0
        column.isAccessibilityElement = true
        column.accessibilityLabel = hero.spoken
        column.accessibilityIdentifier = "stats.hero"

        let row = AdaptiveStackView(arrangedSubviews: [avatar, column])
        row.compactAlignment = .center
        row.spacing = 16
        return HeroCardView(content: row)
    }

    /// Three equal-width tiles in a row; they stack full width at accessibility sizes.
    private func chipRow(_ chips: [SavedStatChip]) -> UIView {
        let row = ChipRowStackView()
        row.spacing = 8
        for (index, chip) in chips.enumerated() {
            let view = StatChipView(symbol: chip.symbol, value: chip.value, caption: chip.caption, spoken: chip.spoken)
            view.addAction(UIAction { [weak self] _ in self?.presenter?.tapChip(at: index) }, for: .touchUpInside)
            row.addArrangedSubview(view)
        }
        return row
    }

    private func rangePicker(_ chart: SavedChartViewModel) -> UIView {
        let picker = UISegmentedControl(items: chart.rangeTitles)
        picker.selectedSegmentIndex = chart.selectedRange
        let font = ThawFont.body(13, weight: .semibold)
        picker.setTitleTextAttributes([.font: font, .foregroundColor: Theme.ink], for: .normal)
        picker.setTitleTextAttributes([.font: font, .foregroundColor: Theme.onAccent], for: .selected)
        picker.selectedSegmentTintColor = Theme.accent
        picker.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        picker.addAction(UIAction { [weak self, weak picker] _ in
            guard let picker else { return }
            self?.presenter?.selectChartRange(at: picker.selectedSegmentIndex)
        }, for: .valueChanged)
        return picker
    }

    private func savedChart(_ chart: SavedChartViewModel) -> UIView {
        UIHostingConfiguration {
            SavedChartView(months: chart.months, label: chart.accessibilityLabel, value: chart.accessibilityValue)
        }
        .margins(.all, 0)
        .makeContentView()
    }

    // MARK: - Swipe actions

    private func swipeActions(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard case .row(let id) = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return WantListStyle.swipeActions(
            onEdit: { [weak self] in self?.presenter?.tapEdit(id: id) },
            onDelete: { [weak self] in self?.presenter?.tapDelete(id: id) }
        )
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, font: UIFont, color: UIColor = Theme.ink) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }
}

/// Horizontal with equal widths and heights at standard sizes; vertical and full width at accessibility sizes.
private final class ChipRowStackView: UIStackView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        alignment = .fill
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: ChipRowStackView, _) in
            self.updateAxis()
        }
        updateAxis()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func updateAxis() {
        let large = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        axis = large ? .vertical : .horizontal
        distribution = large ? .fill : .fillEqually
    }
}

/// Tapping a History row opens Edit (which also offers Delete), so swiping is never the only way to reach them.
extension SavedViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        isRow(at: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        isRow(at: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if case .row(let id) = dataSource.itemIdentifier(for: indexPath) { presenter?.tapEdit(id: id) }
    }

    private func isRow(at indexPath: IndexPath) -> Bool {
        if case .row = dataSource.itemIdentifier(for: indexPath) { return true }
        return false
    }
}

/// Month header in the History list. Sizes to its text, so it isn't held to the list's 44 pt estimated row height.
private final class MonthHeaderCell: UICollectionViewCell {
    private let header = SectionHeaderView(title: "")

    override init(frame: CGRect) {
        super.init(frame: frame)
        header.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(header)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            header.topAnchor.constraint(equalTo: contentView.topAnchor),
            header.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(title: String, detail: String?) {
        header.configure(title: title, detail: detail)
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let size = contentView.systemLayoutSizeFitting(
            CGSize(width: layoutAttributes.size.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        attributes.size.height = ceil(size.height)
        return attributes
    }
}

/// Bars per month, all in solid accent so each clears 3:1 against the background. The highlighted bar (the
/// current month until the user picks another) is drawn in ink and labelled, so colour is never the only cue.
private struct SavedChartView: View {
    let months: [SavedMonthlyAmount]
    let label: String
    let value: String
    @State private var rawSelection: Date?
    @State private var selectedMonth: Date?

    private var highlightedMonth: Date? {
        selectedMonth ?? months.first(where: \.isCurrent)?.month
    }

    var body: some View {
        Chart(months) { point in
            BarMark(x: .value("Month", point.month, unit: .month), y: .value("Saved", point.amount))
                .foregroundStyle(Color(point.month == highlightedMonth ? Theme.ink : Theme.accent))
                .cornerRadius(4)
                .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                    if point.month == highlightedMonth {
                        Text(point.selectionText)
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color(Theme.ink))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color(Theme.surface)))
                            .overlay(Capsule().stroke(Color(Theme.border)))
                    }
                }
                .accessibilityLabel(point.spokenMonth)
                .accessibilityValue(point.spokenAmount)
        }
        .chartXSelection(value: $rawSelection)
        .onChange(of: rawSelection) { _, new in
            guard let new else { return }
            selectedMonth = months.first { Calendar.current.isDate($0.month, equalTo: new, toGranularity: .month) }?.month
        }
        .padding(.top, 28)
        .frame(height: 180)
        // One element covering the whole chart, so the axis labels and the selection label sit inside an
        // accessibility frame (the audit flagged them as potentially inaccessible text). The value reads every
        // month and the descriptor keeps Audio Graph.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityIdentifier("stats.chart")
        .accessibilityChartDescriptor(SavedChartDescriptor(title: label, months: months))
    }
}

private struct SavedChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let months: [SavedMonthlyAmount]

    func makeChartDescriptor() -> AXChartDescriptor {
        let names = months.map(\.spokenMonth)
        let maxAmount = max(months.map(\.amount).max() ?? 0, 1)
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Month", categoryOrder: names)
        let yAxis = AXNumericDataAxisDescriptor(title: "Saved", range: 0...maxAmount, gridlinePositions: []) { amount in
            "S$\(Int(amount.rounded()))"
        }
        let series = AXDataSeriesDescriptor(name: title, isContinuous: false, dataPoints: months.map {
            AXDataPoint(x: $0.spokenMonth, y: $0.amount, label: $0.spokenAmount)
        })
        return AXChartDescriptor(title: title, summary: nil, xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [series])
    }
}
