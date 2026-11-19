import XCTest
import WebKit
@testable import XMac

/// The autoplay toggle rebuilds the web view under a new SwiftUI identity: the new
/// view attaches while the old one is dismantled. The old view's dismantle must not
/// detach the model the replacement just bound. Found live: the toggle blanked the window.
@MainActor
final class WebViewLifecycleTests: XCTestCase {
    func testDetachOnlyRemovesTheCurrentView() async {
        let model = WebModel()
        let first = WKWebView()
        let second = WKWebView()

        model.attach(first)
        model.attach(second)

        // Old view dismantled after the replacement attached: a no-op,
        // through the real dismantle path (its detach lands in a Task).
        let coordinator = WebCoordinator(model: model)
        XWebView.dismantleNSView(first, coordinator: coordinator)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertIdentical(model.webView, second)

        // The window closes with its current view: a real detach.
        model.detachIfCurrent(second)
        XCTAssertNil(model.webView)
    }

    func testDetachOfNilIsSafeWithoutAView() {
        let model = WebModel()
        model.detachIfCurrent(nil)
        XCTAssertNil(model.webView)
    }
}
