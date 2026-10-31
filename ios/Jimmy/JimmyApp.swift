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

enum AppTab: Hashable { case home, workout, plan, history, settings }

@Observable
final class AppNav {
    var tab: AppTab = .home
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNav.self) private var nav
    @Environment(\.colorScheme) private var systemScheme

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
        TabView(selection: $nav.tab) {
            HomeView().tabItem { Label("Home", systemImage: "house.fill") }.tag(AppTab.home)
            WorkoutTab().tabItem { Label("Workout", systemImage: "dumbbell.fill") }.tag(AppTab.workout)
            PlanView().tabItem { Label("Plan", systemImage: "square.text.square.fill") }.tag(AppTab.plan)
            HistoryView().tabItem { Label("History", systemImage: "chart.xyaxis.line") }.tag(AppTab.history)
            SettingsView().tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(AppTab.settings)
        }
        .tint(p.accent)
        .environment(\.palette, p)
        .onChange(of: store.settings.scheme) { _, s in AppIcon.match(s) }
        .preferredColorScheme(store.settings.appearance == .system ? nil : (isDark ? .dark : .light))
    }
}
