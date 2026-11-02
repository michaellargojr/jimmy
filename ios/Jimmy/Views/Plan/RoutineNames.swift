import SwiftUI

// No two routines share a name (Michael, Nov 2). A name alert that gets a name another routine
// already has says so, then opens again with what was typed (rules in Model/RoutineCopies.swift).

/// A name refused because another routine has it. `back` opens the name alert again.
struct NameTaken: Identifiable {
    let id = uid()
    let name: String
    let back: () -> Void
}

/// "You already have Push" - "Pick another name." OK goes back to the name alert. Each alert
/// waits for the one before it to go, or it is lost.
struct NameTakenAlert: ViewModifier {
    @Binding var request: NameTaken?
    @State private var shown: NameTaken? = nil

    func body(content: Content) -> some View {
        content
            .onChange(of: request?.id) { _, id in
                guard id != nil, let r = request else { return }
                request = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    shown = r
                }
            }
            .alert(Text("You already have \(shown?.name ?? "")"),
                   isPresented: Binding(get: { shown != nil }, set: { if !$0 { shown = nil } }),
                   presenting: shown) { t in
                Button("OK") {
                    let back = t.back
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        back()
                    }
                }
            } message: { _ in
                Text("Pick another name.")
            }
    }
}

extension View {
    func nameTakenAlert(_ request: Binding<NameTaken?>) -> some View { modifier(NameTakenAlert(request: request)) }
}
