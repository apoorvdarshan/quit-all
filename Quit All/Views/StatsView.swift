import SwiftUI
import CoreData

// MARK: - Stats View
struct StatsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let addiction: CDAddiction

    @State private var patterns: PatternDetector.Patterns = .init()
    @State private var cravings: [CDCravingEvent] = []

    private var addictionType: AddictionType {
        AddictionTracker.shared.addictionType(for: addiction)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Calendar heatmap
                    calendarHeatmap
                        .padding(.horizontal, 20)

                    // Craving frequency
                    if !cravings.isEmpty {
                        cravingFrequencyCard
                            .padding(.horizontal, 20)
                    }

                    // Top triggers
                    if !patterns.triggerBreakdown.isEmpty {
                        triggerBreakdownCard
                            .padding(.horizontal, 20)
                    }

                    // Hour heatmap
                    if !patterns.hourlyHeatmap.isEmpty {
                        hourlyHeatmapCard
                            .padding(.horizontal, 20)
                    }

                    // Pattern insights
                    if !patterns.insights.isEmpty {
                        insightsCard
                            .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
            .background(Color(hex: "0A0A0A"))
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
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
            Text("Last 30 Days")
                .font(.headline)
                .foregroundColor(.white)

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
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        )
                }
            }

            HStack(spacing: 16) {
                legendDot(color: .green.opacity(0.6), label: "Clean")
                legendDot(color: .red.opacity(0.6), label: "Craving")
                legendDot(color: Color(hex: "141414"), label: "No data")
            }
            .font(.caption)
            .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color(hex: "141414"))
        .cornerRadius(16)
    }

    private func dayColor(status: Bool?, isToday: Bool) -> Color {
        if isToday {
            return addictionType.color.opacity(0.4)
        }
        guard let survived = status else {
            return Color(hex: "1A1A1A")
        }
        return survived ? .green.opacity(0.4) : .red.opacity(0.4)
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
            Text("Craving Frequency")
                .font(.headline)
                .foregroundColor(.white)

            // Simple bar chart for last 7 days
            let last7Days = cravingsPerDay(days: 7)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(last7Days, id: \.date) { day in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(addictionType.color)
                            .frame(height: max(4, CGFloat(day.count) * 20))

                        Text(dayLabel(day.date))
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100, alignment: .bottom)

            if let avg = patterns.averageCravingsPerDay {
                Text("Avg: \(String(format: "%.1f", avg)) cravings/day")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color(hex: "141414"))
        .cornerRadius(16)
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
            Text("Top Triggers")
                .font(.headline)
                .foregroundColor(.white)

            let total = patterns.triggerBreakdown.values.reduce(0, +)
            let sorted = patterns.triggerBreakdown.sorted { $0.value > $1.value }

            ForEach(sorted.prefix(5), id: \.key) { trigger, count in
                let pct = total > 0 ? Double(count) / Double(total) : 0

                HStack {
                    Text(trigger)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(width: 120, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(addictionType.color)
                                .frame(width: geo.size.width * pct)
                        }
                    }
                    .frame(height: 16)

                    Text("\(Int(pct * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.gray)
                        .frame(width: 36)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "141414"))
        .cornerRadius(16)
    }

    // MARK: - Hourly Heatmap
    private var hourlyHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Craving by Hour")
                .font(.headline)
                .foregroundColor(.white)

            let maxCount = patterns.hourlyHeatmap.values.max() ?? 1

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    let count = patterns.hourlyHeatmap[hour] ?? 0
                    let intensity = maxCount > 0 ? Double(count) / Double(maxCount) : 0

                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(addictionType.color.opacity(0.2 + intensity * 0.8))
                            .frame(height: max(4, CGFloat(intensity) * 60))

                        if hour % 6 == 0 {
                            Text("\(hour)")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80, alignment: .bottom)

            if let dangerZone = patterns.dangerZoneDescription {
                Text("Danger zone: \(dangerZone)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(16)
        .background(Color(hex: "141414"))
        .cornerRadius(16)
    }

    // MARK: - Insights
    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Pattern Insights")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            ForEach(patterns.insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(addictionType.color)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(insight)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(16)
        .background(Color(hex: "141414"))
        .cornerRadius(16)
    }
}
