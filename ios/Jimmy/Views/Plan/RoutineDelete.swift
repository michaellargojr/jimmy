import SwiftUI

/// What deleting a routine does, said before it happens (Michael, Nov 2).
func routineDeleteMessage(_ name: String) -> String {
    "\(name) will be gone from your routines and from every split it's in. Workouts you've already done stay in History."
}

/// "Delete from everywhere?" before a routine leaves the app. Set the routine to ask; Delete
/// deletes it, Cancel keeps it.
struct RoutineDeleteAlert: ViewModifier {
    @Environment(AppStore.self) private var store
    @Binding var routine: Routine?

    func body(content: Content) -> some View {
        content.alert("Delete from everywhere?",
                      isPresented: Binding(get: { routine != nil }, set: { if !$0 { routine = nil } }),
                      presenting: routine) { r in
            Button("Delete", role: .destructive) { store.deleteRoutine(r.id); routine = nil }
            Button("Cancel", role: .cancel) { routine = nil }
        } message: { r in
            Text(routineDeleteMessage(r.name))
        }
    }
}

extension View {
    func routineDeleteAlert(_ routine: Binding<Routine?>) -> some View { modifier(RoutineDeleteAlert(routine: routine)) }
}
