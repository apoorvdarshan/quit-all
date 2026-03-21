import SwiftUI

// MARK: - Cost Calculator View
struct CostView: View {
    @Environment(\.dismiss) private var dismiss

    let addiction: CDAddiction

    @State private var projectionMonths: Double = 6

    private var addictionType: AddictionType {
        AddictionTracker.shared.addictionType(for: addiction)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero: total saved
                    heroCard

                    // Timeline slider projection
                    projectionCard

                    // What you could buy
                    whatYouCouldBuyCard

                    // Life time saved (for smoking/alcohol)
                    if addictionType.minutesPerUnit > 0 {
                        lifeSavedCard
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(hex: "0A0A0A"))
            .navigationTitle("Money Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero Card
    private var heroCard: some View {
        let saved = CostCalculator.moneySaved(dailyCost: addiction.dailyCost, startDate: addiction.startDate)

        return VStack(spacing: 8) {
            Text("Total Saved")
                .font(.subheadline)
                .foregroundColor(.gray)

            Text(CostCalculator.formatCurrency(saved, currencyCode: addiction.currency))
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundColor(addictionType.color)

            Text("since quitting \(addiction.name?.lowercased() ?? "")")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(hex: "141414"))
        .cornerRadius(20)
    }

    // MARK: - Projection Card
    private var projectionCard: some View {
        let projected = CostCalculator.projectedSavings(dailyCost: addiction.dailyCost, months: Int(projectionMonths))

        return VStack(spacing: 16) {
            Text("Projected Savings")
                .font(.headline)
                .foregroundColor(.white)

            Text(CostCalculator.formatCurrency(projected, currencyCode: addiction.currency))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Slider
            VStack(spacing: 8) {
                Slider(value: $projectionMonths, in: 1...60, step: 1)
                    .tint(addictionType.color)

                HStack {
                    Text("1 month")
                    Spacer()
                    Text("\(Int(projectionMonths)) months")
                        .foregroundColor(addictionType.color)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("5 years")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
        }
        .padding(20)
        .background(Color(hex: "141414"))
        .cornerRadius(16)
    }

    // MARK: - What You Could Buy
    private var whatYouCouldBuyCard: some View {
        let projected = CostCalculator.projectedSavings(dailyCost: addiction.dailyCost, months: Int(projectionMonths))
        let items = CostCalculator.whatYouCouldBuy(amount: projected, currencyCode: addiction.currency)

        return VStack(alignment: .leading, spacing: 12) {
            Text("What you could buy")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(items, id: \.item) { item in
                let canAfford = projected >= item.cost

                HStack {
                    Text(item.emoji)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.item)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(canAfford ? .white : .gray)
                        Text(CostCalculator.formatCurrency(item.cost, currencyCode: addiction.currency))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    if canAfford {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray.opacity(0.3))
                    }
                }
                .padding(12)
                .background(canAfford ? addictionType.color.opacity(0.1) : Color(hex: "1A1A1A"))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color(hex: "141414"))
        .cornerRadius(16)
    }

    // MARK: - Life Saved Card
    private var lifeSavedCard: some View {
        let hours = CostCalculator.hoursSaved(
            addictionType: addictionType,
            dailyUnits: addictionType.defaultDailyUnits,
            startDate: addiction.startDate
        )

        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Life Saved")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text(CostCalculator.formatHoursSaved(hours))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("of your life back")
                .font(.subheadline)
                .foregroundColor(.gray)

            if addictionType == .smoking {
                Text("Each cigarette takes 11 minutes off your life")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(hex: "141414"))
        .cornerRadius(16)
    }
}
