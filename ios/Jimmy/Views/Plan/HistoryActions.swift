import SwiftUI

/// The rows of the History group on a variation's page, in order.
enum HistoryPick: CaseIterable, Identifiable {
    case move, copy
    var id: Self { self }
    var row: String { self == .move ? "Move history to…" : "Copy history to…" }
    var sheetTitle: String { self == .move ? "Move to" : "Copy to" }
}

/// What the History group on a variation's page opens: move or copy its sessions to another
/// exercise, or erase them. Move and Erase each ask "Are you sure?", then a short Undo bar shows.
/// A move or copy lands on the target's history page, so you see the sessions arrive.
struct HistoryActions: ViewModifier {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let versionId: String
    @Binding var picking: HistoryPick?
    @Binding var erasing: Bool

    private struct Target: Equatable { var version: Version; var styleId: String? }

    @State private var pick: HistoryPick = .move
    @State private var target: Target? = nil
    @State private var sureMove = false
    @State private var landed: Version? = nil

    func body(content: Content) -> some View {
        let v = store.version(versionId)
        let n = historySessions(versionId, workouts: store.workouts).count
        let name = v.map { store.workoutName($0) } ?? ""
        content
            // The usual exercise search, titled "Move to" or "Copy to". Picking can make a new variation on the spot.
            .sheet(item: $picking, onDismiss: afterSearch) { which in
                AddExerciseSheet(title: which.sheetTitle) { chosen, style in
                    if chosen.id != versionId { target = Target(version: chosen, styleId: style?.id) }
                }
                .presentationDetents([.large])
                .presentationBackground(p.card)
            }
            .onChange(of: picking) { _, open in if let open { pick = open; target = nil } }
            .alert("Are you sure?", isPresented: $sureMove) {
                Button("Move", role: .destructive) { run(move: true) }
                Button("Cancel", role: .cancel) { target = nil }
            } message: {
                Text(target.map { "\(sessionsText(n)) go to \(store.workoutName($0.version)). \(name) loses them." } ?? "")
            }
            .alert("Are you sure?", isPresented: $erasing) {
                Button("Erase", role: .destructive) { if let v { store.eraseHistory(v) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Erase \(sessionsText(n)) of \(name).")
            }
            .navigationDestination(item: $landed) { t in ExerciseProgressView(versionId: t.id) }
            .historyUndoBar(versionId: versionId)
    }

    /// After the search closes: a copy goes straight through (Undo covers it), a move asks first.
    private func afterSearch() {
        guard target != nil else { return }
        if pick == .move { sureMove = true } else { run(move: false) }
    }

    private func run(move: Bool) {
        guard let v = store.version(versionId), let t = target else { return }
        store.copyHistory(from: v, to: t.version, styleId: t.styleId, move: move)
        target = nil
        landed = store.version(t.version.id)
    }
}

/// "Moved 2 sessions   Undo", for a few seconds on the page a history change landed on.
struct HistoryUndoBar: ViewModifier {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let versionId: String

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let u = store.historyUndo, u.landedOn == versionId { bar(u) }
            }
            .animation(.snappy, value: store.historyUndo?.id)
    }

    private func bar(_ u: HistoryUndo) -> some View {
        HStack {
            Text(u.message).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
            Spacer()
            Button("Undo") {
                store.undoHistory()
                // After a copy or move this is the target's page, pushed from the variation: go back there.
                if u.kind != .erase { dismiss() }
            }
            .font(.system(size: 16, weight: .heavy)).foregroundStyle(p.accent)
        }
        .padding(.horizontal, 18).frame(height: 56)
        .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        .padding(.horizontal, 16).padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task(id: u.id) {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if store.historyUndo?.id == u.id { store.historyUndo = nil }
        }
    }
}

extension View {
    func historyActions(versionId: String, picking: Binding<HistoryPick?>, erasing: Binding<Bool>) -> some View {
        modifier(HistoryActions(versionId: versionId, picking: picking, erasing: erasing))
    }
    func historyUndoBar(versionId: String) -> some View { modifier(HistoryUndoBar(versionId: versionId)) }
}
