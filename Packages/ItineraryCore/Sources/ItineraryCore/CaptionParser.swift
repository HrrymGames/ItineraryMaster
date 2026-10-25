import Foundation

/// What a saved TikTok is mostly about.
public enum VideoCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case itinerary
    case packing
    case activities
    case accommodation
    case work
    case budget
    case food
    case transport
    case tips
    case visa

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .itinerary: return "Itinerary"
        case .packing: return "Packing"
        case .activities: return "Activities"
        case .accommodation: return "Stay"
        case .work: return "Work & volunteer"
        case .budget: return "Budget"
        case .food: return "Food"
        case .transport: return "Transport"
        case .tips: return "Tips"
        case .visa: return "Visa & docs"
        }
    }

    public var symbol: String {
        switch self {
        case .itinerary: return "map.fill"
        case .packing: return "backpack.fill"
        case .activities: return "figure.hiking"
        case .accommodation: return "bed.double.fill"
        case .work: return "hands.sparkles.fill"
        case .budget: return "sterlingsign.circle.fill"
        case .food: return "fork.knife"
        case .transport: return "bus.fill"
        case .tips: return "lightbulb.fill"
        case .visa: return "doc.text.fill"
        }
    }

    /// Lower-case keywords. Multi-word phrases are matched as phrases; single
    /// words are matched at word boundaries and inside hashtags.
    public var keywords: [String] {
        switch self {
        case .itinerary:
            return ["itinerary", "route", "days in", "weeks in", "week in", "day 1", "day one",
                    "travel guide", "guide to", "where to go", "places to visit", "must visit",
                    "bucket list", "backpacking route", "how to spend", "plan", "roadtrip", "road trip"]
        case .packing:
            return ["packing", "pack with me", "what i pack", "packing list", "essentials", "carry on",
                    "carryon", "backpack", "must have", "must-have", "amazon", "travel gadgets", "gear",
                    "toiletries", "luggage", "packing cubes", "items", "products", "bring"]
        case .activities:
            return ["things to do", "activities", "activity", "tour", "tours", "hike", "hiking", "trek",
                    "trekking", "snorkel", "snorkelling", "snorkeling", "diving", "scuba", "surf", "surfing",
                    "kayak", "waterfall", "island hopping", "excursion", "day trip", "viewpoint", "sunrise",
                    "sunset", "temple", "beach", "national park", "safari", "climb", "bungee", "skydive"]
        case .accommodation:
            return ["hostel", "hostels", "hotel", "airbnb", "stay", "where to stay", "accommodation",
                    "guesthouse", "homestay", "dorm", "bungalow", "camping", "resort", "booking.com", "hostelworld"]
        case .work:
            return ["volunteer", "volunteering", "worldpackers", "workaway", "work exchange", "work for accommodation",
                    "working holiday", "work and travel", "job", "jobs", "wwoof", "helpx", "teach english", "tefl",
                    "au pair", "seasonal work", "remote work", "digital nomad", "visa sponsorship"]
        case .budget:
            return ["budget", "cost", "costs", "price", "prices", "cheap", "how much", "spent", "spend",
                    "money", "per day", "a day", "affordable", "save money", "saving", "expensive", "free"]
        case .food:
            return ["food", "eat", "eats", "restaurant", "street food", "cafe", "coffee", "brunch",
                    "must try", "dish", "market", "night market", "foodie", "vegan", "dinner", "lunch"]
        case .transport:
            return ["bus", "train", "flight", "flights", "ferry", "sleeper", "scooter", "motorbike", "grab",
                    "uber", "taxi", "tuk tuk", "tuktuk", "transport", "getting around", "border crossing", "12go", "rome2rio"]
        case .tips:
            return ["tips", "tip", "hack", "hacks", "mistakes", "avoid", "scam", "scams", "things i wish",
                    "know before", "advice", "don't", "dont", "never", "safety", "solo female", "first time"]
        case .visa:
            return ["visa", "visas", "passport", "evisa", "e-visa", "entry requirements", "esta", "eta",
                    "immigration", "vaccine", "vaccination", "insurance", "documents"]
        }
    }
}

/// A place the parser can recognise.
public struct GazetteerEntry: Codable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case country, city }
    public var name: String
    public var countryCode: String
    public var kind: Kind
    public var latitude: Double?
    public var longitude: Double?
    public var aliases: [String]

    public init(name: String, countryCode: String, kind: Kind, latitude: Double? = nil, longitude: Double? = nil, aliases: [String] = []) {
        self.name = name
        self.countryCode = countryCode
        self.kind = kind
        self.latitude = latitude
        self.longitude = longitude
        self.aliases = aliases
    }
}

public struct PlaceMatch: Codable, Equatable, Hashable, Sendable {
    public var name: String
    public var countryCode: String
    public var kind: GazetteerEntry.Kind
    public var latitude: Double?
    public var longitude: Double?
}

public struct CaptionAnalysis: Codable, Equatable, Sendable {
    public var categories: [VideoCategory]
    public var hashtags: [String]
    public var places: [PlaceMatch]
    public var prices: [Money]
    public var packingItems: [String]
    public var durationDays: Int?
    /// A short human title made from the caption.
    public var title: String

    /// Unique country codes mentioned, cities' countries included, in order of appearance.
    public var countryCodes: [String] {
        var seen = Set<String>()
        return places.compactMap { seen.insert($0.countryCode).inserted ? $0.countryCode : nil }
    }

    public var primaryCategory: VideoCategory? { categories.first }
}

public struct CaptionParser: Sendable {
    public var gazetteer: [GazetteerEntry]

    /// Words that are also place names; only matched when capitalised in the caption.
    static let ambiguous: Set<String> = [
        "nice", "chad", "turkey", "china", "georgia", "jordan", "split", "male", "bath", "reading",
        "victoria", "mali", "cork", "sale", "batman", "hue", "como", "ella", "goa", "ios", "kas", "rio", "leon", "flores", "trinidad", "antigua", "salvador", "granada", "lagos", "santiago", "cali", "nadi", "pai", "nara", "paros"
    ]

    public init(gazetteer: [GazetteerEntry]) {
        self.gazetteer = gazetteer
    }

    public func analyze(_ caption: String, extraPlaceNames: [String] = []) -> CaptionAnalysis {
        let text = caption.replacingOccurrences(of: "\r", with: "\n")
        let lower = text.lowercased()
        let hashtags = Self.hashtags(in: text)
        let hashtagBlob = hashtags.joined(separator: " ")

        // Categories by keyword score.
        var scores: [VideoCategory: Int] = [:]
        for cat in VideoCategory.allCases {
            var score = 0
            for kw in cat.keywords {
                if kw.contains(" ") || kw.contains("-") || kw.contains(".") {
                    if lower.contains(kw) { score += 2 }
                    if !kw.contains(" "), hashtagBlob.contains(kw.replacingOccurrences(of: "-", with: "")) { score += 1 }
                } else {
                    if Self.containsWord(kw, in: lower) { score += 1 }
                    if kw.count >= 4, hashtags.contains(where: { $0.contains(kw) }) { score += 1 }
                }
            }
            if score > 0 { scores[cat] = score }
        }
        let durationDays = Self.duration(in: lower)
        if durationDays != nil { scores[.itinerary, default: 0] += 2 }
        let prices = Self.prices(in: text)
        if !prices.isEmpty { scores[.budget, default: 0] += 1 }

        let categories = scores
            .sorted { $0.value != $1.value ? $0.value > $1.value : VideoCategory.allCases.firstIndex(of: $0.key)! < VideoCategory.allCases.firstIndex(of: $1.key)! }
            .map(\.key)

        // Places.
        var places: [PlaceMatch] = []
        var positions: [PlaceMatch: Int] = [:]
        var seen = Set<String>()
        for entry in gazetteer {
            for name in [entry.name] + entry.aliases {
                let key = name.lowercased()
                guard key.count >= 3 else { continue }
                var pos: Int?
                if Self.ambiguous.contains(key) {
                    pos = Self.wordPosition(name, in: text, caseSensitive: true)
                } else {
                    pos = Self.wordPosition(key, in: lower, caseSensitive: false)
                    if pos == nil, key.count >= 5 {
                        let squashed = key.replacingOccurrences(of: " ", with: "")
                        if hashtags.contains(where: { $0.contains(squashed) }) {
                            pos = 10_000 + places.count
                        }
                    }
                }
                if let p = pos {
                    let id = entry.countryCode + entry.name.lowercased()
                    if seen.insert(id).inserted {
                        let m = PlaceMatch(name: entry.name, countryCode: entry.countryCode, kind: entry.kind,
                                           latitude: entry.latitude, longitude: entry.longitude)
                        places.append(m)
                        positions[m] = p
                    }
                    break
                }
            }
        }
        // Names found by the platform's NLP that we don't already know get attached
        // to the first known country so they can still be geocoded later.
        for extra in extraPlaceNames {
            let key = extra.lowercased()
            if places.contains(where: { $0.name.lowercased() == key }) { continue }
            if let known = gazetteer.first(where: { $0.name.lowercased() == key }) {
                let m = PlaceMatch(name: known.name, countryCode: known.countryCode, kind: known.kind,
                                   latitude: known.latitude, longitude: known.longitude)
                if seen.insert(known.countryCode + known.name.lowercased()).inserted {
                    places.append(m)
                    positions[m] = Int.max - 1
                }
            }
        }
        places.sort { (positions[$0] ?? .max) < (positions[$1] ?? .max) }

        let packing = (categories.first == .packing || scores[.packing, default: 0] >= 2) ? Self.listItems(in: text) : []

        return CaptionAnalysis(
            categories: categories,
            hashtags: hashtags,
            places: places,
            prices: prices,
            packingItems: packing,
            durationDays: durationDays,
            title: Self.title(from: text)
        )
    }

    // MARK: - Pieces (internal so tests can poke them)

    static func hashtags(in text: String) -> [String] {
        let re = try! NSRegularExpression(pattern: "#([\\p{L}\\p{N}_]+)")
        let ns = text as NSString
        var out: [String] = []
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let tag = ns.substring(with: m.range(at: 1)).lowercased()
            if !out.contains(tag) { out.append(tag) }
        }
        return out
    }

    static func containsWord(_ word: String, in text: String) -> Bool {
        wordPosition(word, in: text, caseSensitive: true) != nil
    }

    static func wordPosition(_ word: String, in text: String, caseSensitive: Bool) -> Int? {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        let pattern = "(?<![\\p{L}\\p{N}#])" + escaped + "(?![\\p{L}\\p{N}])"
        guard let re = try? NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return m.range.location
    }

    static let symbolCurrency: [String: String] = [
        "£": "GBP", "$": "USD", "€": "EUR", "¥": "JPY", "₫": "VND", "฿": "THB", "₹": "INR", "₱": "PHP", "₩": "KRW"
    ]
    static let wordCurrency: [String: String] = [
        "gbp": "GBP", "pounds": "GBP", "quid": "GBP", "usd": "USD", "dollars": "USD", "eur": "EUR", "euros": "EUR",
        "euro": "EUR", "baht": "THB", "thb": "THB", "dong": "VND", "vnd": "VND", "aud": "AUD", "nzd": "NZD",
        "rupees": "INR", "inr": "INR", "yen": "JPY", "jpy": "JPY", "idr": "IDR", "rupiah": "IDR", "pesos": "MXN",
        "php": "PHP", "myr": "MYR", "ringgit": "MYR", "soles": "PEN", "cad": "CAD", "sgd": "SGD", "lak": "LAK", "kip": "LAK"
    ]

    static func prices(in text: String) -> [Money] {
        var out: [Money] = []
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        func number(_ s: String, k: Bool) -> Double? {
            guard var v = Double(s.replacingOccurrences(of: ",", with: "")) else { return nil }
            if k { v *= 1000 }
            return v
        }

        // £20, $1,200, €15.50, $5k
        let sym = try! NSRegularExpression(pattern: "([£$€¥₫฿₹₱₩])\\s?(\\d[\\d,]*(?:\\.\\d+)?)\\s?(k\\b)?", options: [.caseInsensitive])
        for m in sym.matches(in: text, range: full) {
            let s = ns.substring(with: m.range(at: 1))
            let n = ns.substring(with: m.range(at: 2))
            let k = m.range(at: 3).location != NSNotFound
            if let v = number(n, k: k), let c = symbolCurrency[s] { out.append(Money(v, c)) }
        }
        // 20 euros, 500 baht, 1.5k usd, 200000 dong
        let words = wordCurrency.keys.sorted { $0.count > $1.count }.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let wre = try! NSRegularExpression(pattern: "(?<![\\d.,])(\\d[\\d,]*(?:\\.\\d+)?)\\s?(k)?\\s?(" + words + ")\\b", options: [.caseInsensitive])
        for m in wre.matches(in: text, range: full) {
            let n = ns.substring(with: m.range(at: 1))
            let k = m.range(at: 2).location != NSNotFound
            let w = ns.substring(with: m.range(at: 3)).lowercased()
            if let v = number(n, k: k), let c = wordCurrency[w] { out.append(Money(v, c)) }
        }
        return out
    }

    static func duration(in lower: String) -> Int? {
        let re = try! NSRegularExpression(pattern: "(\\d{1,3})\\s?-?\\s?(day|days|night|nights|week|weeks|month|months)\\b")
        let ns = lower as NSString
        guard let m = re.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length)),
              let n = Int(ns.substring(with: m.range(at: 1))) else { return nil }
        let unit = ns.substring(with: m.range(at: 2))
        if unit.hasPrefix("week") { return n * 7 }
        if unit.hasPrefix("month") { return n * 30 }
        return n
    }

    /// Bullet / numbered / emoji-led lines, or comma lists after "packing list:" style headers.
    static func listItems(in text: String) -> [String] {
        var items: [String] = []
        func add(_ raw: String) {
            var s = raw
            // strip hashtags and leading bullets/numbers/emoji
            s = s.replacingOccurrences(of: "#[\\p{L}\\p{N}_]+", with: "", options: .regularExpression)
            s = s.replacingOccurrences(of: "^[\\s\\-•*·▪️✅✔️☑️👉➡️🔹🔸⭐️\\d.)]+", with: "", options: .regularExpression)
            s = s.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard s.count >= 3, s.count <= 60 else { return }
            if !items.contains(where: { $0.caseInsensitiveCompare(s) == .orderedSame }) { items.append(s) }
        }

        let lines = text.components(separatedBy: "\n")
        let bullet = try! NSRegularExpression(pattern: "^\\s*([\\-•*·]|\\d{1,2}[.)]|\\p{So})\\s*\\S")
        for line in lines {
            let ns = line as NSString
            if bullet.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) != nil {
                add(line)
            }
        }

        let header = try! NSRegularExpression(pattern: "(packing list|what i pack(?:ed)?|essentials|must haves?|must-haves?|items|products|i bring|bring)\\s*[:\\-]\\s*([^\\n#]+)", options: [.caseInsensitive])
        let ns = text as NSString
        for m in header.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let list = ns.substring(with: m.range(at: 2))
            for part in list.components(separatedBy: CharacterSet(charactersIn: ",;|")) { add(part) }
        }
        return items
    }

    public static func title(from text: String) -> String {
        let noTags = text.replacingOccurrences(of: "#[\\p{L}\\p{N}_]+", with: "", options: .regularExpression)
        let firstLine = noTags.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 { return trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: 77)
        return String(trimmed[..<idx]).trimmingCharacters(in: .whitespaces) + "…"
    }
}

public enum TikTokLink {
    /// Finds the first TikTok URL inside arbitrary shared text.
    public static func firstURL(in text: String) -> URL? {
        let re = try! NSRegularExpression(pattern: "https?://(?:www\\.|vm\\.|vt\\.|m\\.)?tiktok\\.com/[^\\s\"'<>]+", options: [.caseInsensitive])
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        var s = ns.substring(with: m.range)
        while let last = s.last, ".,)!?".contains(last) { s.removeLast() }
        return URL(string: s)
    }

    /// Any http(s) URL (for Instagram/YouTube etc. — saved without metadata parsing).
    public static func anyURL(in text: String) -> URL? {
        let re = try! NSRegularExpression(pattern: "https?://[^\\s\"'<>]+", options: [.caseInsensitive])
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        var s = ns.substring(with: m.range)
        while let last = s.last, ".,)!?".contains(last) { s.removeLast() }
        return URL(string: s)
    }

    public static func isTikTok(_ url: URL) -> Bool {
        (url.host ?? "").lowercased().hasSuffix("tiktok.com")
    }

    /// The public oEmbed endpoint that returns title/author/thumbnail with no API key.
    public static func oEmbedURL(for url: URL) -> URL? {
        // Encode the whole link (including its own ?, & and =) so it arrives as one value.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let value = url.absoluteString.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://www.tiktok.com/oembed?url=\(value)")
    }

    // MARK: Normalising share links

    /// A post on TikTok: who posted it, its id, and whether it's a video or a photo carousel.
    public struct Post: Equatable, Sendable {
        public var username: String?
        public var id: String
        public var isPhoto: Bool

        public init(username: String?, id: String, isPhoto: Bool) {
            self.username = username
            self.id = id
            self.isPhoto = isPhoto
        }

        /// https://www.tiktok.com/@user/video/123 (no tracking query).
        public var canonicalURL: URL {
            URL(string: "https://www.tiktok.com/@\(username ?? "_")/\(isPhoto ? "photo" : "video")/\(id)")!
        }
    }

    private static func firstMatch(_ pattern: String, in text: String, options: NSRegularExpression.Options = [.caseInsensitive]) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }

    /// Reads the post out of any full-form TikTok URL (or URL-like string).
    /// Returns nil for short links (vm./vt./www.tiktok.com/t/…) that must be resolved first.
    public static func post(in text: String) -> Post? {
        if let g = firstMatch("/@([\\w.\\-]+)/(video|photo)/(\\d{6,})", in: text) {
            return Post(username: g[1], id: g[3], isPhoto: g[2].lowercased() == "photo")
        }
        if let g = firstMatch("tiktok\\.com/v/(\\d{6,})", in: text) {
            return Post(username: nil, id: g[1], isPhoto: false)
        }
        if let g = firstMatch("[?&](?:share_)?item_id=(\\d{6,})", in: text) {
            return Post(username: nil, id: g[1], isPhoto: false)
        }
        if let g = firstMatch("tiktok\\.com/(?:embed(?:/v2)?|player/v1)/(\\d{6,})", in: text) {
            return Post(username: nil, id: g[1], isPhoto: false)
        }
        return nil
    }

    /// True when the link is a short share link that redirects to the real post.
    public static func needsResolving(_ url: URL) -> Bool {
        guard isTikTok(url) else { return false }
        return post(in: url.absoluteString) == nil
    }

    /// Finds the post a TikTok web page is about (canonical link, og:url, or first post path).
    public static func post(inHTML html: String) -> Post? {
        if let tag = metaTag(in: html, matching: "<link[^>]+rel=[\"']canonical[\"'][^>]*>"),
           let href = attribute("href", in: tag), let p = post(in: href) { return p }
        if let url = metaContent(in: html, property: "og:url"), let p = post(in: url) { return p }
        return post(in: html)
    }

    /// Caption, image and title from a TikTok page's meta tags / embedded JSON.
    public struct PageInfo: Equatable, Sendable {
        public var caption: String?
        public var imageURL: String?
        public var title: String?
    }

    public static func pageInfo(inHTML html: String) -> PageInfo {
        var caption: String?
        // Embedded JSON has the exact caption ("desc":"…").
        if let g = firstMatch("\"desc\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.){3,})\"", in: html, options: []) {
            caption = jsonUnescape(g[1])
        }
        if caption == nil || caption?.isEmpty == true,
           let d = metaContent(in: html, property: "og:description") ?? metaContent(in: html, name: "description") {
            caption = cleanDescription(d)
        }
        return PageInfo(
            caption: caption,
            imageURL: metaContent(in: html, property: "og:image"),
            title: metaContent(in: html, property: "og:title")
        )
    }

    /// TikTok's og:description looks like `12K Likes, 300 Comments. TikTok video from Name (@user): "caption". song`.
    public static func cleanDescription(_ d: String) -> String {
        if let g = firstMatch("TikTok (?:video|photo)[^:]*:\\s*[\"“](.*)[\"”]", in: d, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            return g[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return d.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func metaTag(in html: String, matching pattern: String) -> String? {
        firstMatch(pattern, in: html)?.first
    }

    static func metaContent(in html: String, property: String) -> String? {
        let p = NSRegularExpression.escapedPattern(for: property)
        guard let tag = metaTag(in: html, matching: "<meta[^>]+property=[\"']\(p)[\"'][^>]*>") else { return nil }
        return attribute("content", in: tag).map(htmlUnescape)
    }

    static func metaContent(in html: String, name: String) -> String? {
        let p = NSRegularExpression.escapedPattern(for: name)
        guard let tag = metaTag(in: html, matching: "<meta[^>]+name=[\"']\(p)[\"'][^>]*>") else { return nil }
        return attribute("content", in: tag).map(htmlUnescape)
    }

    static func attribute(_ name: String, in tag: String) -> String? {
        if let g = firstMatch("\\s\(name)=\"([^\"]*)\"", in: tag) { return g[1] }
        if let g = firstMatch("\\s\(name)='([^']*)'", in: tag) { return g[1] }
        return nil
    }

    static func htmlUnescape(_ s: String) -> String {
        var out = s
        let named = ["&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (k, v) in named { out = out.replacingOccurrences(of: k, with: v) }
        if let re = try? NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);") {
            let ns = out as NSString
            var result = ""
            var last = 0
            for m in re.matches(in: out, range: NSRange(location: 0, length: ns.length)) {
                result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                let hex = ns.substring(with: m.range(at: 1)).lowercased() == "x"
                let digits = ns.substring(with: m.range(at: 2))
                if let v = UInt32(digits, radix: hex ? 16 : 10), let scalar = UnicodeScalar(v) {
                    result += String(Character(scalar))
                } else {
                    result += ns.substring(with: m.range)
                }
                last = m.range.location + m.range.length
            }
            result += ns.substring(from: last)
            out = result
        }
        return out.replacingOccurrences(of: "&amp;", with: "&")
    }

    static func jsonUnescape(_ s: String) -> String {
        let data = Data("\"\(s)\"".utf8)
        return (try? JSONDecoder().decode(String.self, from: data)) ?? s
    }
}

/// Shape of TikTok's oEmbed JSON (only the fields we use).
public struct OEmbedResponse: Codable, Equatable, Sendable {
    public var title: String?
    public var author_name: String?
    public var author_url: String?
    public var thumbnail_url: String?
    public var html: String?

    public init(title: String? = nil, author_name: String? = nil, author_url: String? = nil, thumbnail_url: String? = nil, html: String? = nil) {
        self.title = title
        self.author_name = author_name
        self.author_url = author_url
        self.thumbnail_url = thumbnail_url
        self.html = html
    }
}

/// The folders saved videos are filed into (alongside automatic country folders).
public enum VideoFolder: String, Codable, CaseIterable, Sendable, Identifiable {
    case route, budget, tours, packing, stays, work, other

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .route: return "Route"
        case .budget: return "Budget"
        case .tours: return "Tour ideas"
        case .packing: return "Packing ideas"
        case .stays: return "Hostels & stays"
        case .work: return "Work & volunteering"
        case .other: return "Other"
        }
    }

    public var symbol: String {
        switch self {
        case .route: return "map.fill"
        case .budget: return "sterlingsign.circle.fill"
        case .tours: return "figure.hiking"
        case .packing: return "backpack.fill"
        case .stays: return "bed.double.fill"
        case .work: return "hands.sparkles.fill"
        case .other: return "tray.fill"
        }
    }

    /// Best folder for what the caption parser found.
    public static func suggested(for categories: [VideoCategory]) -> VideoFolder {
        guard let first = categories.first else { return .other }
        switch first {
        case .itinerary, .transport: return .route
        case .budget: return .budget
        case .activities: return .tours
        case .packing: return .packing
        case .accommodation: return .stays
        case .work: return .work
        case .food, .tips, .visa: return .other
        }
    }
}
