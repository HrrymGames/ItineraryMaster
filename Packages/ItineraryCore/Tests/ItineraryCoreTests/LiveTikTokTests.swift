import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import ItineraryCore

/// Hits real TikTok pages with the same parser the app uses.
/// Only runs when LIVE_TIKTOK=1 (the "TikTok live check" workflow), so normal
/// test runs never depend on TikTok being up.
final class LiveTikTokTests: XCTestCase {
    let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LIVE_TIKTOK"] == "1", "Set LIVE_TIKTOK=1 to run")
    }

    private func load(_ url: URL) throws -> (String, URL) {
        var req = URLRequest(url: url)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.setValue("en-GB,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let done = expectation(description: "load")
        var result: (String, URL)?
        URLSession.shared.dataTask(with: req) { data, response, _ in
            if let data { result = (String(decoding: data, as: UTF8.self), response?.url ?? url) }
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: 30)
        return try XCTUnwrap(result)
    }

    func testKnownVideoParses() throws {
        let (html, _) = try load(URL(string: "https://www.tiktok.com/@scout2015/video/6718335390845095173")!)
        let item = try XCTUnwrap(TikTokPage.item(inHTML: html, preferredID: "6718335390845095173"))
        print("LIVE caption:", item.caption, "| author:", item.author ?? "-", "| cover:", item.coverURL?.prefix(60) ?? "-")
        XCTAssertFalse(item.caption.isEmpty)
        XCTAssertEqual(item.author, "scout2015")
        XCTAssertNotNil(item.coverURL)
    }

    func testPlaceholderUsernameWorks() throws {
        let post = TikTokLink.Post(username: nil, id: "6768504823336815877", isPhoto: false)
        let (html, _) = try load(post.canonicalURL)
        let item = try XCTUnwrap(TikTokPage.item(inHTML: html, preferredID: post.id))
        XCTAssertEqual(item.author, "zachking")
    }

    func testMissingPostIsRecognised() throws {
        let (html, _) = try load(URL(string: "https://www.tiktok.com/@_/video/1000000000000000001")!)
        XCTAssertNil(TikTokPage.item(inHTML: html, preferredID: "1000000000000000001"))
    }

    /// Extra links from the workflow input (e.g. real share links) are resolved and parsed.
    func testExtraLinks() throws {
        let links = (ProcessInfo.processInfo.environment["EXTRA_URLS"] ?? "").split(separator: " ").compactMap { URL(string: String($0)) }
        for link in links {
            let (html, final) = try load(link)
            let post = TikTokLink.post(in: link.absoluteString) ?? TikTokLink.post(in: final.absoluteString) ?? TikTokLink.post(inHTML: html)
            let item = TikTokPage.item(inHTML: html, preferredID: post?.id)
            print("LIVE \(link) -> final \(final) post \(post?.id ?? "nil") caption: \(item?.caption.prefix(80) ?? "nil")")
            XCTAssertNotNil(item, "No post found for \(link)")
        }
    }
}
