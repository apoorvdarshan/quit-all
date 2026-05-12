import SwiftUI
import WidgetKit

private let appGroupIdentifier = "group.com.apoorvdarshan.quitall"
private let snapshotKey = "quit_all_widget_snapshot"

struct QuitAllWidgetSnapshot: Codable {
    let addictionName: String
    let addictionType: String
    let startDate: Date
    let dailyCost: Double
    let currencyCode: String
    let activeHabitCount: Int
    let updatedAt: Date
}

struct QuitAllEntry: TimelineEntry {
    let date: Date
    let snapshot: QuitAllWidgetSnapshot?
}

struct QuitAllProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuitAllEntry {
        QuitAllEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuitAllEntry) -> Void) {
        completion(QuitAllEntry(date: Date(), snapshot: readSnapshot() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuitAllEntry>) -> Void) {
        let now = Date()
        let snapshot = readSnapshot()
        let entries = (0..<6).compactMap { offset -> QuitAllEntry? in
            guard let date = Calendar.current.date(byAdding: .minute, value: offset * 15, to: now) else { return nil }
            return QuitAllEntry(date: date, snapshot: snapshot)
        }
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    private func readSnapshot() -> QuitAllWidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroupIdentifier)?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(QuitAllWidgetSnapshot.self, from: data)
    }
}

struct QuitAllWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuitAllEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumWidget
            case .accessoryCircular:
                circularWidget
            case .accessoryRectangular:
                rectangularWidget
            case .accessoryInline:
                inlineWidget
            default:
                smallWidget
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(hex: "080808"), Color(hex: "151005")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUIT ALL")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1.4)

            if let snapshot = entry.snapshot {
                Spacer(minLength: 0)
                Text(streakValue(for: snapshot))
                    .font(.system(size: 42, weight: .black, design: .serif))
                    .foregroundStyle(goldGradient)
                    .minimumScaleFactor(0.7)
                Text(streakUnit(for: snapshot))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                Text(snapshot.addictionName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
            } else {
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(Color(hex: "D4AF37"))
                Text("Start tracking")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var mediumWidget: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("QUIT ALL")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.4)

                if let snapshot = entry.snapshot {
                    Text(streakValue(for: snapshot))
                        .font(.system(size: 48, weight: .black, design: .serif))
                        .foregroundStyle(goldGradient)
                        .minimumScaleFactor(0.7)
                    Text("\(streakUnit(for: snapshot)) free")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(snapshot.addictionName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                } else {
                    Text("Start your first quit goal.")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            Spacer(minLength: 0)

            if let snapshot = entry.snapshot {
                VStack(alignment: .trailing, spacing: 10) {
                    metric("Saved", value: moneySaved(for: snapshot))
                    metric("Habits", value: "\(snapshot.activeHabitCount)")
                    metric("Since", value: shortDate(snapshot.startDate))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }

    @ViewBuilder
    private var circularWidget: some View {
        if let snapshot = entry.snapshot {
            VStack(spacing: 1) {
                Text(streakValue(for: snapshot))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                Text(streakUnitShort(for: snapshot))
                    .font(.system(size: 10, weight: .bold))
            }
            .widgetAccentable()
        } else {
            Image(systemName: "plus")
                .font(.headline.weight(.bold))
                .widgetAccentable()
        }
    }

    @ViewBuilder
    private var rectangularWidget: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.addictionName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(streakValue(for: snapshot)) \(streakUnit(for: snapshot)) free")
                    .font(.headline.weight(.bold))
                    .widgetAccentable()
            }
        } else {
            Text("Quit All: start tracking")
                .font(.caption.weight(.semibold))
                .widgetAccentable()
        }
    }

    private var inlineWidget: some View {
        if let snapshot = entry.snapshot {
            Text("Quit All: \(streakValue(for: snapshot)) \(streakUnitShort(for: snapshot)) \(snapshot.addictionName)")
        } else {
            Text("Quit All: start tracking")
        }
    }

    private var goldGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "F5E6A3"), Color(hex: "D4AF37"), Color(hex: "9A7517")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.32))
                .tracking(0.8)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: "F5E6A3"))
                .lineLimit(1)
        }
    }

    private func streakValue(for snapshot: QuitAllWidgetSnapshot) -> String {
        let days = max(0, Calendar.current.dateComponents([.day], from: snapshot.startDate, to: entry.date).day ?? 0)
        if days > 0 { return "\(days)" }
        let hours = max(0, Calendar.current.dateComponents([.hour], from: snapshot.startDate, to: entry.date).hour ?? 0)
        if hours > 0 { return "\(hours)" }
        let minutes = max(0, Calendar.current.dateComponents([.minute], from: snapshot.startDate, to: entry.date).minute ?? 0)
        return "\(minutes)"
    }

    private func streakUnit(for snapshot: QuitAllWidgetSnapshot) -> String {
        let days = max(0, Calendar.current.dateComponents([.day], from: snapshot.startDate, to: entry.date).day ?? 0)
        if days > 0 { return days == 1 ? "day" : "days" }
        let hours = max(0, Calendar.current.dateComponents([.hour], from: snapshot.startDate, to: entry.date).hour ?? 0)
        if hours > 0 { return hours == 1 ? "hour" : "hours" }
        return "minutes"
    }

    private func streakUnitShort(for snapshot: QuitAllWidgetSnapshot) -> String {
        let unit = streakUnit(for: snapshot)
        if unit.hasPrefix("day") { return "d" }
        if unit.hasPrefix("hour") { return "h" }
        return "m"
    }

    private func moneySaved(for snapshot: QuitAllWidgetSnapshot) -> String {
        let hours = Double(max(0, Calendar.current.dateComponents([.hour], from: snapshot.startDate, to: entry.date).hour ?? 0))
        let amount = snapshot.dailyCost * (hours / 24.0)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = snapshot.currencyCode
        formatter.maximumFractionDigits = amount >= 100 ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct QuitAllWidget: Widget {
    let kind = "QuitAllWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuitAllProvider()) { entry in
            QuitAllWidgetView(entry: entry)
        }
        .configurationDisplayName("Quit All")
        .description("Track your current streak from the Home Screen or Lock Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct QuitAllWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuitAllWidget()
    }
}

private extension QuitAllWidgetSnapshot {
    static let preview = QuitAllWidgetSnapshot(
        addictionName: "Smoking",
        addictionType: "Smoking",
        startDate: Calendar.current.date(byAdding: .day, value: -12, to: Date()) ?? Date(),
        dailyCost: 12,
        currencyCode: "USD",
        activeHabitCount: 2,
        updatedAt: Date()
    )
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (255, 255, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
