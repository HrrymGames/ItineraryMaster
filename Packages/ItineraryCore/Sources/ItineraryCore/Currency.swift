import Foundation

/// Exchange rates expressed as "1 unit of `base` = rate units of currency".
public struct ExchangeRates: Codable, Equatable, Sendable {
    public var base: String
    public var rates: [String: Double]
    public var fetchedAt: Date

    public init(base: String, rates: [String: Double], fetchedAt: Date = Date()) {
        self.base = base.uppercased()
        var r = rates.reduce(into: [String: Double]()) { $0[$1.key.uppercased()] = $1.value }
        r[self.base] = 1
        self.rates = r
        self.fetchedAt = fetchedAt
    }

    /// Converts between any two currencies known to this table.
    /// Returns nil if either currency is unknown.
    public func convert(_ amount: Double, from: String, to: String) -> Double? {
        let f = from.uppercased(), t = to.uppercased()
        if f == t { return amount }
        guard let rf = rates[f], let rt = rates[t], rf > 0 else { return nil }
        return amount / rf * rt
    }

    /// Converts, falling back to the unconverted amount when a rate is missing,
    /// so totals still show something sensible offline.
    public func convertOrSame(_ amount: Double, from: String, to: String) -> Double {
        convert(amount, from: from, to: to) ?? amount
    }

    /// Rough built-in rates (per 1 GBP) used before the first online refresh.
    /// They only need to be in the right ballpark for planning.
    public static let fallbackGBP = ExchangeRates(
        base: "GBP",
        rates: [
            "USD": 1.30, "EUR": 1.18, "AUD": 1.98, "NZD": 2.18, "CAD": 1.79,
            "JPY": 195, "THB": 43, "VND": 33500, "IDR": 21000, "MYR": 5.7,
            "SGD": 1.70, "PHP": 74, "KHR": 5300, "LAK": 28000, "INR": 110,
            "NPR": 176, "LKR": 390, "CNY": 9.3, "KRW": 1800, "TWD": 41,
            "HKD": 10.1, "MXN": 24, "BRL": 7.2, "ARS": 1300, "CLP": 1230,
            "PEN": 4.8, "COP": 5300, "BOB": 9.0, "CRC": 650, "GTQ": 10,
            "ZAR": 23.5, "KES": 168, "TZS": 3400, "MAD": 12.6, "EGP": 63,
            "TRY": 52, "AED": 4.77, "CHF": 1.10, "NOK": 13.8, "SEK": 13.5,
            "DKK": 8.8, "PLN": 5.0, "CZK": 29.5, "HUF": 470, "ISK": 178,
            "HRK": 8.9, "RON": 5.9, "BGN": 2.3, "FJD": 2.9, "USDT": 1.30
        ],
        fetchedAt: Date(timeIntervalSince1970: 0)
    )
}

public enum MoneyFormat {
    public static func string(_ amount: Double, currency: String, locale: Locale = .current) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency.uppercased()
        f.locale = locale
        f.maximumFractionDigits = abs(amount) >= 1000 ? 0 : 2
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "\(currency) \(Int(amount.rounded()))"
    }
}
