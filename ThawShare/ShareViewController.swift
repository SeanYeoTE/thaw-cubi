import UIKit
import UniformTypeIdentifiers

/// Principal class of the share extension: reads the shared page, then hosts the AddWant form.
final class ShareViewController: UIViewController {
    private var finished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        var input = ShareItemParser.Input(
            title: items.lazy.compactMap { $0.attributedTitle?.string }.first,
            contentText: items.lazy.compactMap { $0.attributedContentText?.string }.first
        )
        let providers = items.flatMap { $0.attachments ?? [] }
        Task {
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = await Self.load(URL.self, from: provider) { input.urls.append(url) }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = await Self.load(String.self, from: provider) { input.texts.append(text) }
                }
            }
            showForm(ShareItemParser.parse(input))
        }
    }

    private func showForm(_ result: ShareItemParser.Result) {
        let form = ShareAddRouter.createModule(host: self, draft: AddWantDraft(name: result.name, link: result.link))
        addChild(form)
        form.view.frame = view.bounds
        form.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(form.view)
        form.didMove(toParent: self)
    }

    /// Completes the request after a save (the Cubi moment has already shown); otherwise cancels it.
    func finish(saved: Bool) {
        guard !finished else { return }
        finished = true
        if saved {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        } else {
            extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
        }
    }

    private static func load<T: _ObjectiveCBridgeable & Sendable>(_ type: T.Type, from provider: NSItemProvider) async -> T?
        where T._ObjectiveCType: NSItemProviderReading {
        guard provider.canLoadObject(ofClass: type) else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: type) { value, _ in continuation.resume(returning: value) }
        }
    }
}
