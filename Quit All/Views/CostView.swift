import SwiftUI

// MARK: - Cost Calculator View
struct CostView: View {
    @Environment(\.dismiss) private var dismiss

    let addiction: CDAddiction

    @State private var projectionMonths: Double = 6

    private let gold = Color(hex: "D4AF37")
    private let lightGold = Color(hex: "F5E6A3")

    private var addictionType: AddictionType {
        AddictionTracker.shared.addictionType(for: addiction)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroCard
                    projectionCard
                    whatYouCouldBuyCard

                    if addictionType.minutesPerUnit > 0 {
                        lifeSavedCard
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(hex: "080808"))
            .navigationTitle("Money Saved")
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
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero Card
    private var heroCard: some View {
        let saved = CostCalculator.moneySaved(dailyCost: addiction.dailyCost, startDate: addiction.startDate)

        return VStack(spacing: 8) {
            Text("TOTAL SAVED")
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundColor(gold.opacity(0.7))
                .tracking(1.5)

            Text(CostCalculator.formatCurrency(saved, currencyCode: addiction.currency))
                .font(.system(size: 48, weight: .black, design: .serif))
                .foregroundStyle(
                    LinearGradient(
                        colors: [lightGold, gold, Color(hex: "C5962C")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: gold.opacity(0.3), radius: 12)

            Text("since quitting \(addiction.name?.lowercased() ?? "")")
                .font(.system(size: 12, design: .serif))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(hex: "111111"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(gold.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Projection Card
    private var projectionCard: some View {
        let projected = CostCalculator.projectedSavings(dailyCost: addiction.dailyCost, months: Int(projectionMonths))

        return VStack(spacing: 16) {
            Text("PROJECTED SAVINGS")
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundColor(gold.opacity(0.7))
                .tracking(1.5)

            Text(CostCalculator.formatCurrency(projected, currencyCode: addiction.currency))
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundColor(lightGold)

            VStack(spacing: 8) {
                Slider(value: $projectionMonths, in: 1...60, step: 1)
                    .tint(gold)

                HStack {
                    Text("1 month")
                    Spacer()
                    Text("\(Int(projectionMonths)) months")
                        .foregroundColor(gold)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                    Spacer()
                    Text("5 years")
                }
                .font(.system(size: 11, design: .serif))
                .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(20)
        .background(Color(hex: "111111"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gold.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - What You Could Buy
    private var whatYouCouldBuyCard: some View {
        let projected = CostCalculator.projectedSavings(dailyCost: addiction.dailyCost, months: Int(projectionMonths))
        let items = CostCalculator.whatYouCouldBuy(amount: projected, currencyCode: addiction.currency)

        return VStack(alignment: .leading, spacing: 12) {
            Text("WHAT YOU COULD BUY")
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .foregroundColor(gold.opacity(0.7))
                .tracking(1.5)

            ForEach(items, id: \.item) { item in
                let canAfford = projected >= item.cost

                HStack {
                    Text(item.emoji)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.item)
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundColor(canAfford ? .white : .white.opacity(0.4))
                        Text(CostCalculator.formatCurrency(item.cost, currencyCode: addiction.currency))
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(.white.opacity(0.3))
                    }

                    Spacer()

                    if canAfford {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(gold)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.white.opacity(0.1))
                    }
                }
                .padding(12)
                .background(canAfford ? gold.opacity(0.08) : Color(hex: "151515"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(canAfford ? gold.opacity(0.2) : Color.white.opacity(0.04), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(Color(hex: "111111"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gold.opacity(0.08), lineWidth: 1)
        )
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
                    .foregroundColor(Color(hex: "8B0000"))
                Text("LIFE SAVED")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundColor(gold.opacity(0.7))
                    .tracking(1.5)
            }

            Text(CostCalculator.formatHoursSaved(hours))
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundColor(lightGold)

            Text("of your life back")
                .font(.system(size: 13, design: .serif))
                .foregroundColor(.white.opacity(0.35))

            if addictionType == .smoking {
                Text("Each cigarette takes 11 minutes off your life")
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(hex: "111111"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gold.opacity(0.08), lineWidth: 1)
        )
    }
}
