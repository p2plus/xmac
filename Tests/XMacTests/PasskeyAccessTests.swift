import XCTest
import XMacCore

final class PasskeyAccessTests: XCTestCase {
    func testAsksOnceForAnXPage() {
        let home = URL(string: "https://x.com/home")
        XCTAssertTrue(PasskeyAccess.shouldRequest(url: home, authorization: .notDetermined, alreadyAsked: false))
        XCTAssertFalse(PasskeyAccess.shouldRequest(url: home, authorization: .notDetermined, alreadyAsked: true))
        XCTAssertFalse(PasskeyAccess.shouldRequest(url: home, authorization: .authorized, alreadyAsked: false))
        XCTAssertFalse(PasskeyAccess.shouldRequest(url: home, authorization: .denied, alreadyAsked: false))
    }

    func testSkipsOtherSitesAndInsecurePages() {
        XCTAssertTrue(PasskeyAccess.shouldRequest(
            url: URL(string: "https://mobile.twitter.com/i/flow/login"),
            authorization: .notDetermined,
            alreadyAsked: false
        ))
        XCTAssertFalse(PasskeyAccess.shouldRequest(
            url: URL(string: "https://example.com/login"),
            authorization: .notDetermined,
            alreadyAsked: false
        ))
        XCTAssertFalse(PasskeyAccess.shouldRequest(
            url: URL(string: "https://notx.com/"),
            authorization: .notDetermined,
            alreadyAsked: false
        ))
        XCTAssertFalse(PasskeyAccess.shouldRequest(
            url: URL(string: "http://x.com/home"),
            authorization: .notDetermined,
            alreadyAsked: false
        ))
        XCTAssertFalse(PasskeyAccess.shouldRequest(
            url: URL(string: "https://accounts.google.com/"),
            authorization: .notDetermined,
            alreadyAsked: false
        ))
        XCTAssertFalse(PasskeyAccess.shouldRequest(url: nil, authorization: .notDetermined, alreadyAsked: false))
    }
}
