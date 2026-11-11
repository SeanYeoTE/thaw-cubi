import UIKit

/// Cooling tab: filter chips, sort menu and lean want rows in a collection view list, so wants get swipe
/// Edit and Delete like Saved history. Tap opens the detail screen.
final class HomeViewController: UIViewController, HomeViewProtocol, UICollectionViewDelegate {
    private nonisolated enum Section: Hashable, Sendable {
        case header
        case empty
        case wants(Int)
    }

    private nonisolated enum Item: Hashable, Sendable {
        case title
        case filters
        case empty
        case sectionHeader(Int)
        case want(UUID)
    }

    private static let rowGap = WantListStyle.rowGap

    var presenter: HomePresenterProtocol?

    private var model: HomeViewModel?
    private var cards: [UUID: HomeCardViewModel] = [:]
    private var sortButton: UIButton?
    /// One bar for the screen's lifetime, so a tap keeps its selection animation across renders.
    private var filterBar: FilterChipBar?
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var isLongPress = false

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Cooling"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        navigationController?.navigationBar.prefersLargeTitles = true
        // The system large title stays blank for a collection view until the first real scroll, so the list draws it.
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = ""
        navigationItem.rightBarButtonItems = [makeAddItem(), makeSortItem()]

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: makeLayout())
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.contentInsetAdjustmentBehavior = .automatic
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        dataSource = makeDataSource()

        // A long press must not count as a tap: swipe is the only way to reach Edit and Delete.
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(holdChanged(_:)))
        hold.minimumPressDuration = 0.35
        hold.cancelsTouchesInView = false
        hold.delaysTouchesEnded = false
        hold.delegate = self
        collectionView.addGestureRecognizer(hold)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
    }

    private func makeAddItem() -> UIBarButtonItem {
        let add = UIButton(type: .custom)
        add.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)), for: .normal)
        add.tintColor = .white
        add.backgroundColor = Theme.accent
        add.layer.cornerRadius = 22
        add.accessibilityLabel = "Add a want"
        add.accessibilityIdentifier = "home.add"
        add.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        add.widthAnchor.constraint(equalToConstant: 44).isActive = true
        add.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let item = UIBarButtonItem(customView: add)
        if #available(iOS 26.0, *) {
            item.hidesSharedBackground = true
        }
        return item
    }

    private func makeSortItem() -> UIBarButtonItem {
        let sort = UIButton(type: .system)
        sort.setImage(UIImage(systemName: "arrow.up.arrow.down",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)), for: .normal)
        sort.tintColor = Theme.ink
        sort.showsMenuAsPrimaryAction = true
        sort.accessibilityLabel = "Sort"
        sort.accessibilityIdentifier = "home.sort"
        sort.widthAnchor.constraint(equalToConstant: 44).isActive = true
        sort.heightAnchor.constraint(equalToConstant: 44).isActive = true
        sortButton = sort
        return UIBarButtonItem(customView: sort)
    }

    private func updateSortMenu(_ model: HomeViewModel) {
        guard let sortButton else { return }
        sortButton.accessibilityValue = model.sortTitle
        sortButton.menu = UIMenu(title: "Sort", options: .singleSelection, children: model.sortOptions.map { option in
            UIAction(title: option.title, state: option.isSelected ? .on : .off) { [weak self] _ in
                self?.presenter?.selectSort(option.sort)
            }
        })
    }

    private func updateFilterBar(_ model: HomeViewModel) {
        if let filterBar {
            filterBar.selectedIndex = model.filterIndex
            return
        }
        let bar = FilterChipBar(titles: model.filterTitles, selectedIndex: model.filterIndex)
        bar.accessibilityIdentifier = "home.filters"
        bar.onChange = { [weak self] index in self?.presenter?.selectFilter(at: index) }
        filterBar = bar
    }

    // MARK: - Rendering

    func render(_ model: HomeViewModel) {
        self.model = model
        cards = Dictionary(uniqueKeysWithValues: model.sections.flatMap(\.cards).map { ($0.id, $0) })
        updateSortMenu(model)
        updateFilterBar(model)
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.header])
        let showsFilters = model.empty?.kind != .noWants
        snapshot.appendItems(showsFilters ? [.title, .filters] : [.title], toSection: .header)
        if model.empty != nil {
            snapshot.appendSections([.empty])
            snapshot.appendItems([.empty], toSection: .empty)
        }
        for (index, section) in model.sections.enumerated() {
            snapshot.appendSections([.wants(index)])
            if section.title != nil { snapshot.appendItems([.sectionHeader(index)], toSection: .wants(index)) }
            snapshot.appendItems(section.cards.map { .want($0.id) }, toSection: .wants(index))
        }
        let existing = Set(dataSource.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter(existing.contains))
        dataSource.apply(snapshot, animatingDifferences: view.window != nil)
    }

    func showDeleteConfirmation(id: UUID, confirmation: HomeDeleteConfirmation) {
        let alert = UIAlertController(title: confirmation.title, message: confirmation.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: confirmation.cancelTitle, style: .cancel))
        alert.addAction(UIAlertAction(title: confirmation.deleteTitle, style: .destructive) { [weak self] _ in
            self?.presenter?.confirmDelete(id: id)
        })
        present(alert, animated: true)
    }

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] index, environment in
            guard let self else { return nil }
            let section = self.dataSource?.sectionIdentifier(for: index) ?? .header
            let isWants: Bool
            if case .wants = section { isWants = true } else { isWants = false }
            var config = UICollectionLayoutListConfiguration(appearance: .plain)
            config.showsSeparators = false
            config.backgroundColor = .clear
            if isWants {
                config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                    self?.swipeActions(at: indexPath)
                }
            }
            let layoutSection = NSCollectionLayoutSection.list(using: config, layoutEnvironment: environment)
            layoutSection.contentInsetsReference = .none
            if isWants { WantListStyle.applyRowSpacing(to: layoutSection) }
            let isLast = index == (self.dataSource?.snapshot().numberOfSections ?? 1) - 1
            let top: CGFloat
            switch section {
            case .header: top = 0
            case .empty: top = Self.rowGap * 2
            case .wants: top = Self.rowGap
            }
            layoutSection.contentInsets = WantListStyle.contentInsets(
                environment: environment, safeArea: self.collectionView?.safeAreaInsets ?? .zero,
                top: top, bottom: isLast ? 24 : 0)
            return layoutSection
        }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, item in
            self?.configure(cell, item: item)
        }
        return UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }
    }

    private func configure(_ cell: UICollectionViewListCell, item: Item) {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundConfiguration = .clear()
        cell.isAccessibilityElement = false
        cell.accessibilityIdentifier = nil
        cell.accessibilityTraits = []
        cell.accessibilityLabel = nil
        cell.accessibilityValue = nil
        cell.accessibilityHint = nil
        cell.accessibilityCustomActions = nil
        let content: UIView
        var topGap = Self.rowGap / 2
        var bottomGap = Self.rowGap / 2
        switch item {
        case .title:
            let label = UILabel()
            label.text = "Cooling"
            label.font = ThawFont.display(36)
            label.textColor = Theme.ink
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
            label.accessibilityTraits = .header
            content = label
            topGap = 0
        case .filters:
            guard let filterBar else { return }
            content = filterBar
        case .empty:
            guard let empty = model?.empty else { return }
            content = makeEmptyView(empty)
            topGap = 0
            bottomGap = 0
        case .sectionHeader(let index):
            guard let section = model?.sections[safe: index], let title = section.title else { return }
            content = SectionHeaderView(title: title, detail: section.trailing)
            // Baseline alignment leaves its height loose, so the cell would keep the list's taller estimate.
            let hug = content.heightAnchor.constraint(equalToConstant: 0)
            hug.priority = .fittingSizeLevel
            hug.isActive = true
            topGap = 0
            bottomGap = 0
        case .want(let id):
            guard let card = cards[id] else { return }
            topGap = 0
            bottomGap = 0
            let label = card.accessibilityLabel
            let value = card.accessibilityValue
            content = WantRowView(model: WantRowModel(
                title: card.name, priceText: card.priceText, leadingSymbol: card.symbol,
                tone: card.isTimer ? .timer : .accent, trailing: card.trailingText,
                progress: card.progress, progressTone: card.isTimer ? .timer : .accent,
                accessibilityLabel: label, accessibilityValue: value))
            content.isUserInteractionEnabled = false
            // The cell is the single VoiceOver element; its swipe actions are exposed as custom actions.
            cell.isAccessibilityElement = true
            cell.accessibilityIdentifier = "home.card"
            cell.accessibilityLabel = label
            cell.accessibilityValue = value
            cell.accessibilityTraits = .button
            cell.accessibilityCustomActions = WantListStyle.accessibilityActions(
                onEdit: { [weak self] in self?.presenter?.tapEdit(id: id) },
                onDelete: { [weak self] in self?.presenter?.tapDelete(id: id) })
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            content.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: topGap),
            content.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -bottomGap),
        ])
    }

    private func makeEmptyView(_ empty: HomeEmptyViewModel) -> UIView {
        switch empty.kind {
        case .noWants:
            let view = EmptyStateView(mood: .frozen, line: empty.line, actionTitle: empty.actionTitle)
            view.onAction = { [weak self] in self?.presenter?.tapAdd() }
            view.accessibilityIdentifier = "home.empty"
            return view
        case .noMatches:
            let label = UILabel()
            label.text = empty.line
            label.font = ThawFont.body(15)
            label.textColor = Theme.inkSecondary
            label.textAlignment = .center
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true

            var config = UIButton.Configuration.plain()
            config.title = empty.actionTitle
            config.baseForegroundColor = Theme.accent
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var updated = attributes
                updated.font = ThawFont.body(15, weight: .semibold)
                return updated
            }
            let button = UIButton(configuration: config)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.accessibilityIdentifier = "home.showAll"
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            button.addAction(UIAction { [weak self] _ in self?.presenter?.tapShowAll() }, for: .touchUpInside)

            let stack = UIStackView(arrangedSubviews: [label, button])
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = 4
            stack.accessibilityIdentifier = "home.noMatches"
            return stack
        }
    }

    // MARK: - Swipe actions

    private func swipeActions(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard case .want(let id) = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return WantListStyle.swipeActions(
            onEdit: { [weak self] in self?.presenter?.tapEdit(id: id) },
            onDelete: { [weak self] in self?.presenter?.tapDelete(id: id) }
        )
    }

    // MARK: - Delegate

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard !isLongPress, case .want = dataSource.itemIdentifier(for: indexPath) else { return false }
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        if case .want(let id) = dataSource.itemIdentifier(for: indexPath) { presenter?.tapWant(id: id) }
    }

    @objc private func holdChanged(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            isLongPress = true
        case .ended, .cancelled, .failed:
            // Selection fires on touch-up; clear the flag after it has been evaluated.
            DispatchQueue.main.async { [weak self] in self?.isLongPress = false }
        default:
            break
        }
    }

    @objc private func addTapped() {
        presenter?.tapAdd()
    }
}

extension HomeViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
