import UIKit

final class SettingsViewController: ScrollStackViewController {
    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Settings"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        stack.addArrangedSubview(makeLabel("Payday setup arrives in sprint 2.", font: ThawFont.body(16), color: Theme.inkSecondary))
    }
}
