import SwiftUI
import CoreData

// MARK: - Stats View
struct StatsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let addiction: CDAddiction

    @State private var patterns: PatternDetector.Patterns = .init()
    @State private var cravings: [CDCravingEvent] = []

    private let gold = Color(hex: "D4AF37")
    private let lightGold = Color(hex: "F5E6A3")

    private var addictionType: AddictionType {
        AddictionTracker.shared.addictionType(for: addiction)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    calendarHeatmap
                        .padding(.horizontal, 20)

                    if !cravings.isEmpty {
                        cravingFrequencyCard
                            .padding(.horizontal, 20)
                    }

                    if !patterns.triggerBreakdown.isEmpty {
                        triggerBreakdownCard
                            .padding(.horizontal, 20)
                    }

                    if !patterns.hourlyHeatmap.isEmpty {
                        hourlyHeatmapCard
                            .padding(.horizontal, 20)
                    }

                    if !patterns.insights.isEmpty {
                        insightsCard
                            .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
            .background(Color(hex: "080808"))
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundColor(gold)
                    }
                }
            }
            .task {
                cravings = CravingLogger.shared.fetchCravings(for: addiction, context: viewContext)
                patterns = await PatternDetector.shared.analyzePatterns(for: addictionType, context: viewContext)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Calendar Heatmap
    private var calendarHeatmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAST 30 DAYS")
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundColor(gold.opacity(0.7))
                .tracking(1.5)

            let dateMap = CravingLogger.shared.cravingDateMap(for: addiction, context: viewContext)
            let today = Calendar.current.startOfDay(for: Date())

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(0..<30, id: \.self) { daysAgo in
                    let date = Calendar.current.date(byAdding: .day, value: -(29 - daysAgo), to: today)!
                    let status = dateMap[date]

                    RoundedRectangle(cornerRadius: 4)
                        .fill(dayColor(status: status, isToday: date == today))
                        .frame(height: 32)
                        .overlay(
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 10, weight: .medium, design: .serif))
                                .foregroundColor(.white.opacity(0.6))
                        )
                }
            }

            HStack(spacing: 16) {
                legendDot(color: gold.opacity(0.5), label: "Clean")
                legendDot(color: Color(hex: "8B0000").opacity(0.6), label: "Craving")
                legendDot(color: Color(hex: "151515"), label: "No data")
            }
            .font(.system(size: 11, design: .serif))
            .foregroundColor(.white.opacity(0.4))
        }
        .padding(16)
        .background(Color(hex: "111111"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gold.opacity(0.08), lineWidth: 1)
        )
    }

    private func dayColor(status: Bool?, isToday: Bool) -> Color {
        if isToday {
            return gold.opacity(0.3)
        }
        guard let survived = status else {
            return Color(hex: "151515")
        }
        return survived ? gold.opacity(0.25) : Color(hex: "8B0000").opacity(0.4)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    // MARK: - Craving Frequency
    private var cravingFrequencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CRAVING FREQUENCY")
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundColor(gold.opacity(0.7))
                .tracking(1.5)

            let last7Days = cravingsPerDay(days: 7)
            let maxBarCount = max(1, last7Days.map(\.count).max() ?? 1)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(last7Days, id: \.date) { day in
                    let barHeight = day.count > 0 ? CGFloat(day.count) / CGFloat(maxBarCount) * 80 : 4

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [gold, gold.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(4, barHeight))

                        Text(dayLabel(day.date))
                            .font(.system(size: 9, weight: .medium, design: .serif))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100, alignment: .bottom)

            if let avg = patterns.averageCravingsPerDay {
                Text("Avg: \(String(format: "%.1f", avg)) cravings/day")
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(16)
        .background(Color(hex: "111111"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gold.opacity(0.08), lineWidth: 1)
        )
    }

    private struct DayCount: Hashable {
        let date: Date
        let count: Int
    }

    private func cravingsPerDay(days: Int) -> [DayCount] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<days).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -(days - 1 - offset), to: today)!
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: date)!
            let count = cravings.filter {
                guard let ts = $0.timestamp else { return false }
                return ts >= date && ts < nextDay
            }.count
            return DayCount(date: date, count: count)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(2))
    }

    // MARK: - Trigger Breakdown
    private var triggerBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOP TRIGGERS")
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundColor(gold.opacity(0.7))
                .tracking(1.5)

            let total = patterns.triggerBreakdown.values.reduce(0, +)
            let sorted = patterns.triggerBreakdown.sorted { $0.value > $1.value }

            ForEach(sorted.prefix(5), id: \.key) { trigger, count in
                let pct = total > 0 ? Double(count) / Double(total) : 0

                HStack {
                    Text(trigger)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 110, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [gold, gold.opacity(0.5)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * pct)
                        }
                    }
                    .frame(height: 14)

                    Text("\(Int(pct * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .serif).monospacedDigit())
                        .foregroundColor(lightGold)
                        .frame(width: 36)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "111111"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gold.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Hourly Heatmap
    private var hourlyHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CRAVING BY HOUR")
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundColor(gold.opacity(0.7))
                .tracking(1.5)

            let maxCount = patterns.hourlyHeatmap.values.max() ?? 1

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = patterns.hourlyHeatmap[hour] ?? 0
                    let intensity = maxCount > 0 ? Double(count) / Double(maxCount) : 0

                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(gold.opacity(0.15 + intensity * 0.85))
                            .frame(height: max(4, CGFloat(intensity) * 60))

                        if hour % 6 == 0 {
                            Text("\(hour)")
                                .font(.system(size: 8, design: .serif))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80, alignment: .bottom)

            if let dangerZone = patterns.dangerZoneDescription {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "8B0000"))
                    Text("Danger zone: \(dangerZone)")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundColor(Color(hex: "8B0000"))
                }
            }
        }
        .padding(16)
        .background(Color(hex: "111111"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gold.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Insights
    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(gold)
                Text("PATTERN INSIGHTS")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundColor(gold.opacity(0.7))
                    .tracking(1.5)
            }

            ForEach(patterns.insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(gold.opacity(0.6))
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)
                    Text(insight)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(16)
        .background(Color(hex: "111111"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gold.opacity(0.08), lineWidth: 1)
        )
    }
}
