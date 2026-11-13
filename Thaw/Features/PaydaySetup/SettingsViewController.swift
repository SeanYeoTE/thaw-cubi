import UIKit

/// The Settings tab: an inset-grouped list that saves as you change it.
final class SettingsViewController: ThawListViewController, SettingsViewProtocol, UICollectionViewDelegate {
    var presenter: SettingsPresenterProtocol?

    private var content: SettingsContent?
    private var dataSource: UICollectionViewDiffableDataSource<String, SettingsRowID>!

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Settings"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var listBottomAnchor: NSLayoutYAxisAnchor { view.keyboardLayoutGuide.topAnchor }

    override var listAppearance: ThawListAppearance { .insetGrouped }

    override func sectionLayout(at index: Int, environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? {
        let configuration = SettingsListStyle.listConfiguration(footer: section(at: index)?.footer != nil)
        return ThawColumn.insetGroupedSection(configuration, environment: environment)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // The pushed Payday screen gets a chevron-only back button.
        navigationItem.backButtonDisplayMode = .minimal
        collectionView.delegate = self
        configureDataSource()
        presenter?.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Commits a field that is still being edited, so switching tabs never loses it.
        view.endEditing(true)
    }

    // MARK: Data source

    private func section(at index: Int) -> SettingsSectionViewModel? {
        guard let sections = content?.sections, sections.indices.contains(index) else { return nil }
        return sections[index]
    }

    private func row(_ id: SettingsRowID) -> SettingsRowViewModel? {
        content?.sections.lazy.flatMap(\.rows).first { $0.id == id }
    }

    private func configureDataSource() {
        let plain = UICollectionView.CellRegistration<UICollectionViewListCell, SettingsRowID> { [weak self] cell, _, id in
            guard let model = self?.row(id) else { return }
            SettingsListStyle.styleBackground(cell)
            var configuration = UIListContentConfiguration.valueCell()
            SettingsListStyle.style(&configuration)
            configuration.text = model.title
            configuration.secondaryText = model.value
            cell.contentConfiguration = configuration
            cell.accessories = model.control == .disclosure ? [.disclosureIndicator()] : []
            cell.isAccessibilityElement = true
            cell.accessibilityLabel = model.accessibilityLabel
            cell.accessibilityValue = model.accessibilityValue
            cell.accessibilityTraits = model.control == .disclosure ? .button : .staticText
        }
        let amount = UICollectionView.CellRegistration<SettingsAmountCell, SettingsRowID> { [weak self] cell, _, id in
            guard let model = self?.row(id), case .amount(let editText) = model.control else { return }
            cell.configure(model, editText: editText)
            cell.onEnd = { [weak self] text in self?.presenter?.amountEdited(id, text: text) }
        }
        let stepper = UICollectionView.CellRegistration<SettingsStepperCell, SettingsRowID> { [weak self] cell, _, id in
            guard let model = self?.row(id), case .stepper(let value, let minimum, let maximum) = model.control else { return }
            cell.configure(model, value: value, minimum: minimum, maximum: maximum)
            cell.onChange = { [weak self] value in self?.presenter?.stepperChanged(id, value: value) }
        }
        let time = UICollectionView.CellRegistration<SettingsTimeCell, SettingsRowID> { [weak self] cell, _, id in
            guard let model = self?.row(id), case .time(let minutes) = model.control else { return }
            cell.configure(model, minutes: minutes)
            cell.onChange = { [weak self] minutes in self?.presenter?.reviewTimeChanged(minutes: minutes) }
        }
        let appearance = UICollectionView.CellRegistration<SettingsAppearanceCell, SettingsRowID> { [weak self] cell, _, id in
            guard let model = self?.row(id), case .appearance(let mode) = model.control else { return }
            cell.configure(model, mode: mode)
            cell.onChange = { [weak self] mode in self?.presenter?.appearanceChanged(mode) }
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] view, path, id in
            switch self?.row(id)?.control {
            case .amount: view.dequeueConfiguredReusableCell(using: amount, for: path, item: id)
            case .stepper: view.dequeueConfiguredReusableCell(using: stepper, for: path, item: id)
            case .time: view.dequeueConfiguredReusableCell(using: time, for: path, item: id)
            case .appearance: view.dequeueConfiguredReusableCell(using: appearance, for: path, item: id)
            default: view.dequeueConfiguredReusableCell(using: plain, for: path, item: id)
            }
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] view, _, path in
            view.contentConfiguration = SettingsListStyle.header(self?.section(at: path.section)?.header)
        }
        let footer = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] view, _, path in
            view.contentConfiguration = SettingsListStyle.footer(self?.section(at: path.section)?.footer)
        }
        dataSource.supplementaryViewProvider = { [weak self] view, kind, path in
            switch kind {
            case Self.titleKind: return self?.dequeueTitle(in: view, at: path)
            case UICollectionView.elementKindSectionHeader: return view.dequeueConfiguredReusableSupplementary(using: header, for: path)
            default: return view.dequeueConfiguredReusableSupplementary(using: footer, for: path)
            }
        }
    }

    // MARK: SettingsViewProtocol

    func render(_ content: SettingsContent) {
        self.content = content
        title = content.title
        guard let dataSource else { return }
        var snapshot = NSDiffableDataSourceSnapshot<String, SettingsRowID>()
        for section in content.sections {
            snapshot.appendSections([section.id])
            snapshot.appendItems(section.rows.map(\.id), toSection: section.id)
        }
        if dataSource.snapshot().itemIdentifiers == snapshot.itemIdentifiers {
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func applyAppearance(_ mode: AppearanceMode) {
        mode.apply(to: view.window?.windowScene)
    }

    func playSaveFeedback() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return false }
        return row(id)?.control == .disclosure
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let id = dataSource.itemIdentifier(for: indexPath) else { return }
        presenter?.tapRow(id)
    }
}
