import UIKit

// Stub owned by the share-extension engineer (sprint 10); replaced with the real implementation.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        extensionContext?.cancelRequest(withError: NSError(domain: "ThawShare", code: 0))
    }
}
