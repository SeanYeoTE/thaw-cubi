import UIKit

final class ItemDetailViewController: ScrollStackViewController {
    private let store: WantStore
    private let reminders: Reminders
    private let want: Want

    init(store: WantStore, reminders: Reminders, want: Want) {
        self.store = store
        self.reminders = reminders
        self.want = want
        super.init(nibName: nil, bundle: nil)
        title = "Item detail"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func buildContent() {
        navigationItem.largeTitleDisplayMode = .never
        stack.spacing = 18
        let settings = store.effectiveSettings
        let isTimer = want.price < settings.timerThreshold
        let calendar = Calendar.current
        let daysLeft = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: want.thawsAt).day ?? 0)

        stack.addArrangedSubview(makeLabel(want.name, font: ThawFont.display(34)))
        stack.addArrangedSubview(makeLabel(
            "\(Formatting.sgd(want.price)) · frozen \(Formatting.paydayDate(want.frozenOn))",
            font: ThawFont.body(15), color: Theme.inkSecondary))

        let countdown = CardView()
        let days = makeLabel("\(daysLeft) \(daysLeft == 1 ? "day" : "days")", font: ThawFont.display(36))
        let until = makeLabel("\(isTimer ? "until it thaws" : "until payday") · \(Formatting.paydayDate(want.thawsAt))",
                              font: ThawFont.body(14), color: Theme.inkSecondary)
        let progress = ProgressBarView(fraction: CGFloat(want.progress), color: isTimer ? Theme.warm : Theme.accent)
        let countStack = UIStackView(arrangedSubviews: [days, until, progress])
        countStack.axis = .vertical
        countStack.spacing = 10
        pin(countStack, in: countdown, inset: 18)
        stack.addArrangedSubview(countdown)

        let reasonCard = CardView()
        let heading = makeLabel("Why you froze it", font: ThawFont.body(13, weight: .medium), color: Theme.inkSecondary)
        let quote = makeLabel("\u{201C}\(want.reason.isEmpty ? "No reason written." : want.reason)\u{201D}",
                              font: ThawFont.body(17))
        let reasonStack = UIStackView(arrangedSubviews: [heading, quote])
        reasonStack.axis = .vertical
        reasonStack.spacing = 8
        pin(reasonStack, in: reasonCard, inset: 18)
        stack.addArrangedSubview(reasonCard)

        let thaws = makeLabel(
            "Thaws · \(isTimer ? "Timer" : "Payday") · \(Formatting.paydayDate(want.thawsAt)) · \(Self.timeText(want.thawsAt))",
            font: ThawFont.body(14), color: Theme.inkSecondary)
        stack.addArrangedSubview(thaws)

        let wait = PillButton(title: "Wait one more payday", style: .secondary)
        wait.addAction(UIAction { [weak self] _ in self?.waitOnePayday() }, for: .touchUpInside)
        stack.addArrangedSubview(wait)

        let decide = PillButton(title: "Decide now", style: .quiet)
        decide.addAction(UIAction { [weak self] _ in self?.decideNow() }, for: .touchUpInside)
        stack.addArrangedSubview(decide)

        let skip = PillButton(title: "Skip it now", style: .quiet)
        skip.addAction(UIAction { [weak self] _ in self?.skip() }, for: .touchUpInside)
        stack.addArrangedSubview(skip)
    }

    private static func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date).lowercased()
    }

    private func decideNow() {
        let controller = StillWantItViewController(store: store, reminders: reminders, queue: [want])
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func waitOnePayday() {
        store.decide(id: want.id, keep: false)
        reminders.refresh(requestingPermission: false)
        navigationController?.popViewController(animated: true)
    }

    private func skip() {
        store.update(want.id, status: .skipped)
        reminders.refresh(requestingPermission: false)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let line = CubiMood.proudLine(amount: Formatting.sgd(want.price))
        navigationController?.setNavigationBarHidden(true, animated: true)
        MomentView.present(on: view, mood: .proud, line: line) { [weak self] in
            self?.navigationController?.setNavigationBarHidden(false, animated: false)
            self?.navigationController?.popViewController(animated: true)
        }
    }

    private func pin(_ inner: UIView, in card: CardView, inset: CGFloat) {
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -inset),
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: inset),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -inset),
        ])
    }
}
