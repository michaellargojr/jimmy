import SwiftUI

/// What the History group on a variation's page opens: copy or move its sessions to another
/// exercise, or erase them. Move and Erase each ask "Are you sure?", then a short Undo bar shows.
/// A copy or move lands on the target's history page, so you see the sessions arrive.
struct HistoryActions: ViewModifier {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    let versionId: String
    @Binding var picking: Bool
    @Binding var erasing: Bool

    private struct Target: Equatable { var version: Version; var styleId: String? }

    @State private var target: Target? = nil
    @State private var choosing = false
    @State private var sureMove = false
    @State private var landed: Version? = nil

    func body(content: Content) -> some View {
        let v = store.version(versionId)
        let n = historySessions(versionId, workouts: store.workouts).count
        let name = v.map { store.workoutName($0) } ?? ""
        content
            // The usual exercise search, titled "Copy to". Picking can make a new variation on the spot.
            .sheet(isPresented: $picking, onDismiss: { if target != nil { choosing = true } }) {
                AddExerciseSheet(title: "Copy to") { picked, style in
                    if picked.id != versionId { target = Target(version: picked, styleId: style?.id) }
                }
                .presentationDetents([.large])
                .presentationBackground(p.card)
            }
            .onChange(of: picking) { _, open in if open { target = nil } }
            .confirmationDialog(target.map { "\(sessionsText(n)) to \(store.workoutName($0.version))" } ?? "",
                                isPresented: $choosing, titleVisibility: .visible) {
                Button("Copy") { run(move: false) }
                Button("Move", role: .destructive) { sureMove = true }
                Button("Cancel", role: .cancel) { target = nil }
            }
            .alert("Are you sure?", isPresented: $sureMove) {
                Button("Move", role: .destructive) { run(move: true) }
                Button("Cancel", role: .cancel) { target = nil }
            } message: {
                Text("\(name) loses \(sessionsText(n)).")
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
    func historyActions(versionId: String, picking: Binding<Bool>, erasing: Binding<Bool>) -> some View {
        modifier(HistoryActions(versionId: versionId, picking: picking, erasing: erasing))
    }
    func historyUndoBar(versionId: String) -> some View { modifier(HistoryUndoBar(versionId: versionId)) }
}
