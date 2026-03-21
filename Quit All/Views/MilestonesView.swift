import SwiftUI
import CoreData

// MARK: - Milestones View
struct MilestonesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let addiction: CDAddiction

    @State private var showShareCard = false
    @State private var selectedMilestone: MilestoneDefinition?
    @State private var celebratingMilestone: MilestoneDefinition?

    private var addictionType: AddictionType {
        AddictionTracker.shared.addictionType(for: addiction)
    }

    private var unlockedTypes: Set<String> {
        let milestones = addiction.milestones as? Set<CDMilestone> ?? []
        return Set(milestones.compactMap { $0.type })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(MilestoneLibrary.milestones) { milestone in
                        let isUnlocked = StreakEngine.hoursSince(addiction.startDate) >= milestone.requiredHours
                        milestoneRow(milestone, unlocked: isUnlocked)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(hex: "0A0A0A"))
            .navigationTitle("Milestones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedMilestone) { milestone in
                shareCardView(milestone)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func milestoneRow(_ milestone: MilestoneDefinition, unlocked: Bool) -> some View {
        Button {
            if unlocked {
                HapticManager.shared.milestone()
                selectedMilestone = milestone

                // Save milestone if not already saved
                if !unlockedTypes.contains(milestone.type.rawValue) {
                    let cdMilestone = CDMilestone(context: viewContext)
                    cdMilestone.id = UUID()
                    cdMilestone.type = milestone.type.rawValue
                    cdMilestone.unlockedDate = Date()
                    cdMilestone.addiction = addiction
                    AddictionTracker.shared.saveContext(viewContext)
                }
            }
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(unlocked ? addictionType.color : Color(hex: "1A1A1A"))
                        .frame(width: 48, height: 48)

                    if unlocked {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(milestone.type.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundColor(unlocked ? addictionType.color : .gray)

                        Spacer()

                        if unlocked {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Text(milestone.title)
                        .font(.headline)
                        .foregroundColor(unlocked ? .white : .gray)

                    if unlocked {
                        Text(milestone.healthFact)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(3)
                    } else {
                        Text(milestone.subtitle)
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }
            .padding(16)
            .background(Color(hex: "141414"))
            .cornerRadius(16)
            .opacity(unlocked ? 1.0 : 0.5)
        }
        .disabled(!unlocked)
    }

    // MARK: - Shareable Card
    private func shareCardView(_ milestone: MilestoneDefinition) -> some View {
        let days = StreakEngine.daysSince(addiction.startDate)
        let saved = CostCalculator.moneySaved(dailyCost: addiction.dailyCost, startDate: addiction.startDate)
        let hours = CostCalculator.hoursSaved(addictionType: addictionType, dailyUnits: addictionType.defaultDailyUnits, startDate: addiction.startDate)

        return VStack(spacing: 24) {
            Spacer()

            // The shareable card
            VStack(spacing: 20) {
                Text(addictionType.emoji)
                    .font(.system(size: 48))

                Text("\(days) days free from \(addiction.name?.lowercased() ?? "")")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("\" \(milestone.title) \"")
                    .font(.headline)
                    .foregroundColor(addictionType.color)

                HStack(spacing: 24) {
                    if saved > 0 {
                        VStack(spacing: 4) {
                            Text(CostCalculator.formatCurrency(saved, currencyCode: addiction.currency))
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("saved")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    if hours > 0 {
                        VStack(spacing: 4) {
                            Text(CostCalculator.formatHoursSaved(hours))
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("life back")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Text("Quit All")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.gray)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "0A0A0A"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(addictionType.color.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)

            // Share button
            ShareLink(item: "\(days) days free from \(addiction.name ?? ""). \(CostCalculator.formatCurrency(saved, currencyCode: addiction.currency)) saved. — Quit All app") {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(addictionType.color)
                .cornerRadius(16)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button("Close") {
                selectedMilestone = nil
            }
            .foregroundColor(.gray)
            .padding(.bottom, 32)
        }
        .background(Color(hex: "0A0A0A").ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
