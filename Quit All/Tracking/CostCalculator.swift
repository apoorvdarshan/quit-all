import Foundation

// MARK: - Cost Calculator
struct CostCalculator {

    // Total money saved since quit date
    static func moneySaved(dailyCost: Double, startDate: Date?) -> Double {
        guard let start = startDate else { return 0 }
        let days = Double(StreakEngine.daysSince(start))
        let hours = Double(StreakEngine.hoursSince(start))
        // Use hours for more precise calculation in first few days
        if days < 1 {
            return dailyCost * (hours / 24.0)
        }
        return dailyCost * days
    }

    // Projected savings for a given number of months
    static func projectedSavings(dailyCost: Double, months: Int) -> Double {
        return dailyCost * Double(months) * 30.44  // average days per month
    }

    // Hours of life saved (primarily for smoking)
    static func hoursSaved(addictionType: AddictionType, dailyUnits: Double, startDate: Date?) -> Double {
        guard addictionType.minutesPerUnit > 0 else { return 0 }
        let days = Double(StreakEngine.daysSince(startDate))
        let totalMinutes = days * dailyUnits * addictionType.minutesPerUnit
        return totalMinutes / 60.0
    }

    // Format currency amount using device locale
    static func formatCurrency(_ amount: Double, currencyCode: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode ?? Locale.current.currency?.identifier ?? "USD"
        formatter.maximumFractionDigits = amount >= 100 ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }

    // "What you could buy" items with approximate costs in USD
    static func whatYouCouldBuy(amount: Double, currencyCode: String?) -> [(emoji: String, item: String, cost: Double)] {
        let items: [(emoji: String, item: String, costUSD: Double)] = [
            ("☕", "Coffee", 5),
            ("🍔", "Nice dinner", 30),
            ("🎧", "AirPods", 130),
            ("👟", "New sneakers", 150),
            ("✈️", "Weekend trip", 500),
            ("📱", "iPhone", 999),
            ("💻", "MacBook", 1299),
            ("🏝️", "International vacation", 3000),
            ("🚗", "Used car", 10000),
            ("🏠", "Down payment on a house", 50000),
        ]

        // Simple conversion factor (approximate)
        let factor = currencyConversionFactor(currencyCode: currencyCode)

        return items.map { (emoji: $0.emoji, item: $0.item, cost: $0.costUSD * factor) }
            .filter { $0.cost <= amount * 3 }  // Show items within 3x of savings
    }

    // Basic currency conversion factor relative to USD
    private static func currencyConversionFactor(currencyCode: String?) -> Double {
        switch currencyCode {
        case "INR": return 83.0
        case "EUR": return 0.92
        case "GBP": return 0.79
        case "JPY": return 150.0
        case "CAD": return 1.36
        case "AUD": return 1.53
        case "CNY": return 7.24
        case "BRL": return 4.97
        default: return 1.0
        }
    }

    // Format hours saved into human readable
    static func formatHoursSaved(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60)) minutes"
        } else if hours < 24 {
            return String(format: "%.1f hours", hours)
        } else {
            let days = hours / 24.0
            if days < 30 {
                return String(format: "%.1f days", days)
            } else {
                let months = days / 30.44
                return String(format: "%.1f months", months)
            }
        }
    }
}
