import Foundation
import SwiftData
import ItineraryCore

/// Saves shared links as SavedVideos and turns their captions into structure.
@MainActor
enum VideoImporter {
    /// Adds a link (deduplicated). Returns the existing video if already saved.
    @discardableResult
    static func add(urlString raw: String, note: String? = nil, context: ModelContext) -> SavedVideo? {
        let found = TikTokLink.firstURL(in: raw) ?? TikTokLink.anyURL(in: raw) ?? URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))
        guard let url = found, url.scheme?.hasPrefix("http") == true else { return nil }
        let key = url.absoluteString
        let postID = TikTokLink.post(in: key)?.id
        let all = (try? context.fetch(FetchDescriptor<SavedVideo>())) ?? []
        if let existing = all.first(where: { $0.urlString == key || (postID != nil && TikTokLink.post(in: $0.urlString)?.id == postID) }) {
            return existing
        }
        let video = SavedVideo(urlString: key)
        if let note, !note.isEmpty { video.notes = note }
        context.insert(video)
        try? context.save()
        return video
    }

    /// Fetches caption/author/thumbnail, then analyses the caption.
    static func process(_ video: SavedVideo, trip: Trip?, context: ModelContext) async {
        guard let url = video.url else { return }
        do {
            let meta = try await VideoMetadataService.fetch(url)
            if let canonical = meta.canonicalURL?.absoluteString, canonical != video.urlString {
                // A short link that turned out to be a post we already have: keep the older one.
                let all = (try? context.fetch(FetchDescriptor<SavedVideo>())) ?? []
                let id = TikTokLink.post(in: canonical)?.id
                if let dupe = all.first(where: { $0.id != video.id && TikTokLink.post(in: $0.urlString)?.id == id && id != nil }) {
                    if dupe.notes.isEmpty { dupe.notes = video.notes }
                    context.delete(video)
                    try? context.save()
                    return
                }
                video.urlString = canonical
            }
            video.caption = meta.caption
            video.author = meta.author
            video.thumbnailURL = meta.thumbnailURL
            if let thumb = await VideoMetadataService.thumbnail(from: meta.thumbnailURL) {
                video.thumbnail = thumb
            }
            video.fetchState = .fetched
            video.fetchError = nil
            video.fetchErrorIsTemporary = false
        } catch {
            let reason = VideoFetchError.from(error)
            if reason == .unsupportedSite {
                // e.g. Instagram - keep it as a plain link the user can caption themselves.
                video.fetchState = .manual
                video.fetchError = nil
            } else if video.caption.isEmpty {
                video.fetchState = .failed
                video.fetchError = reason.errorDescription
                video.fetchErrorIsTemporary = reason.isTemporary
            }
        }
        if !video.caption.isEmpty {
            apply(caption: video.caption, to: video, trip: trip)
        }
        try? context.save()
    }

    /// Runs the on-device parser and fills categories, places, packing items etc.
    static func apply(caption: String, to video: SavedVideo, trip: Trip?) {
        let a = CountryStore.shared.analyze(caption: caption)
        video.title = a.title
        video.categories = a.categories.isEmpty ? [.tips] : Array(a.categories.prefix(4))
        video.countryCodes = a.countryCodes
        video.placeNames = a.places.filter { $0.kind == .city }.map(\.name)
        video.packingSuggestions = a.packingItems
        video.priceNotes = a.prices.map { MoneyFormat.string($0.amount, currency: $0.currency) }
        video.durationDays = a.durationDays

        // Auto-sort: link to a stop on the route if the caption names it.
        if video.stop == nil, let trip {
            let names = Set((a.places.map(\.name) + NLPlaceTagger.placeNames(in: caption)).map { $0.lowercased() })
            if let match = trip.orderedStops.first(where: { names.contains($0.name.lowercased()) }) {
                video.stop = match
                video.isSorted = true
            }
        }
    }

    /// Retries anything never fetched, or that failed for a temporary reason (no signal, TikTok busy).
    /// Permanent failures (deleted post, bad link) wait for the user to tap "Try again".
    static func retryPending(trip: Trip?, context: ModelContext, includeAllFailures: Bool = false) async {
        let all = (try? context.fetch(FetchDescriptor<SavedVideo>())) ?? []
        let due = all.filter {
            $0.fetchState == .pending ||
                ($0.fetchState == .failed && (includeAllFailures || $0.fetchErrorIsTemporary || $0.fetchError == nil))
        }
        for v in due {
            await process(v, trip: trip, context: context)
        }
    }

    /// Pulls in links queued by the share extension.
    static func drainShareQueue(trip: Trip?, context: ModelContext) async -> Int {
        let pending = ImportQueue.drain()
        var added: [SavedVideo] = []
        for p in pending {
            if let v = add(urlString: p.url, note: p.note, context: context), v.fetchState == .pending {
                added.append(v)
            }
        }
        for v in added { await process(v, trip: trip, context: context) }
        return pending.count
    }
}
