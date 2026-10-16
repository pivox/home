import SwiftUI
import DeuxCore
import DeuxPersistence

struct HistoryView: View {
    @ObservedObject var store: HouseholdStore
    @Environment(\.dismiss) private var dismiss
    @ViewState private var error: String?

    private var grouped: [(date: Date, completions: [TaskCompletion])] {
        let groups = Dictionary(grouping: store.completions) { Calendar.current.startOfDay(for: $0.completedAt) }
        return groups.keys.sorted(by: >).map { date in (date, (groups[date] ?? []).sorted { $0.completedAt > $1.completedAt }) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Tout ce qui rend\nla maison plus légère.")
                        .font(DeuxStyle.title(30)).foregroundStyle(DeuxStyle.forest)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Une validation accidentelle ? Annulez-la ici. Pour une routine, seule la validation la plus récente peut être annulée.")
                        .font(.subheadline).foregroundStyle(DeuxStyle.secondary)
                    if store.completions.isEmpty {
                        EmptyState(symbol: "heart.text.square", title: "Les petits gestes restent.", message: "Vos tâches réalisées apparaîtront ici, avec la personne qui s’en est chargée.")
                    } else {
                        ForEach(grouped, id: \.date) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeading(title: Calendar.current.isDateInToday(group.date) ? "Aujourd’hui" : DeuxStyle.date(group.date, weekday: true).capitalized)
                                ForEach(group.completions) { completion in
                                    CompletionCard(completion: completion, personName: store.name(for: completion.completedBy)) {
                                        do { try store.undoCompletion(completion) }
                                        catch { self.error = error.localizedDescription }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(22).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(DeuxStyle.canvas)
            .navigationTitle("Les gestes déjà faits").inlineNavigationTitle()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
            .alert("Ce geste n’a pas pu être annulé", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("D’accord", role: .cancel) { error = nil }
            } message: { Text(error ?? "Réessayez dans un instant.") }
        }
        .tint(DeuxStyle.forest).preferredColorScheme(.light)
    }

}
