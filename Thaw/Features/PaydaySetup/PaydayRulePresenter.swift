import Foundation

/// The pushed payday-rule screen. Each change saves straight away; Back simply returns.
final class PaydayRulePresenter: PaydayRulePresenterProtocol, PaydaySetupInteractorOutput {
    private weak var view: PaydayRuleViewProtocol?
    private let interactor: PaydaySetupInteractorProtocol
    private var settings: PaydaySettings
    private var model: PaydayRuleModel

    // Explicit deinit: the synthesized one on a MainActor class with weak refs corrupts the heap in the test host.
    deinit {}

    init(view: PaydayRuleViewProtocol, interactor: PaydaySetupInteractorProtocol) {
        self.view = view
        self.interactor = interactor
        settings = interactor.settings
        model = PaydayRuleModel(rule: settings.rule)
    }

    func viewDidLoad() { render() }

    func settingsDidChange() {
        let latest = interactor.settings
        guard latest != settings else { return }
        settings = latest
        model = PaydayRuleModel(rule: latest.rule)
        render()
    }

    func selectRule(at index: Int) {
        guard model.select(at: index) else { return }
        save()
    }

    func dayChanged(_ value: Int) {
        guard model.setDay(value) else { return }
        save()
    }

    private func save() {
        settings.rule = model.rule
        interactor.save(settings, requestingPermission: false)
        render()
        view?.playSaveFeedback()
    }

    private func render() {
        view?.render(content)
    }

    var content: PaydayRuleContent {
        PaydayRuleContent(
            title: "Payday",
            options: PaydayRuleModel.Kind.allCases.map { option in
                PaydayRuleOptionViewModel(title: PaydayRuleModel.title(option), hint: model.shortHint(option),
                                          selected: option == model.kind)
            },
            day: model.dayViewModel,
            nextPaydayTitle: "Next payday",
            nextPayday: PaydayRuleModel.nextPaydayText(settings)
        )
    }
}
