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
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "https://oauth2.googleapis.com/token")!, isMainFrame: true), .allow)
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "https://account.apple.com/sign-in")!, isMainFrame: true), .allow)
        XCTAssertEqual(URLClassifier.policy(for: URL(string: "https://login.microsoft.com/common")!, isMainFrame: true), .allow)
    }

    func testSecretsStayInsideTheApp() {
        let callback = URL(string: "https://x.com/home?code=sekret&q=swift")!
        let shared = URLClassifier.shareable(callback)
        XCTAssertEqual(shared?.host, "x.com")
        XCTAssertEqual(shared?.path, "/home")
        XCTAssertFalse(shared?.absoluteString.contains("sekret") ?? true)
        XCTAssertTrue(shared?.absoluteString.contains("q=swift") ?? false)

        let stored = URLClassifier.persisted(URL(string: "http://mobile.twitter.com/home?access_token=abc&q=1#frag")!)
        XCTAssertEqual(stored?.scheme, "https")
        XCTAssertEqual(stored?.host, "x.com")
        XCTAssertEqual(stored?.path, "/home")
        XCTAssertNil(stored?.fragment)
        XCTAssertFalse(stored?.absoluteString.contains("abc") ?? true)
        XCTAssertTrue(stored?.absoluteString.contains("q=1") ?? false)

        XCTAssertNil(URLClassifier.persisted(URL(string: "https://x.com/i/flow/login?code=abc")!))
        XCTAssertNil(URLClassifier.persisted(URL(string: "https://x.com/oauth/authorize?oauth_token=abc")!))
        XCTAssertNil(URLClassifier.persisted(URL(string: "https://x.com/logout")!))
        XCTAssertNil(URLClassifier.persisted(URL(string: "https://x.com/account/password_reset/SECRET123")!))
        XCTAssertNil(URLClassifier.persisted(URL(string: "https://x.com/account/verify/TOKEN123")!))
        XCTAssertNil(URLClassifier.persisted(URL(string: "https://example.com/home")!))
        XCTAssertNil(URLClassifier.shareable(URL(string: "javascript:alert(1)")!))
        XCTAssertNil(URLClassifier.shareable(URL(fileURLWithPath: "/etc/passwd")))

        let fragmentToken = URLClassifier.shareable(URL(string: "https://x.com/i/#access_token=abc")!)
        XCTAssertNil(fragmentToken?.fragment)
        XCTAssertTrue(fragmentToken?.path.hasPrefix("/i") ?? false)

        let withUser = URL(string: "https://user:pass@x.com/home")!
        XCTAssertNil(URLClassifier.shareable(withUser)?.user)
        XCTAssertFalse(URLClassifier.shareable(withUser)?.absoluteString.contains("pass") ?? true)

        XCTAssertEqual(URLClassifier.shareable(URL(string: "mailto:a@b.c")!)?.scheme, "mailto")

        let once = URLClassifier.persisted(URL(string: "https://x.com/home?q=swift")!)
        XCTAssertEqual(URLClassifier.persisted(once!), once)

        let navigated = URLClassifier.navigationTarget(URL(string: "https://user:pass@mobile.twitter.com/home?code=abc")!)
        XCTAssertEqual(navigated.scheme, "https")
        XCTAssertEqual(navigated.host, "x.com")
        XCTAssertNil(navigated.user)
        XCTAssertTrue(navigated.absoluteString.contains("code=abc"))
        XCTAssertFalse(navigated.absoluteString.contains("pass"))
    }

    func testDeviceAccessStaysOnX() {
        XCTAssertTrue(URLClassifier.mayCaptureMedia(host: "x.com"))
        XCTAssertTrue(URLClassifier.mayCaptureMedia(host: "mobile.twitter.com"))
        XCTAssertFalse(URLClassifier.mayCaptureMedia(host: "video.twimg.com"))
        XCTAssertFalse(URLClassifier.mayCaptureMedia(host: "accounts.google.com"))
        XCTAssertFalse(URLClassifier.mayCaptureMedia(host: ""))
        XCTAssertFalse(URLClassifier.mayCaptureMedia(host: "notx.com"))

        XCTAssertTrue(URLClassifier.mayOfferFilePicker(host: "x.com"))
        XCTAssertTrue(URLClassifier.mayOfferFilePicker(host: "twitter.com"))
        XCTAssertFalse(URLClassifier.mayOfferFilePicker(host: "video.twimg.com"))
        XCTAssertFalse(URLClassifier.mayOfferFilePicker(host: "accounts.google.com"))
        XCTAssertFalse(URLClassifier.mayOfferFilePicker(host: "evil.com"))

        XCTAssertTrue(URLClassifier.mayPresentPageDialog(host: "x.com"))
        XCTAssertTrue(URLClassifier.mayPresentPageDialog(host: "accounts.google.com", path: "/o/oauth2/auth"))
        XCTAssertFalse(URLClassifier.mayPresentPageDialog(host: "ads.example.com"))
        XCTAssertFalse(URLClassifier.mayPresentPageDialog(host: ""))

        XCTAssertFalse(URLClassifier.mayReadLocation(host: "x.com"))
        XCTAssertFalse(URLClassifier.mayReadLocation(host: "example.com"))
    }

    func testDownloadNames() {
        XCTAssertEqual(DownloadName.sanitize("photo.jpg"), "photo.jpg")
        XCTAssertEqual(DownloadName.sanitize("../etc/passwd"), "etcpasswd")
        XCTAssertEqual(DownloadName.sanitize("..secret"), "secret")
        XCTAssertEqual(DownloadName.sanitize(".hidden"), "hidden")
        XCTAssertEqual(DownloadName.sanitize("a/b\\c:d"), "abcd")
        XCTAssertEqual(DownloadName.sanitize("   "), "Download")
        XCTAssertEqual(DownloadName.sanitize("...\u{0000}ok.png"), "ok.png")
        XCTAssertEqual(DownloadName.sanitize("evil\u{202E}gpj.exe"), "evilgpj.exe")
        let long = String(repeating: "a", count: 300) + ".mp4"
        let sanitized = DownloadName.sanitize(long)
        XCTAssertLessThanOrEqual(sanitized.count, 180)
        XCTAssertTrue(sanitized.hasSuffix(".mp4"))
    }

    func testNotificationText() {
        XCTAssertEqual(
            PageEvent.parse(["type": "notify", "title": "Hi\u{0007}", "body": "There", "tag": "t"]),
            .notify(title: "Hi", body: "There", tag: "t")
        )
        let spoofed = PageEvent.parse(["type": "notify", "title": "\u{202E}evil", "body": "ok", "tag": ""])
        XCTAssertEqual(spoofed, .notify(title: "evil", body: "ok", tag: ""))
        let huge = String(repeating: "n", count: 500)
        let clipped = PageEvent.parse(["type": "notify", "title": huge, "body": "", "tag": huge])
        if case .notify(let title, _, let tag) = clipped {
            XCTAssertEqual(title.count, 120)
            XCTAssertEqual(tag.count, 80)
        } else {
            XCTFail("expected a notification")
        }
        XCTAssertNil(PageEvent.parse(["type": "notify", "title": " \n\t ", "body": ""]))
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
        // one unwrap is a link, a second one is a crash attempt
        XCTAssertNil(LinkIntent.destination(for: URL(string: "xmac://open?url=xmac://open?url=https://x.com/home")!))
        XCTAssertNil(LinkIntent.destination(for: URL(string: "xmac://open?url=" + String(repeating: "a", count: 2_001))!))
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
        XCTAssertNil(URLClassifier.classify(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        XCTAssertNil(URLClassifier.classify(NSError(domain: "WebKitErrorDomain", code: 102)))
        XCTAssertNil(URLClassifier.classify(NSError(domain: "WebKitErrorDomain", code: 204)))
        XCTAssertEqual(URLClassifier.classify(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)), .timedOut)
        XCTAssertEqual(URLClassifier.classify(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)), .offline)
        XCTAssertEqual(URLClassifier.classify(NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)), .offline)
        XCTAssertEqual(URLClassifier.classify(NSError(domain: NSURLErrorDomain, code: NSURLErrorDNSLookupFailed)), .unreachable)
        XCTAssertEqual(URLClassifier.classify(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost)), .unreachable)
        XCTAssertEqual(URLClassifier.classify(NSError(domain: "AnythingElse", code: 7)), .generic)
    }

    private func assertX(_ url: URL?, path: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(url?.scheme, "https", file: file, line: line)
        XCTAssertEqual(url?.host, "x.com", file: file, line: line)
        XCTAssertEqual(url?.path, path, file: file, line: line)
    }
}
