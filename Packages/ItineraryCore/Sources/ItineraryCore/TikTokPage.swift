import Foundation

/// What we can read from a TikTok post page without an API key.
public struct TikTokItem: Equatable, Sendable {
    public var id: String
    public var caption: String
    public var author: String?
    public var coverURL: String?
    public var isPhoto: Bool

    public init(id: String, caption: String, author: String?, coverURL: String?, isPhoto: Bool) {
        self.id = id
        self.caption = caption
        self.author = author
        self.coverURL = coverURL
        self.isPhoto = isPhoto
    }
}

/// Parses the JSON TikTok embeds in every post page
/// (`<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__">`). Its oEmbed endpoint
/// no longer returns captions or thumbnails, but this data block does.
public enum TikTokPage {
    static let scriptIDs = ["__UNIVERSAL_DATA_FOR_REHYDRATION__", "SIGI_STATE", "__NEXT_DATA__"]

    /// The embedded JSON object, if the page has one.
    public static func embeddedJSON(in html: String) -> Any? {
        for id in scriptIDs {
            let pattern = "<script[^>]*id=[\"']\(id)[\"'][^>]*>(.*?)</script>"
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { continue }
            let ns = html as NSString
            guard let m = re.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) else { continue }
            let body = ns.substring(with: m.range(at: 1))
            if let obj = try? JSONSerialization.jsonObject(with: Data(body.utf8)) { return obj }
        }
        return nil
    }

    /// Finds the post in a page. Prefers the item whose id matches `preferredID`,
    /// then any object stored under an `itemStruct` key.
    public static func item(inHTML html: String, preferredID: String? = nil) -> TikTokItem? {
        if let json = embeddedJSON(in: html), let found = item(inJSON: json, preferredID: preferredID) {
            return found
        }
        // Last resort: Open Graph tags (some regions serve these instead).
        let info = TikTokLink.pageInfo(inHTML: html)
        if let caption = info.caption, !caption.isEmpty, let post = TikTokLink.post(inHTML: html) ?? preferredID.map({ TikTokLink.Post(username: nil, id: $0, isPhoto: false) }) {
            return TikTokItem(id: post.id, caption: caption, author: post.username, coverURL: info.imageURL, isPhoto: post.isPhoto)
        }
        return nil
    }

    public static func item(inJSON json: Any, preferredID: String? = nil) -> TikTokItem? {
        var candidates: [(dict: [String: Any], underItemStruct: Bool)] = []
        collect(json, parentKey: nil, into: &candidates)
        let chosen = candidates.first { c in preferredID != nil && idString(c.dict["id"]) == preferredID }
            ?? candidates.first { $0.underItemStruct }
        guard let d = chosen?.dict, let id = idString(d["id"]) else { return nil }

        let caption = (d["desc"] as? String) ?? ""
        var author: String?
        if let a = d["author"] as? [String: Any] {
            author = (a["uniqueId"] as? String) ?? (a["unique_id"] as? String)
        } else if let a = d["author"] as? String {
            author = a
        }

        var cover: String?
        var isPhoto = false
        if let image = d["imagePost"] as? [String: Any] {
            isPhoto = true
            cover = firstImageURL(image["cover"])
            if cover == nil, let images = image["images"] as? [Any], let first = images.first {
                cover = firstImageURL(first)
            }
        }
        if cover == nil, let v = d["video"] as? [String: Any] {
            cover = ["cover", "originCover", "dynamicCover", "shareCover", "zoomCover"].lazy
                .compactMap { key -> String? in
                    if let s = v[key] as? String, !s.isEmpty { return s }
                    if let list = v[key] as? [String] { return list.first }
                    return nil
                }.first
        }
        return TikTokItem(id: id, caption: caption, author: author, coverURL: cover, isPhoto: isPhoto)
    }

    private static func collect(_ o: Any, parentKey: String?, into out: inout [(dict: [String: Any], underItemStruct: Bool)]) {
        if let d = o as? [String: Any] {
            if d["desc"] is String, idString(d["id"]) != nil, d["video"] != nil || d["imagePost"] != nil || d["author"] != nil {
                out.append((d, parentKey == "itemStruct"))
            }
            for (k, v) in d { collect(v, parentKey: k, into: &out) }
        } else if let a = o as? [Any] {
            for v in a { collect(v, parentKey: parentKey, into: &out) }
        }
    }

    private static func idString(_ v: Any?) -> String? {
        if let s = v as? String, !s.isEmpty { return s }
        if let n = v as? Int { return String(n) }
        if let n = v as? Int64 { return String(n) }
        if let n = v as? UInt64 { return String(n) }
        if let n = v as? NSNumber { return n.stringValue }
        return nil
    }

    private static func firstImageURL(_ v: Any?) -> String? {
        guard let d = v as? [String: Any] else { return nil }
        if let u = d["imageURL"] as? [String: Any], let list = u["urlList"] as? [String] { return list.first }
        if let list = d["urlList"] as? [String] { return list.first }
        return nil
    }

    /// True when the page loaded fine but holds no post (deleted, private, or region-locked).
    public static func looksLikeMissingPost(_ html: String) -> Bool {
        embeddedJSON(in: html) != nil && item(inHTML: html) == nil
    }
}
