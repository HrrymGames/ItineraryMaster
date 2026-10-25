import SwiftUI
import UIKit
import ItineraryCore

enum Theme {
    static let accent = Color(red: 0.937, green: 0.329, blue: 0.420)
    static let current = Color.orange
    static let visited = Color.green
    static let skipped = Color.gray
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)

    static func color(for status: StopStatus) -> Color {
        switch status {
        case .planned: return accent
        case .current: return current
        case .visited: return visited
        case .skipped: return skipped
        }
    }

    static func color(for category: VideoCategory) -> Color {
        switch category {
        case .itinerary: return .blue
        case .packing: return .brown
        case .activities: return .green
        case .accommodation: return .indigo
        case .work: return .teal
        case .budget: return .mint
        case .food: return .orange
        case .transport: return .cyan
        case .tips: return .yellow
        case .visa: return .purple
        }
    }

    static func color(for section: PlaceSection) -> Color {
        switch section {
        case .stay: return .indigo
        case .work: return .teal
        case .todo: return .green
        case .food: return .orange
        case .see: return .pink
        case .other: return .gray
        }
    }

    static func color(for category: BudgetCategory) -> Color {
        switch category {
        case .accommodation: return .indigo
        case .food: return .orange
        case .transport: return .cyan
        case .activities: return .green
        case .flights: return .blue
        case .insurance: return .purple
        case .gear: return .brown
        case .visas: return .pink
        case .shopping: return .yellow
        case .other: return .gray
        }
    }
}

enum Fmt {
    static let day: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f
    }()

    static let dayYear: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return f
    }()

    static func range(_ d: ScheduledDates?) -> String {
        guard let d else { return "" }
        if d.arrival == d.departure { return Fmt.day.string(from: d.arrival) }
        return "\(Fmt.day.string(from: d.arrival)) – \(Fmt.day.string(from: d.departure))"
    }

    static func money(_ amount: Double, _ currency: String) -> String {
        MoneyFormat.string(amount, currency: currency)
    }

    static func nights(_ n: Int) -> String { n == 1 ? "1 night" : "\(n) nights" }

    static func km(_ km: Double) -> String {
        km < 10 ? String(format: "%.1f km", km) : "\(Int(km.rounded())) km"
    }

    static func hours(_ h: Double) -> String {
        if h < 1 { return "\(max(5, Int((h * 60).rounded()))) min" }
        if h < 10 { return String(format: "%.1f h", h).replacingOccurrences(of: ".0", with: "") }
        return "\(Int(h.rounded())) h"
    }
}

struct StopNumberBadge: View {
    let number: Int
    let status: StopStatus
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(Theme.color(for: status))
            if status == .visited {
                Image(systemName: "checkmark").font(.system(size: size * 0.45, weight: .bold))
            } else {
                Text("\(number)").font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .overlay(Circle().stroke(.white, lineWidth: 2))
        .opacity(status == .skipped ? 0.6 : 1)
    }
}

struct ChipView: View {
    let title: String
    var symbol: String?
    var color: Color = Theme.accent
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.caption2) }
            Text(title).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(selected ? color : color.opacity(0.14), in: Capsule())
        .foregroundStyle(selected ? Color.white : color)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var caption: String?
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.bold)).foregroundStyle(tint).minimumScaleFactor(0.6).lineLimit(1)
            if let caption { Text(caption).font(.caption2).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ThumbnailView: View {
    let data: Data?
    var placeholderSymbol: String = "play.rectangle.fill"
    var cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            if let data, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Theme.accent.opacity(0.8), .purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: placeholderSymbol).font(.title2).foregroundStyle(.white.opacity(0.9))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct StarRating: View {
    @Binding var rating: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .foregroundStyle(i <= rating ? Color.yellow : Color.secondary)
                    .onTapGesture { rating = (rating == i ? 0 : i) }
            }
        }
    }
}

/// A currency text field that shows the code next to the number.
struct AmountField: View {
    let title: String
    @Binding var amount: Double
    @Binding var currency: String
    @EnvironmentObject private var rates: CurrencyService

    var body: some View {
        HStack {
            TextField(title, value: $amount, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
            Picker("", selection: $currency) {
                ForEach(rates.knownCurrencies, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }
}

extension View {
    /// Card styling used throughout.
    func card(padding: CGFloat = 14) -> some View {
        self.padding(padding)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}

extension URL {
    /// Opens TikTok links in the TikTok app if installed (universal link), else Safari.
    func openExternally() {
        UIApplication.shared.open(self)
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
    var asURL: URL? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if t.hasPrefix("http://") || t.hasPrefix("https://") { return URL(string: t) }
        return URL(string: "https://" + t)
    }
}
