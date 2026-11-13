import UIKit

/// Pushed from Settings: pick the payday rule and its day. Changes save straight away.
final class PaydayRuleViewController: UIViewController, PaydayRuleViewProtocol, UICollectionViewDelegate {
    nonisolated private enum Section: Hashable { case options, day, next }
    nonisolated private enum Item: Hashable { case option(Int), day, next }

    var presenter: PaydayRulePresenterProtocol?

    private var content: PaydayRuleContent?
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        navigationItem.largeTitleDisplayMode = .never

        let layout = UICollectionViewCompositionalLayout { _, environment in
            var configuration = SettingsListStyle.listConfiguration(footer: false)
            configuration.headerMode = .none
            return SettingsListStyle.section(configuration, environment: environment)
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = Theme.background
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        configureDataSource()
        presenter?.viewDidLoad()
    }

    private func configureDataSource() {
        let option = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { [weak self] cell, _, index in
            guard let model = self?.content?.options[index] else { return }
            SettingsListStyle.styleBackground(cell)
            var configuration = UIListContentConfiguration.subtitleCell()
            SettingsListStyle.styleSubtitle(&configuration)
            configuration.text = model.title
            configuration.secondaryText = model.hint
            configuration.textToSecondaryTextVerticalPadding = 2
            cell.contentConfiguration = configuration
            cell.accessories = model.selected ? [.checkmark(options: .init(tintColor: Theme.accent))] : []
            cell.accessibilityTraits = model.selected ? [.button, .selected] : .button
        }
        let day = UICollectionView.CellRegistration<SettingsMenuCell, Item> { [weak self] cell, _, _ in
            guard let model = self?.content?.day else { return }
            cell.configure(model)
            cell.onSelect = { [weak self] value in self?.presenter?.dayChanged(value) }
        }
        let next = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, _ in
            guard let content = self?.content else { return }
            SettingsListStyle.styleBackground(cell)
            var configuration = UIListContentConfiguration.valueCell()
            SettingsListStyle.style(&configuration)
            configuration.text = content.nextPaydayTitle
            configuration.secondaryText = content.nextPayday
            cell.contentConfiguration = configuration
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = content.nextPaydayTitle
            cell.accessibilityValue = content.nextPayday
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { view, path, item in
            switch item {
            case .option(let index): view.dequeueConfiguredReusableCell(using: option, for: path, item: index)
            case .day: view.dequeueConfiguredReusableCell(using: day, for: path, item: item)
            case .next: view.dequeueConfiguredReusableCell(using: next, for: path, item: item)
            }
        }
    }

    // MARK: PaydayRuleViewProtocol

    func render(_ content: PaydayRuleContent) {
        let hadDay = self.content?.day != nil
        self.content = content
        title = content.title
        guard let dataSource else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.options])
        snapshot.appendItems(content.options.indices.map(Item.option), toSection: .options)
        if content.day != nil {
            snapshot.appendSections([.day])
            snapshot.appendItems([.day], toSection: .day)
        }
        snapshot.appendSections([.next])
        snapshot.appendItems([.next], toSection: .next)
        let existing = Set(dataSource.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter(existing.contains))
        let animate = !existing.isEmpty && hadDay != (content.day != nil)
        dataSource.apply(snapshot, animatingDifferences: animate)
    }

    func playSaveFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if case .option = dataSource.itemIdentifier(for: indexPath) { return true }
        return false
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard case .option(let index) = dataSource.itemIdentifier(for: indexPath) else { return }
        presenter?.selectRule(at: index)
    }
}
