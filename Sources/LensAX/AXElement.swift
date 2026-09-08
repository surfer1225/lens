import ApplicationServices
import CoreGraphics
import Foundation

/// Thin, typed wrappers over the C Accessibility API.
///
/// The raw API deals in `CFTypeRef?` out-parameters and `AXError` returns; these helpers turn
/// that into optionals so the rest of `LensAX` reads like ordinary Swift.
extension AXUIElement {
    func value<T>(_ attribute: String, as _: T.Type = T.self) -> T? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &raw) == .success else {
            return nil
        }
        return raw as? T
    }

    func boolValue(_ attribute: String) -> Bool? {
        value(attribute, as: NSNumber.self)?.boolValue
    }

    /// Unwraps an attribute the API boxes in an `AXValue`.
    ///
    /// Not generic on purpose: `AXValueGetValue` writes through a raw pointer, so a generic `T`
    /// would let a type containing object references be filled in by memcpy.
    private func boxedValue(_ attribute: String) -> AXValue? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &raw) == .success,
              let raw, CFGetTypeID(raw) == AXValueGetTypeID()
        else { return nil }
        // The `as!` is sound and cannot be softened to `as?`: Swift rejects a conditional
        // downcast to a CoreFoundation type as always-succeeding. The real check is the
        // CFGetTypeID comparison in the guard above, which is the documented way to verify a
        // CFTypeRef before casting it.
        return (raw as! AXValue)
    }

    var position: CGPoint? {
        guard let boxed = boxedValue(kAXPositionAttribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(boxed, .cgPoint, &point) else { return nil }
        return point
    }

    var size: CGSize? {
        guard let boxed = boxedValue(kAXSizeAttribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(boxed, .cgSize, &size) else { return nil }
        return size
    }

    @discardableResult
    func setPosition(_ point: CGPoint) -> Bool {
        var point = point
        guard let boxed = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(self, kAXPositionAttribute as CFString, boxed) == .success
    }

    @discardableResult
    func setSize(_ size: CGSize) -> Bool {
        var size = size
        guard let boxed = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(self, kAXSizeAttribute as CFString, boxed) == .success
    }

    @discardableResult
    func setValue(_ attribute: String, _ value: Any) -> Bool {
        AXUIElementSetAttributeValue(self, attribute as CFString, value as CFTypeRef) == .success
    }

    func isSettable(_ attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(self, attribute as CFString, &settable) == .success
        else { return false }
        return settable.boolValue
    }
}

/// `_AXUIElementGetWindow` is the only way to map an `AXUIElement` to a `CGWindowID`, and Apple
/// has never made it public. Resolving it through `dlsym` keeps it out of the link line, so a
/// future macOS that drops the symbol degrades to the title-hash fallback in `AXWindow` instead
/// of failing to launch.
enum PrivateAX {
    private typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>)
        -> AXError

    private static let getWindow: GetWindow? = {
        // RTLD_DEFAULT — search every already-loaded image.
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow")
        else { return nil }
        return unsafeBitCast(symbol, to: GetWindow.self)
    }()

    /// The window's `CGWindowID`, or `nil` when the private symbol is unavailable.
    static func windowID(of element: AXUIElement) -> CGWindowID? {
        guard let getWindow else { return nil }
        var id: CGWindowID = 0
        guard getWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    static var isWindowIDAvailable: Bool { getWindow != nil }
}
