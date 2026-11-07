import SwiftUI

// Right after a change to a workout's exercises: does the routine take it too? (Rules in
// Model/WorkoutRoutineChanges.swift.) The workout page and Overview each carry this; Overview
// shows it over itself, the workout page waits until nothing else is up.

/// Shows the question when one is waiting for this workout. Swiping it away is Just today.
struct RoutineAskSheet: ViewModifier {
    @Environment(AppStore.self) private var store
    let workoutId: String
    let waits: Bool
    @State private var shown: RoutineAsk? = nil

    func body(content: Content) -> some View {
        content
            .onChange(of: store.routineAsk?.id, initial: true) { _, id in
                guard let id, let ask = store.routineAsk, ask.workoutId == workoutId else { shown = nil; return }
                Task { @MainActor in
                    // A sheet, menu or alert on its way out goes first, or this one is lost.
                    try? await Task.sleep(for: .milliseconds(350))
                    while waits && somethingPresented() {
                        guard store.routineAsk?.id == id else { return }
                        try? await Task.sleep(for: .milliseconds(150))
                    }
                    if store.routineAsk?.id == id { shown = ask }
                }
            }
            .sheet(item: $shown, onDismiss: { store.dismissRoutineAsk() }) { ask in
                RoutineAskPanel(ask: ask)
            }
    }
}

extension View {
    /// `waits`: hold the question until no sheet or alert is up (the workout page).
    func routineAsk(workoutId: String, waits: Bool) -> some View {
        modifier(RoutineAskSheet(workoutId: workoutId, waits: waits))
    }
}

/// "Change Shoulders too?" - what changed - Update Shoulders, Save as new routine, Just today.
struct RoutineAskPanel: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let ask: RoutineAsk
    /// Held from the start, so the words don't change while the sheet slides away.
    private let routineName: String
    @State private var naming = false
    @State private var newName = ""
    @State private var taken: NameTaken? = nil
    @State private var height: CGFloat = 330

    init(ask: RoutineAsk) {
        self.ask = ask
        routineName = ask.proposed.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Change \(routineName) too?")
                .font(.system(size: 22, weight: .heavy)).foregroundStyle(p.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(store.routineAsk?.id == ask.id ? store.routineAsk?.summary ?? ask.summary : ask.summary)
                .font(.system(size: 15)).foregroundStyle(p.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            PillButton(title: "Update \(routineName)", style: .primary, full: true, height: 52) { store.acceptRoutineAsk() }
            PillButton(title: "Save as new routine", full: true, height: 52) {
                newName = copyName(routineName, taken: store.routines.map(\.name))
                naming = true
            }
            PillButton(title: "Just today", full: true, height: 52) { store.dismissRoutineAsk() }
        }
        .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { if $0 > 0 { height = $0 } }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(p.card)
        .alert("New routine", isPresented: $naming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saveAsNew() }
        }
        .nameTakenAlert($taken)
    }

    private func saveAsNew() {
        let n = newName.trimmingCharacters(in: .whitespaces)
        if routineNameTaken(n, in: store.routines) {
            let typed = newName
            taken = NameTaken(name: n) { newName = typed; naming = true }
            return
        }
        store.saveRoutineAskAsNew(named: n.isEmpty ? copyName(routineName, taken: store.routines.map(\.name)) : n)
    }
}
