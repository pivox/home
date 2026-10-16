import SwiftUI
import DeuxCore
import DeuxPersistence

private enum PlanningScope: String, CaseIterable {
    case day = "Cette date", overdue = "En retard", upcoming = "À venir", completed = "Réalisées"
}

struct PlanningView: View {
    @ObservedObject var store: HouseholdStore
    let add: () -> Void
    let edit: (HouseTask) -> Void
    let complete: (HouseTask) -> Void
    @ViewState private var selectedDate = Date()
    @ViewState private var scope: PlanningScope = .day
    @ViewState private var category: TaskCategory?
    @ViewState private var person: PersonFilter = .everyone
    @ViewState private var error: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var calendar: Calendar {
        var result = Calendar.current
        result.locale = Locale(identifier: "fr_FR")
        result.firstWeekday = 2
        return result
    }

    private var week: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var filteredTasks: [HouseTask] {
        store.tasks.filter { task in
            guard task.completedAt == nil, person.includes(task), category == nil || task.category == category else { return false }
            switch scope {
            case .day: return calendar.isDate(task.dueDate, inSameDayAs: selectedDate)
            case .overdue: return calendar.startOfDay(for: task.dueDate) < calendar.startOfDay(for: Date())
            case .upcoming: return calendar.startOfDay(for: task.dueDate) > calendar.startOfDay(for: Date())
            case .completed: return false
            }
        }.sorted { $0.dueDate < $1.dueDate }
    }

    private var filteredCompletions: [TaskCompletion] {
        store.completions.filter { completion in
            guard calendar.isDate(completion.completedAt, inSameDayAs: selectedDate), person.includes(assignee: completion.completedBy) else { return false }
            guard let category else { return true }
            return store.tasks.first { $0.id == completion.taskID }?.category == category
        }.sorted { $0.completedAt > $1.completedAt }
    }

    private var routines: [HouseTask] {
        store.tasks.filter { $0.completedAt == nil && $0.recurrence != .none && person.includes($0) && (category == nil || $0.category == category) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var listTitle: String {
        switch scope {
        case .day: return calendar.isDateInToday(selectedDate) ? "Au programme aujourd’hui" : DeuxStyle.date(selectedDate, weekday: true).capitalized
        case .overdue: return "On reprend le fil"
        case .upcoming: return "Les prochains jours"
        case .completed: return "Les gestes réalisés"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Un peu d’avance")
                        Text("Le rythme de la maison.").font(DeuxStyle.title()).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button(action: add) {
                        Image(systemName: "plus").font(.title3).frame(width: 46, height: 46)
                            .background(DeuxStyle.sage, in: Circle())
                    }.buttonStyle(.plain).accessibilityLabel("Ajouter une tâche")
                }
                .accessibilityElement(children: .contain)
                StoreErrorBanner(store: store)
                calendarCard
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PlanningScope.allCases, id: \.self) { item in
                                FilterPill(title: item.rawValue, selected: scope == item) { scope = item }
                            }
                        }.padding(.vertical, 2)
                    }.accessibilityLabel("Filtrer par état et période")
                    PersonFilters(store: store, selection: $person)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterPill(title: "Toutes les catégories", selected: category == nil) { category = nil }
                            ForEach(TaskCategory.allCases, id: \.self) { item in
                                FilterPill(title: item.title, selected: category == item, symbol: item.symbolName) { category = item }
                            }
                        }.padding(.vertical, 2)
                    }.accessibilityLabel("Filtrer par catégorie")
                }
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: listTitle, detail: "\(scope == .completed ? filteredCompletions.count : filteredTasks.count)")
                    if scope == .completed {
                        Text("Réalisés le \(DeuxStyle.date(selectedDate)). Le filtre par personne indique qui a effectué le geste.")
                            .font(.caption).foregroundStyle(DeuxStyle.secondary)
                        if filteredCompletions.isEmpty {
                            EmptyState(symbol: "checkmark.circle", title: "Chaque geste a sa place.", message: "Aucune validation à cette date avec ces filtres. Retrouvez aussi tout l’historique dans Maison.")
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredCompletions) { completion in
                                    CompletionCard(completion: completion, personName: store.name(for: completion.completedBy)) {
                                        do { try store.undoCompletion(completion) }
                                        catch { self.error = error.localizedDescription }
                                    }
                                }
                            }
                        }
                    } else if filteredTasks.isEmpty {
                        EmptyState(symbol: scope == .overdue ? "checkmark.seal" : "calendar.badge.plus", title: scope == .overdue ? "Le fil est à jour." : "Une page encore libre.", message: "Aucune tâche pour cette période et ces filtres.", actionTitle: "Ajouter une tâche", action: add)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredTasks) { task in
                                TaskRow(task: task, assigneeName: task.assignee == .anyone ? "Au choix" : store.name(for: task.assignee), complete: { complete(task) }, edit: { edit(task) })
                            }
                        }
                    }
                }
                routineSection
                Button(action: add) { Label("Prévoir une tâche", systemImage: "plus") }.buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 28)
            .frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background(DeuxStyle.canvas)
        .screenChrome()
        .refreshable { await store.load() }
        .alert("Ce geste n’a pas pu être annulé", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("D’accord", role: .cancel) { error = nil }
        } message: { Text(error ?? "Réessayez dans un instant.") }
    }

    private var calendarCard: some View {
        PaperCard {
            VStack(spacing: 18) {
                HStack {
                    Text(selectedDate.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "fr_FR"))).capitalized)
                        .font(.headline).foregroundStyle(DeuxStyle.forest)
                    Spacer(minLength: 0)
                    Button("Ce jour") { selectedDate = Date(); if scope != .completed { scope = .day } }.font(.caption.weight(.semibold))
                    Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Semaine précédente")
                    Button { shiftWeek(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Semaine suivante")
                }
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(week, id: \.self) { date in
                                dayButton(date).frame(width: 68)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        ForEach(week, id: \.self) { date in
                            dayButton(date)
                        }
                    }
                }
                DatePicker("Choisir une date", selection: $selectedDate, displayedComponents: .date)
                    .font(.caption)
                    .onChange(of: selectedDate) { _, _ in if scope != .completed { scope = .day } }
            }
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
        let hasTasks = store.tasks.contains { $0.completedAt == nil && calendar.isDate($0.dueDate, inSameDayAs: date) }
        return Button {
            selectedDate = date
            if scope != .completed { scope = .day }
        } label: {
            VStack(spacing: 9) {
                Text(date.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "fr_FR"))))
                    .font(.caption)
                Text(date.formatted(.dateTime.day())).font(.system(.title3, design: .serif, weight: .medium))
                Circle().fill(hasTasks ? (selected ? DeuxStyle.apricot : DeuxStyle.forest) : Color.clear).frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .foregroundStyle(selected ? .white : DeuxStyle.forest)
            .background(selected ? DeuxStyle.forest : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(DeuxStyle.date(date, weekday: true))
        .accessibilityValue(hasTasks ? "Des tâches sont prévues" : "Aucune tâche")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func shiftWeek(_ delta: Int) {
        selectedDate = calendar.date(byAdding: .day, value: 7 * delta, to: selectedDate) ?? selectedDate
        if scope != .completed { scope = .day }
    }

    private var routineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading(title: "Les habitudes qui aident", detail: "\(routines.count)")
            if routines.isEmpty {
                Text("Une tâche récurrente revient au bon moment après chaque validation. Créez la vôtre, ou découvrez les routines de départ dans Maison.")
                    .font(.subheadline).foregroundStyle(DeuxStyle.secondary).padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DeuxStyle.sage.opacity(0.45), in: RoundedRectangle(cornerRadius: 20))
            } else {
                VStack(spacing: 0) {
                    ForEach(routines) { task in
                        Button { edit(task) } label: {
                            HStack(spacing: 12) {
                                CategoryIcon(category: task.category)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(task.title).font(.subheadline.weight(.semibold)).foregroundStyle(DeuxStyle.ink)
                                    Text("\(task.recurrence.title) · \(DeuxStyle.date(task.dueDate))")
                                        .font(.caption).foregroundStyle(DeuxStyle.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "repeat").font(.caption).foregroundStyle(DeuxStyle.forest)
                            }.padding(16).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        if task.id != routines.last?.id { Divider().padding(.leading, 72) }
                    }
                }
                .background(DeuxStyle.paper, in: RoundedRectangle(cornerRadius: 21))
            }
        }
    }
}
