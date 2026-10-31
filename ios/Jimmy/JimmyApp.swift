import SwiftUI

@main
struct JimmyApp: App {
    @State private var store = AppStore()
    @State private var nav = AppNav()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(nav)
                .onAppear { if !store.loaded { store.load() } }
        }
    }
}

/// In the order the bar shows them: Workout sits in the middle.
enum AppTab: Hashable { case home, plan, workout, history, settings }

@Observable
final class AppNav {
    var tab: AppTab = .home
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNav.self) private var nav
    @Environment(\.colorScheme) private var systemScheme
    @State private var visited: Set<AppTab> = [.home]
    @State private var keyboardUp = false

    private var isDark: Bool {
        switch store.settings.appearance {
        case .dark: return true
        case .light: return false
        case .system: return systemScheme == .dark
        }
    }

    var body: some View {
        @Bindable var nav = nav
        let p = Palette.make(scheme: store.settings.scheme, dark: isDark)
        // Each tab is built the first time it's opened and then kept, so it stays where you left it.
        GeometryReader { geo in
            ZStack {
                page(.home) { HomeView() }
                page(.plan) { PlanView() }
                page(.workout) { WorkoutTab() }
                page(.history) { HistoryView() }
                page(.settings) { SettingsView() }
            }
            .background(p.bg.ignoresSafeArea())
            // The extra spacing lets the last thing on a page scroll clear of the Workout tile.
            .safeAreaInset(edge: .bottom, spacing: 16) {
                // Out of the way while typing, like the system bar.
                if !keyboardUp {
                    // Floats low, a little into the home indicator's space, like the system's bar.
                    JimmyTabBar(tab: $nav.tab)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? -10 : 8)
                }
            }
        }
        .onChange(of: nav.tab, initial: true) { _, t in visited.insert(t) }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
        .tint(p.accent)
        .environment(\.palette, p)
        .onChange(of: store.settings.scheme) { _, s in AppIcon.match(s) }
        .preferredColorScheme(store.settings.appearance == .system ? nil : (isDark ? .dark : .light))
    }

    @ViewBuilder
    private func page<Content: View>(_ t: AppTab, @ViewBuilder _ content: () -> Content) -> some View {
        if visited.contains(t) || nav.tab == t {
            content()
                .opacity(nav.tab == t ? 1 : 0)
                .allowsHitTesting(nav.tab == t)
                .accessibilityHidden(nav.tab != t)
        }
    }
}
