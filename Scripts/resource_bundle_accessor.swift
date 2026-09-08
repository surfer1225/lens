// Stands in for the accessor SwiftPM generates for a target that carries resources.
// KeyboardShortcuts localises its recorder strings via `NSLocalizedString(_:bundle: .module)`.
//
// Unlike SwiftPM's version this falls back to the main bundle instead of calling fatalError:
// a missing resource bundle should cost us localisation, not launch the app into a crash.
import Foundation

extension Foundation.Bundle {
    static let module: Bundle = {
        let bundleName = "KeyboardShortcuts_KeyboardShortcuts"

        let candidates = [
            Bundle.main.resourceURL,
            Bundle(for: BundleFinder.self).resourceURL,
            Bundle.main.bundleURL,
        ]

        for case let candidate? in candidates {
            let url = candidate.appendingPathComponent(bundleName + ".bundle")
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return Bundle.main
    }()
}

private final class BundleFinder {}
