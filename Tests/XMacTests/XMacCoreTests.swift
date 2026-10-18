import XCTest
import XMacCore

final class XMacCoreTests: XCTestCase {
    func testBadgeCount() {
        XCTAssertEqual(URLClassifier.badgeCount(from: "(3) Home / X"), 3)
        XCTAssertEqual(URLClassifier.badgeCount(from: "(99+) X"), 99)
        XCTAssertEqual(URLClassifier.badgeCount(from: "Home / X"), 0)
        XCTAssertEqual(URLClassifier.badgeCount(from: ""), 0)
        XCTAssertEqual(URLClassifier.badgeCount(from: "(nope) X"), 0)
        XCTAssertEqual(URLClassifier.badgeCount(from: "  (12) Mitteilungen / X"), 12)
    }

    func testHosts() {
        XCTAssertTrue(URLClassifier.isXFamily(host: "x.com"))
        XCTAssertTrue(URLClassifier.isXFamily(host: "www.x.com"))
        XCTAssertTrue(URLClassifier.isXFamily(host: "video.twimg.com"))
        XCTAssertTrue(URLClassifier.isXFamily(host: "t.co"))
        XCTAssertTrue(URLClassifier.isXFamily(host: "mobile.twitter.com"))
        XCTAssertFalse(URLClassifier.isXFamily(host: "notx.com"))
        XCTAssertFalse(URLClassifier.isXFamily(host: "x.com.evil.com"))
        XCTAssertFalse(URLClassifier.isXFamily(host: "example.com"))
    }

    func testRewrite() {
        let rewritten = URLClassifier.rewriteToX(URL(string: "http://mobile.twitter.com/jack")!)
        XCTAssertEqual(rewritten.scheme, "https")
        XCTAssertEqual(rewritten.host, "x.com")
        XCTAssertEqual(rewritten.path, "/jack")
    }

    func testPolicy() {
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "https://nytimes.com/a")!, isMainFrame: true), .openExternally)
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "https://nytimes.com/a")!, isMainFrame: false), .allow)
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "https://x.com/home")!, isMainFrame: true), .allow)
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "https://t.co/abc")!, isMainFrame: true), .allow)
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "mailto:a@b.c")!, isMainFrame: true), .openExternally)
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "javascript:alert(1)")!, isMainFrame: true), .cancel)
        XCTAssertEqual(URLClassifier.policy(for: URL(fileURLWithPath: "/etc/passwd"), isMainFrame: true), .cancel)
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "https://accounts.google.com/o/oauth2/auth")!, isMainFrame: true), .allow)
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "https://www.google.com/search?q=x")!, isMainFrame: true), .openExternally)
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "https://www.google.com/signin/v2")!, isMainFrame: true), .allow)
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "https://challenges.cloudflare.com/cdn-cgi/challenge")!, isMainFrame: true), .allow)
    }

    func testSearchAndRoutes() {
        let search = URLClassifier.searchURL(query: "a b")
        let query = URLComponents(url: search, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "q" }?.value
        XCTAssertEqual(query, "a b")
        XCTAssertEqual(search.host, "x.com")

        XCTAssertEqual(AppRoute.match(URL(string: "https://x.com/home")!), .home)
        XCTAssertEqual(AppRoute.match(URL(string: "https://x.com/notifications/mentions")!), .notifications)
        XCTAssertEqual(AppRoute.match(URL(string: "https://x.com/i/bookmarks")!), .bookmarks)
        XCTAssertEqual(AppRoute.match(URL(string: "https://x.com/jack")!), nil)
        XCTAssertEqual(AppRoute.match(URL(string: "https://x.com/i/grok")!), .grok)
        XCTAssertEqual(AppRoute.match(URL(string: "https://x.com/search?q=swift")!), .explore)
    }

    func testLinkIntents() {
        assertX(LinkIntent.destination(for: URL(string: "twitter://status?id=1234567890")!), path: "/i/status/1234567890")
        assertX(LinkIntent.destination(for: URL(string: "twitter://user?screen_name=jack")!), path: "/jack")
        assertX(LinkIntent.destination(for: URL(string: "https://mobile.twitter.com/home")!), path: "/home")
        assertX(LinkIntent.destination(for: URL(string: "xmac://messages")!), path: "/messages")
        assertX(LinkIntent.destination(for: URL(string: "twitter://mentions")!), path: "/notifications/mentions")
        XCTAssertNil(LinkIntent.destination(for: URL(string: "https://example.com/a")!))
        XCTAssertNil(LinkIntent.destination(for: URL(string: "twitter://user?screen_name=../../etc")!))
        XCTAssertNil(LinkIntent.destination(for: URL(string: "twitter://status?id=nope")!))

        let compose = LinkIntent.destination(for: URL(string: "twitter://post?message=Hi%20there")!)
        let text = URLComponents(url: compose!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "text" }?.value
        XCTAssertEqual(compose?.host, "x.com")
        XCTAssertEqual(compose?.path, "/compose/post")
        XCTAssertEqual(text, "Hi there")

        let opened = LinkIntent.destination(for: URL(string: "xmac://open?url=https://x.com/explore")!)
        assertX(opened, path: "/explore")
        XCTAssertNil(LinkIntent.destination(for: URL(string: "xmac://open?url=https://example.com")!))
    }

    func testPageEvents() {
        XCTAssertEqual(PageEvent.parse(["type": "title", "title": "(2) X"]), .title("(2) X"))
        XCTAssertEqual(
            PageEvent.parse(["type": "notify", "title": "Ada", "body": "Hi", "tag": "t1"]),
            .notify(title: "Ada", body: "Hi", tag: "t1")
        )
        XCTAssertNil(PageEvent.parse(["type": "notify", "title": "  ", "body": ""]))
        XCTAssertNil(PageEvent.parse("nope"))
    }

    func testNavigationErrors() {
        XCTAssertNil(URLClassifier.navigationErrorMessage(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        XCTAssertNil(URLClassifier.navigationErrorMessage(NSError(domain: "WebKitErrorDomain", code: 102)))
        XCTAssertNotNil(URLClassifier.navigationErrorMessage(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)))
    }

    private func assertX(_ url: URL?, path: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(url?.scheme, "https", file: file, line: line)
        XCTAssertEqual(url?.host, "x.com", file: file, line: line)
        XCTAssertEqual(url?.path, path, file: file, line: line)
    }
}
