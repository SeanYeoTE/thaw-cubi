import Charts
import SwiftUI
import UIKit

/// Saved tab: header (Cubi, total, progress) and History rows in a collection view list,
/// so History rows get swipe actions. Visually matches the `ScrollStackViewController` screens.
final class SavedViewController: UIViewController, SavedViewProtocol {
    private nonisolated enum Section: Hashable, Sendable {
        case header
        case history
    }

    private nonisolated enum Item: Hashable, Sendable {
        case header
        case row(UUID)
    }

    /// Same column cap and margins as `ScrollStackViewController`.
    private static let maxContentWidth: CGFloat = 700
    private static let rowGap: CGFloat = 14

    var presenter: SavedPresenterProtocol?

    private var model: SavedViewModel?
    private var rows: [UUID: SavedHistoryRow] = [:]
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Stats"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        navigationController?.navigationBar.prefersLargeTitles = true
        // The system large title stays blank for a collection view until the first real scroll, so the header draws it.
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = ""

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: makeLayout())
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        dataSource = makeDataSource()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
    }

    // MARK: - SavedViewProtocol

    func render(_ model: SavedViewModel) {
        self.model = model
        rows = Dictionary(model.history.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard let dataSource else { return }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.header])
        snapshot.appendItems([.header])
        if !model.history.isEmpty {
            snapshot.appendSections([.history])
            snapshot.appendItems(model.history.map { .row($0.id) })
        }
        let existing = Set(dataSource.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter(existing.contains))
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

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] index, environment in
            guard let self else { return nil }
            let section = self.dataSource?.sectionIdentifier(for: index) ?? .header
            var config = UICollectionLayoutListConfiguration(appearance: .plain)
            config.showsSeparators = false
            config.backgroundColor = .clear
            if section == .history {
                config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                    self?.swipeActions(at: indexPath)
                }
            }
            let layoutSection = NSCollectionLayoutSection.list(using: config, layoutEnvironment: environment)
            layoutSection.contentInsetsReference = .none
            let safe = self.collectionView?.safeAreaInsets ?? .zero
            let available = environment.container.contentSize.width - safe.left - safe.right
            let side = max(Theme.Spacing.screen, (available - Self.maxContentWidth) / 2)
            let hasHistory = self.dataSource?.snapshot().indexOfSection(.history) != nil
            let bottom: CGFloat = section == .history || !hasHistory ? 24 - Self.rowGap / 2 : 0
            layoutSection.contentInsets = NSDirectionalEdgeInsets(
                top: 0, leading: safe.left + side, bottom: bottom, trailing: safe.right + side
            )
            return layoutSection
        }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let headerRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, _ in
            guard let self, let model = self.model else { return }
            self.configureHeader(cell, model: model)
        }
        let rowRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, UUID> { [weak self] cell, _, id in
            guard let self, let row = self.rows[id] else { return }
            self.configureRow(cell, row: row)
        }
        return UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .header:
                collectionView.dequeueConfiguredReusableCell(using: headerRegistration, for: indexPath, item: item)
            case .row(let id):
                collectionView.dequeueConfiguredReusableCell(using: rowRegistration, for: indexPath, item: id)
            }
        }
    }

    // MARK: - Cells

    private func configureHeader(_ cell: UICollectionViewListCell, model: SavedViewModel) {
        prepare(cell)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Self.rowGap
        let heading = makeLabel(title ?? "Stats", font: ThawFont.display(36))
        heading.accessibilityTraits = .header
        stack.addArrangedSubview(heading)
        if let progress = model.progress {
            stack.addArrangedSubview(cubiBesideStats(model.cubi, progress))
        } else {
            stack.addArrangedSubview(CubiHeaderView(mood: model.cubi.mood, line: model.cubi.line, spoken: model.cubi.line))
            if let emptyText = model.emptyText {
                stack.addArrangedSubview(makeLabel(emptyText, font: ThawFont.body(16)))
            }
        }
        if model.monthlySaved.count >= 2 {
            stack.addArrangedSubview(makeLabel("Saved per month", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
            stack.addArrangedSubview(savedChart(model.monthlySaved))
        }
        if !model.history.isEmpty {
            stack.addArrangedSubview(makeLabel("History", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary))
        }
        pin(stack, in: cell.contentView, top: 16, bottom: Self.rowGap / 2)
    }

    private func configureRow(_ cell: UICollectionViewListCell, row: SavedHistoryRow) {
        prepare(cell)
        let card = CardView()
        let name = makeLabel(row.name, font: ThawFont.body(16, weight: .semibold))
        let detail = makeLabel("\(row.outcome) · \(row.dateText)", font: ThawFont.body(13),
                               color: row.isSkipped ? Theme.accent : Theme.inkSecondary)
        let price = makeLabel(row.priceText, font: ThawFont.money(16))
        price.setContentHuggingPriority(.required, for: .horizontal)
        let texts = UIStackView(arrangedSubviews: [name, detail])
        texts.axis = .vertical
        texts.spacing = 2
        let line = AdaptiveStackView(arrangedSubviews: [texts, price])
        line.compactAlignment = .center
        line.spacing = 12
        line.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            line.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            line.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            line.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        pin(card, in: cell.contentView, top: Self.rowGap / 2, bottom: Self.rowGap / 2)

        let id = row.id
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = "\(row.name), \(row.priceText)"
        cell.accessibilityValue = "\(row.outcome) · \(row.dateText)"
        cell.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Edit") { [weak self] _ in
                self?.presenter?.tapEdit(id: id)
                return true
            },
            UIAccessibilityCustomAction(name: "Delete") { [weak self] _ in
                self?.presenter?.tapDelete(id: id)
                return true
            },
        ]
    }

    private func prepare(_ cell: UICollectionViewListCell) {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundConfiguration = .clear()
        cell.isAccessibilityElement = false
        cell.accessibilityLabel = nil
        cell.accessibilityValue = nil
        cell.accessibilityCustomActions = nil
    }

    /// Cubi on the leading edge with the progress stats beside it; stacks at accessibility sizes.
    private func cubiBesideStats(_ cubi: SavedCubiViewModel, _ model: SavedProgressViewModel) -> UIView {
        let avatar = CubiView(mood: cubi.mood, size: 56)
        avatar.spokenLine = cubi.line
        avatar.setContentHuggingPriority(.required, for: .horizontal)
        avatar.setContentCompressionResistancePriority(.required, for: .horizontal)
        let column = UIStackView()
        column.axis = .vertical
        column.spacing = 14
        for stat in model.stats {
            let value = makeLabel(stat.value, font: ThawFont.display(20))
            let caption = makeLabel(stat.caption, font: ThawFont.body(13), color: Theme.inkSecondary)
            let item = UIStackView(arrangedSubviews: [value, caption])
            item.axis = .vertical
            item.spacing = 2
            item.isAccessibilityElement = true
            item.accessibilityLabel = stat.spoken
            column.addArrangedSubview(item)
        }
        let row = AdaptiveStackView(arrangedSubviews: [avatar, column])
        row.compactAlignment = .top
        row.spacing = 16
        return row
    }

    private func savedChart(_ months: [SavedMonthlyAmount]) -> UIView {
        let view = UIHostingConfiguration {
            Chart(months) { point in
                BarMark(x: .value("Month", point.month, unit: .month), y: .value("Saved", point.amount))
                    .foregroundStyle(Color(Theme.accent))
                    .cornerRadius(4)
            }
            .frame(height: 140)
            .accessibilityLabel("Saved per month")
        }
        .margins(.all, 0)
        .makeContentView()
        return view
    }

    // MARK: - Swipe actions

    private func swipeActions(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard case .row(let id) = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            // The row stays until the user confirms, so the swipe reports "not performed".
            done(false)
            self?.presenter?.tapDelete(id: id)
        }
        delete.image = UIImage(systemName: "trash")
        let edit = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, done in
            done(true)
            self?.presenter?.tapEdit(id: id)
        }
        edit.image = UIImage(systemName: "arrow.uturn.backward")
        edit.backgroundColor = Theme.accent
        let configuration = UISwipeActionsConfiguration(actions: [delete, edit])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    // MARK: - Helpers

    private func pin(_ inner: UIView, in container: UIView, top: CGFloat, bottom: CGFloat) {
        inner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            inner.topAnchor.constraint(equalTo: container.topAnchor, constant: top),
            inner.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -bottom),
        ])
    }

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

extension SavedViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool { false }
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool { false }
}
