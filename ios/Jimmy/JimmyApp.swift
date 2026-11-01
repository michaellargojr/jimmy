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
                #if DEBUG
                // A test simulator can open straight on the Workout tab for screenshots: -openTab workout
                .onAppear {
                    let args = ProcessInfo.processInfo.arguments
                    if let i = args.firstIndex(of: "-openTab"), i + 1 < args.count, args[i + 1] == "workout" { nav.tab = .workout }
                }
                #endif
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
    /// The phone's own bottom safe area: the home indicator's, or 0 with a Home button.
    @State private var deviceBottom: CGFloat = 0

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
        ZStack {
            page(.home) { HomeView() }
            page(.plan) { PlanView() }
            page(.workout) { WorkoutTab() }
            page(.history) { HistoryView() }
            page(.settings) { SettingsView() }
        }
        .background(p.bg.ignoresSafeArea())
        // Every page, pushed ones included, keeps room under the bar for its last row.
        .background(TabBarRoomSetter(deviceBottom: $deviceBottom))
        .overlay(alignment: .bottom) {
            // Out of the way while typing, like the system bar.
            if !keyboardUp {
                // Placed from the bottom of the screen, below the room the pages keep for it.
                JimmyTabBar(tab: $nav.tab)
                    .padding(.bottom, TabBarRoom.lift(device: deviceBottom))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(.container, edges: .bottom)
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
