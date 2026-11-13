import UIKit

/// The 700 pt content column shared by every screen: capped and centred on wide screens, with at least
/// `Theme.Spacing.screen` plus the safe area on each side.
enum ThawColumn {
    static let maxWidth: CGFloat = 700

    /// Side inset for content of `availableWidth` (the container width minus the safe area on both sides).
    static func sideInset(availableWidth: CGFloat) -> CGFloat {
        max(Theme.Spacing.screen, (availableWidth - maxWidth) / 2)
    }

    /// Extra inset an inset-grouped list needs on each side, on top of its own margins, to stay within the column.
    static func extraInset(width: CGFloat) -> CGFloat {
        max(0, (width - maxWidth) / 2)
    }

    /// Section insets for a plain list section. Use with `contentInsetsReference = .none`.
    static func insets(
        containerWidth: CGFloat, safeArea: UIEdgeInsets, top: CGFloat = 0, bottom: CGFloat = 0
    ) -> NSDirectionalEdgeInsets {
        let side = sideInset(availableWidth: containerWidth - safeArea.left - safeArea.right)
        return NSDirectionalEdgeInsets(top: top, leading: safeArea.left + side, bottom: bottom, trailing: safeArea.right + side)
    }

    /// Width of the title text, so its leading edge lines up with the cards. Plain sections fill the 700 pt
    /// column; inset-grouped cards sit the list's own margin (`listMargin`) inside it.
    static func titleWidth(for appearance: ThawListAppearance, listMargin: CGFloat = Theme.Spacing.screen) -> CGFloat {
        switch appearance {
        case .plain: maxWidth
        case .insetGrouped: maxWidth - 2 * listMargin
        }
    }

    /// Smallest gap between the safe area and the title, matching where the cards start on narrow screens.
    static func titleMargin(for appearance: ThawListAppearance, listMargin: CGFloat) -> CGFloat {
        switch appearance {
        case .plain: Theme.Spacing.screen
        case .insetGrouped: listMargin
        }
    }

    /// Inset-grouped list section, capped to the column on wide screens.
    static func insetGroupedSection(
        _ configuration: UICollectionLayoutListConfiguration, environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        let section = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
        let extra = extraInset(width: environment.container.effectiveContentSize.width)
        section.contentInsets.leading += extra
        section.contentInsets.trailing += extra
        return section
    }

    /// The system margin an inset-grouped section from `insetGroupedSection` puts before its cards
    /// (16 pt on iPhone, 20 pt on iPad), without the extra column inset or the safe area, which the list bakes in.
    static func cardMargin(of section: NSCollectionLayoutSection, environment: NSCollectionLayoutEnvironment,
                           safeAreaLeading: CGFloat) -> CGFloat {
        section.contentInsets.leading - extraInset(width: environment.container.effectiveContentSize.width) - safeAreaLeading
    }
}

/// How a list screen lays out its sections, which decides where its title starts.
enum ThawListAppearance {
    /// Sections use `ThawColumn.insets` with `contentInsetsReference = .none`.
    case plain
    /// Sections use `ThawColumn.insetGroupedSection`, whose cards follow the list's layout margins.
    case insetGrouped
}

/// The large screen title, drawn by the screen because the system one stays blank over a collection view until
/// the first scroll. Header trait and Dynamic Type included.
final class ThawScreenTitleLabel: UILabel {
    init(text: String? = nil) {
        super.init(frame: .zero)
        self.text = text
        font = ThawFont.display(36)
        textColor = Theme.ink
        numberOfLines = 0
        adjustsFontForContentSizeCategory = true
        accessibilityTraits = .header
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// The title as a boundary supplementary view: aligned with the list's cards and capped to the column.
final class ThawListTitleView: UICollectionReusableView {
    private let label = ThawScreenTitleLabel()
    private var top: NSLayoutConstraint!
    private var bottom: NSLayoutConstraint!
    private var width: NSLayoutConstraint!
    private var leading: NSLayoutConstraint!
    private var trailing: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        width = label.widthAnchor.constraint(equalToConstant: ThawColumn.titleWidth(for: .plain))
        width.priority = .defaultHigh
        top = label.topAnchor.constraint(equalTo: topAnchor)
        bottom = label.bottomAnchor.constraint(equalTo: bottomAnchor)
        leading = label.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: Theme.Spacing.screen)
        trailing = label.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -Theme.Spacing.screen)
        // Centred in the safe area, like the sections, so landscape stays aligned too.
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor),
            leading, trailing, width, top, bottom,
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(text: String, insets: ThawListTitleInsets, appearance: ThawListAppearance = .plain,
                   listMargin: CGFloat = Theme.Spacing.screen) {
        label.text = text
        width.constant = ThawColumn.titleWidth(for: appearance, listMargin: listMargin)
        let margin = ThawColumn.titleMargin(for: appearance, listMargin: listMargin)
        leading.constant = margin
        trailing.constant = -margin
        top.constant = insets.top
        bottom.constant = -insets.bottom
    }
}

struct ThawListTitleInsets {
    var top: CGFloat
    var bottom: CGFloat

    static let standard = ThawListTitleInsets(top: 8, bottom: 12)
}

/// Base for the list tabs (Cooling, Stats, Settings): a collection view that draws its own large title as a
/// boundary supplementary view, so the title needs no fake item in the data source. Subclasses provide the
/// section layout and the data source, and call `dequeueTitle` for `ThawListViewController.titleKind`.
class ThawListViewController: UIViewController {
    static let titleKind = "thaw.list.title"

    private(set) var collectionView: UICollectionView!

    /// Space around the title text. Screens override it to keep their own rhythm.
    var titleInsets: ThawListTitleInsets { .standard }

    /// How the sections are laid out, so the title lines up with their cards. Inset-grouped screens override it.
    var listAppearance: ThawListAppearance { .plain }

    /// Inset-grouped card margin, read from the first section's layout.
    private var listMargin: CGFloat = Theme.Spacing.screen

    /// Where the list ends. Settings overrides it to stop above the keyboard.
    var listBottomAnchor: NSLayoutYAxisAnchor { view.bottomAnchor }

    /// The screen title is drawn in the list, so the navigation bar's own stays empty.
    override var title: String? {
        didSet { navigationItem.title = "" }
    }

    // Created up front: UIKit rejects a registration first created while dequeuing.
    private var titleRegistration: UICollectionView.SupplementaryRegistration<ThawListTitleView>!

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    /// Layout for one section. Called by the compositional layout.
    func sectionLayout(at index: Int, environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = ""
        // A hidden keyboard keeps the guide at the view's bottom edge.
        view.keyboardLayoutGuide.usesBottomSafeArea = false

        titleRegistration = UICollectionView.SupplementaryRegistration<ThawListTitleView>(
            elementKind: Self.titleKind
        ) { [weak self] view, _, _ in
            guard let self else { return }
            view.configure(text: self.title ?? "", insets: self.titleInsets, appearance: self.listAppearance,
                           listMargin: self.listMargin)
        }

        let titleItem = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(64)),
            elementKind: Self.titleKind, alignment: .top)
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.boundarySupplementaryItems = [titleItem]
        let layout = UICollectionViewCompositionalLayout(sectionProvider: { [weak self] index, environment in
            guard let self else { return nil }
            let section = self.sectionLayout(at: index, environment: environment)
            if index == 0, self.listAppearance == .insetGrouped, let section {
                self.listMargin = ThawColumn.cardMargin(of: section, environment: environment,
                                                        safeAreaLeading: self.collectionView?.safeAreaInsets.left ?? 0)
            }
            return section
        }, configuration: configuration)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = Theme.background
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .interactive
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: listBottomAnchor),
        ])
    }

    func dequeueTitle(in collectionView: UICollectionView, at indexPath: IndexPath) -> UICollectionReusableView {
        collectionView.dequeueConfiguredReusableSupplementary(using: titleRegistration, for: indexPath)
    }

    /// Nav bar trailing items, such as Cooling's sort and add buttons.
    func setTrailingBarItems(_ items: [UIBarButtonItem]) {
        navigationItem.rightBarButtonItems = items
    }

    /// Insets for a plain section in the 700 pt column. Use with `contentInsetsReference = .none`.
    func columnInsets(
        environment: NSCollectionLayoutEnvironment, top: CGFloat = 0, bottom: CGFloat = 0
    ) -> NSDirectionalEdgeInsets {
        ThawColumn.insets(
            containerWidth: environment.container.contentSize.width, safeArea: collectionView?.safeAreaInsets ?? .zero,
            top: top, bottom: bottom)
    }
}

extension ThawListViewController {
    /// Serves the title for data sources that have no other supplementary views.
    func installTitle<Section: Hashable & Sendable, Item: Hashable & Sendable>(
        on dataSource: UICollectionViewDiffableDataSource<Section, Item>
    ) {
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self, kind == Self.titleKind else { return nil }
            return self.dequeueTitle(in: collectionView, at: indexPath)
        }
    }
}

extension UICollectionViewListCell {
    /// Clears what a previous use left behind: content, background and accessibility state.
    func resetForReuse() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        backgroundConfiguration = .clear()
        isAccessibilityElement = false
        accessibilityIdentifier = nil
        accessibilityTraits = []
        accessibilityLabel = nil
        accessibilityValue = nil
        accessibilityHint = nil
        accessibilityCustomActions = nil
    }

    /// Pins `inner` to the content view with the given vertical gaps.
    func embed(_ inner: UIView, top: CGFloat = 0, bottom: CGFloat = 0) {
        inner.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            inner.topAnchor.constraint(equalTo: contentView.topAnchor, constant: top),
            inner.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -bottom),
        ])
    }
}
