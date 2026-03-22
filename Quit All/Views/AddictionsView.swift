import SwiftUI
import CoreData

// MARK: - Addictions Management View
struct AddictionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDAddiction.startDate, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default
    ) private var addictions: FetchedResults<CDAddiction>

    @State private var showAddNew = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(addictions) { addiction in
                    let type = AddictionTracker.shared.addictionType(for: addiction)
                    let days = StreakEngine.daysSince(addiction.startDate)

                    HStack(spacing: 12) {
                        Image(type.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(addiction.name ?? "")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(days) days clean")
                                .font(.caption)
                                .foregroundColor(type.color)
                        }

                        Spacer()

                        if addiction.dailyCost > 0 {
                            Text(CostCalculator.formatCurrency(
                                CostCalculator.moneySaved(dailyCost: addiction.dailyCost, startDate: addiction.startDate),
                                currencyCode: addiction.currency
                            ))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.green)
                        }
                    }
                    .listRowBackground(Color(hex: "141414"))
                }
                .onDelete(perform: deleteAddictions)
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "0A0A0A"))
            .navigationTitle("My Addictions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func deleteAddictions(at offsets: IndexSet) {
        for index in offsets {
            let addiction = addictions[index]
            AddictionTracker.shared.deleteAddiction(addiction, context: viewContext)
        }
    }
}
