import SwiftUI
import DeuxCore
import DeuxPersistence

struct TodayView: View {
    @ObservedObject var store: HouseholdStore
    let add: () -> Void
    let edit: (HouseTask) -> Void
    let complete: (HouseTask) -> Void
    @ViewState private var person: PersonFilter = .everyone
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var dueTasks: [HouseTask] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return store.tasks.filter { $0.completedAt == nil && $0.dueDate < tomorrow }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var visibleTasks: [HouseTask] { dueTasks.filter { person.includes($0) } }
    private var todayDone: Int { store.completions.filter { Calendar.current.isDateInToday($0.completedAt) }.count }
    private var overdueCount: Int { TaskInsights.overdueTasks(store.tasks).count }
    private var weekMinutes: Int { TaskInsights.weeklyEffortMinutes(store.completions) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                StoreErrorBanner(store: store)
                progressCard
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeading(title: "Le fil de la journée", detail: "\(dueTasks.count) à faire")
                    PersonFilters(store: store, selection: $person)
                    if visibleTasks.isEmpty {
                        EmptyState(
                            symbol: dueTasks.isEmpty ? "sparkles" : "leaf",
                            title: dueTasks.isEmpty ? "De l’air dans la journée." : "Rien de ce côté-ci.",
                            message: dueTasks.isEmpty
                                ? "Aucune tâche prévue ou en retard. Profitez de ce temps, ou préparez la suite."
                                : "Aucune tâche pour cette personne aujourd’hui. Les tâches au choix ont leur propre filtre.",
                            actionTitle: dueTasks.isEmpty ? "Prévoir une tâche" : "Voir tout le monde",
                            action: dueTasks.isEmpty ? add : { person = .everyone }
                        )
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(visibleTasks) { task in
                                TaskRow(task: task, assigneeName: task.assignee == .anyone ? "Au choix" : store.name(for: task.assignee), complete: { complete(task) }, edit: { edit(task) })
                            }
                        }
                    }
                    Button(action: add) { Label("Ajouter une tâche", systemImage: "plus") }
                        .buttonStyle(PrimaryButtonStyle())
                }
                HStack(spacing: 8) {
                    Image(systemName: "heart").font(.caption)
                    Text("Une équipe, pas une liste de comptes.").font(.caption)
                }
                .foregroundStyle(DeuxStyle.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
            }
            .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 28)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(DeuxStyle.canvas)
        .screenChrome()
        .refreshable { await store.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("À DEUX", systemImage: "house.fill")
                    .font(.caption.weight(.bold)).tracking(2).foregroundStyle(DeuxStyle.forest)
                Spacer()
                Text(store.householdName).font(.caption).foregroundStyle(DeuxStyle.secondary).lineLimit(1)
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Bonjour, \(store.name(for: store.currentPerson)).")
                        .font(DeuxStyle.title()).foregroundStyle(DeuxStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(DeuxStyle.date(Date(), weekday: true).capitalized)
                        .font(.subheadline).foregroundStyle(DeuxStyle.secondary)
                }
                Spacer(minLength: 0)
                Button(action: add) {
                    Image(systemName: "plus").font(.system(size: 20, weight: .medium))
                        .foregroundStyle(DeuxStyle.forest).frame(width: 46, height: 46)
                        .background(DeuxStyle.sage, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ajouter une tâche")
            }
        }
    }

    private var progressCard: some View {
        let total = todayDone + dueTasks.count
        let progress = total == 0 ? 0 : Double(todayDone) / Double(total)
        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Votre élan commun", color: DeuxStyle.sage)
                    Text(todayDone > 0 ? "Les petits gestes\nfont du bien." : "On fait place\nau temps à deux.")
                        .font(DeuxStyle.title(28)).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if !dynamicTypeSize.isAccessibilitySize {
                    HouseIllustration(onDark: true)
                        .scaleEffect(0.66).frame(width: 112, height: 112)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(todayDone)").font(.system(.largeTitle, design: .serif, weight: .medium))
                    Text(todayDone == 1 ? "chose réglée aujourd’hui" : "choses réglées aujourd’hui")
                        .font(.subheadline).foregroundStyle(DeuxStyle.sage)
                }
                .foregroundStyle(.white)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.13))
                        Capsule().fill(DeuxStyle.apricot).frame(width: geometry.size.width * progress)
                    }
                }
                    .frame(height: 5)
                    .accessibilityElement()
                    .accessibilityLabel("Progression des tâches du jour et en retard")
                    .accessibilityValue("\(todayDone) réalisées, \(dueTasks.count) à faire")
                HStack(alignment: .top, spacing: 12) {
                    Label("\(DeuxStyle.duration(weekMinutes)) cette semaine", systemImage: "leaf")
                    Spacer(minLength: 0)
                    if overdueCount > 0 {
                        Text("\(overdueCount) en retard").multilineTextAlignment(.trailing)
                    }
                }
                .font(.caption).foregroundStyle(DeuxStyle.sage)
            }
        }
        .padding(23)
        .background(DeuxStyle.forest, in: RoundedRectangle(cornerRadius: 28))
    }
}
