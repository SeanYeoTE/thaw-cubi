import UIKit
import XCTest
@testable import Thaw

@MainActor
final class ThawColumnTests: XCTestCase {
    func testPhoneWidthKeepsScreenMargins() {
        let insets = ThawColumn.insets(containerWidth: 402, safeArea: .zero, top: 4, bottom: 8)
        XCTAssertEqual(insets.leading, Theme.Spacing.screen)
        XCTAssertEqual(insets.trailing, Theme.Spacing.screen)
        XCTAssertEqual(insets.top, 4)
        XCTAssertEqual(insets.bottom, 8)
    }

    func testPhoneLandscapeAddsSafeAreaToMargins() {
        let safe = UIEdgeInsets(top: 0, left: 59, bottom: 0, right: 59)
        let insets = ThawColumn.insets(containerWidth: 818, safeArea: safe)
        XCTAssertEqual(insets.leading, 59 + Theme.Spacing.screen)
        XCTAssertEqual(insets.trailing, 59 + Theme.Spacing.screen)
    }

    func testPadWidthCentresA700ptColumn() {
        let insets = ThawColumn.insets(containerWidth: 1032, safeArea: .zero)
        XCTAssertEqual(insets.leading, 166)
        XCTAssertEqual(1032 - insets.leading - insets.trailing, ThawColumn.maxWidth)
    }

    func testExtraInsetOnlyAppliesAboveTheColumn() {
        XCTAssertEqual(ThawColumn.extraInset(width: 402), 0)
        XCTAssertEqual(ThawColumn.extraInset(width: 700), 0)
        XCTAssertEqual(ThawColumn.extraInset(width: 1032), 166)
    }

    // MARK: Title alignment

    private static let widths: [(name: String, width: CGFloat, safeArea: UIEdgeInsets)] = [
        ("iPhone", 402, .zero),
        ("iPhone landscape", 874, UIEdgeInsets(top: 0, left: 62, bottom: 0, right: 62)),
        ("iPad", 1032, .zero),
        ("iPad Pro", 1376, .zero),
    ]

    func testTitleLinesUpWithPlainSections() {
        for size in Self.widths {
            let host = Host(width: size.width, safeArea: size.safeArea)
            let section = ThawColumn.insets(containerWidth: size.width, safeArea: host.view.safeAreaInsets)
            XCTAssertEqual(host.titleLeading(.plain), section.leading, accuracy: 0.5, size.name)
            XCTAssertEqual(host.titleTrailing(.plain), size.width - section.trailing, accuracy: 0.5, size.name)
        }
    }

    func testTitleLinesUpWithInsetGroupedCards() {
        for size in Self.widths {
            let host = Host(width: size.width, safeArea: size.safeArea)
            XCTAssertEqual(host.titleLeading(.insetGrouped), host.insetGroupedCardLeading(), accuracy: 0.5, size.name)
        }
    }

    func testListAppearanceIsReadFromTheSection() {
        let plain = NSCollectionLayoutSection(group: .vertical(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)),
            subitems: [NSCollectionLayoutItem(layoutSize: .init(
                widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)))]))
        plain.contentInsetsReference = .none
        XCTAssertEqual(ThawListViewController.appearance(of: plain), .plain)

        let host = Host(width: 402, safeArea: .zero)
        XCTAssertEqual(host.insetGroupedAppearance(), .insetGrouped)
    }

    /// A window-hosted screen, so safe areas and system list margins are real.
    @MainActor private final class Host {
        let window: UIWindow
        let controller = UIViewController()
        var view: UIView { controller.view }

        init(width: CGFloat, safeArea: UIEdgeInsets) {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 800))
            controller.additionalSafeAreaInsets = safeArea
            window.rootViewController = controller
            window.isHidden = false
            window.layoutIfNeeded()
        }

        deinit {}

        private func title(_ appearance: ThawListAppearance) -> UIView {
            let title = ThawListTitleView(frame: view.bounds)
            title.configure(text: "Cooling", insets: .standard, appearance: appearance)
            view.addSubview(title)
            title.layoutIfNeeded()
            return title.subviews[0]
        }

        func titleLeading(_ appearance: ThawListAppearance) -> CGFloat {
            title(appearance).frame.minX
        }

        func titleTrailing(_ appearance: ThawListAppearance) -> CGFloat {
            title(appearance).frame.maxX
        }

        private var lastSection: NSCollectionLayoutSection?
        private var dataSources: [AnyObject] = []

        private func insetGroupedList() -> UICollectionView {
            var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            configuration.headerMode = .none
            let layout = UICollectionViewCompositionalLayout { [weak self] _, environment in
                let section = ThawColumn.insetGroupedSection(configuration, environment: environment)
                self?.lastSection = section
                return section
            }
            let list = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
            let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { _, _, _ in }
            let dataSource = UICollectionViewDiffableDataSource<Int, Int>(collectionView: list) { list, indexPath, item in
                list.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
            }
            var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
            snapshot.appendSections([0])
            snapshot.appendItems([1])
            dataSource.apply(snapshot, animatingDifferences: false)
            dataSources.append(dataSource)
            view.addSubview(list)
            list.layoutIfNeeded()
            return list
        }

        func insetGroupedCardLeading() -> CGFloat {
            let list = insetGroupedList()
            return list.layoutAttributesForItem(at: IndexPath(item: 0, section: 0))?.frame.minX ?? -1
        }

        func insetGroupedAppearance() -> ThawListAppearance? {
            _ = insetGroupedList()
            return lastSection.map(ThawListViewController.appearance(of:))
        }
    }
}
