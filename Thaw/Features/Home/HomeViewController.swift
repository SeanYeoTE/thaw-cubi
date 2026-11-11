import UIKit

/// Cooling tab: payday card and want cards in a collection view list, so wants get swipe Edit and Delete
/// like Saved history. Tap opens the detail screen.
final class HomeViewController: UIViewController, HomeViewProtocol, UICollectionViewDelegate {
    private nonisolated enum Section: Hashable, Sendable {
        case header
        case wants
    }

    private nonisolated enum Item: Hashable, Sendable {
        case title
        case payday
        case empty
        case want(UUID)
    }

    /// Same column cap and margins as `ScrollStackViewController`.
    private static let maxContentWidth: CGFloat = 700
    private static let rowGap = WantListStyle.rowGap

    var presenter: HomePresenterProtocol?

    private var model: HomeViewModel?
    private var cards: [UUID: HomeCardViewModel] = [:]
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
        navigationItem.rightBarButtonItem = makeAddItem()

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

    // MARK: - Rendering

    func render(_ model: HomeViewModel) {
        self.model = model
        cards = Dictionary(uniqueKeysWithValues: model.cards.map { ($0.id, $0) })
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.header])
        snapshot.appendItems(model.emptyText == nil ? [.title, .payday] : [.title, .payday, .empty], toSection: .header)
        if !model.cards.isEmpty {
            snapshot.appendSections([.wants])
            snapshot.appendItems(model.cards.map { .want($0.id) }, toSection: .wants)
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
            var config = UICollectionLayoutListConfiguration(appearance: .plain)
            config.showsSeparators = false
            config.backgroundColor = .clear
            if section == .wants {
                config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                    self?.swipeActions(at: indexPath)
                }
            }
            let layoutSection = NSCollectionLayoutSection.list(using: config, layoutEnvironment: environment)
            layoutSection.contentInsetsReference = .none
            if section == .wants { WantListStyle.applyRowSpacing(to: layoutSection) }
            let safe = self.collectionView?.safeAreaInsets ?? .zero
            let available = environment.container.contentSize.width - safe.left - safe.right
            let side = max(Theme.Spacing.screen, (available - Self.maxContentWidth) / 2)
            let hasWants = self.dataSource?.snapshot().indexOfSection(.wants) != nil
            let top: CGFloat = section == .wants ? Self.rowGap / 2 : 0
            let bottom: CGFloat = section == .wants ? 24 : (!hasWants ? 24 - Self.rowGap / 2 : 0)
            layoutSection.contentInsets = NSDirectionalEdgeInsets(
                top: top, leading: safe.left + side, bottom: bottom, trailing: safe.right + side
            )
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
        case .payday:
            guard let model else { return }
            let payday = PaydayCardView(daysLeft: model.daysLeft, nextPayday: model.nextPaydayText,
                                        subtitle: model.paydaySubtitle)
            payday.addAction(UIAction { [weak self] _ in self?.presenter?.tapPayday() }, for: .touchUpInside)
            payday.accessibilityIdentifier = "home.payday"
            payday.isEnabled = model.hasReview
            payday.alpha = model.hasReview ? 1 : 0.5
            if !model.hasReview { payday.accessibilityTraits.insert(.notEnabled) }
            payday.accessibilityHint = model.hasReview ? "Opens the payday preview" : "Nothing has thawed yet"
            content = payday
        case .empty:
            let label = UILabel()
            label.text = model?.emptyText
            label.font = ThawFont.body(15)
            label.textColor = Theme.inkSecondary
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
            content = label
        case .want(let id):
            guard let card = cards[id] else { return }
            topGap = 0
            bottomGap = 0
            let label = "\(card.name), \(card.priceText)"
            let value = "\(card.statusText), \(card.trailingText)"
            content = WantRowView(model: WantRowModel(
                title: card.name, priceText: card.priceText, status: card.statusText,
                statusTone: .neutral, trailing: card.trailingText,
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
