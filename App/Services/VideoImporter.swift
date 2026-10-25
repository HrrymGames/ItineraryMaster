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
        let all = (try? context.fetch(FetchDescriptor<SavedVideo>())) ?? []
        if let existing = all.first(where: { $0.urlString == key }) { return existing }
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
            video.caption = meta.caption
            video.author = meta.author
            video.thumbnailURL = meta.thumbnailURL
            video.thumbnail = await VideoMetadataService.thumbnail(from: meta.thumbnailURL)
            video.fetchState = .fetched
        } catch let error as URLError where error.code == .unsupportedURL {
            // Not a site with a public oEmbed (e.g. Instagram) - keep it as a plain link.
            video.fetchState = .manual
        } catch {
            if video.caption.isEmpty {
                video.fetchState = .failed
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

    /// Retries anything that failed or never got fetched (e.g. saved offline).
    static func retryPending(trip: Trip?, context: ModelContext) async {
        let all = (try? context.fetch(FetchDescriptor<SavedVideo>())) ?? []
        for v in all where v.fetchState == .pending || v.fetchState == .failed {
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
