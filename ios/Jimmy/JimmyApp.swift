import SwiftUI

@main
struct JimmyApp: App {
    @State private var store = AppStore()
    @State private var nav = AppNav()

    var body: some Scene {
        WindowGroup {
            RootView()
                // Tap away or scroll to close the keyboard, everywhere.
                .keyboardDismissal()
                .environment(store)
                .environment(nav)
                .onAppear {
                    if !store.loaded { store.load() }
                    #if DEBUG
                    // A test simulator can open straight on the Workout tab for screenshots (-openTab workout),
                    // and start the first routine with the next two exercises as a superset and the first
                    // exercise's sets logged (-demoWorkout all, -demoWorkout two for only its first two, or
                    // -demoWorkout second for all of them plus the first set of the superset's first member,
                    // so your set is the second member), so screenshots can show the landing and the chips.
                    let args = ProcessInfo.processInfo.arguments
                    if let d = args.firstIndex(of: "-demoWorkout"), store.activeWorkout == nil, let r = store.routines.first {
                        let which = d + 1 < args.count ? args[d + 1] : "all"
                        var w = store.startWorkout(from: r)
                        store.startClock(w.id)
                        w = store.workout(w.id) ?? w
                        for j in w.items[0].sets.indices.prefix(which == "two" ? 2 : w.items[0].sets.count) {
                            w.items[0].sets[j].weight = w.items[0].sets[j].weight ?? 20
                            w.items[0].sets[j].reps = 10
                        }
                        store.put(w)
                        if w.items.count >= 3 {
                            w = makeGroup(w, ids: [w.items[1].id, w.items[2].id])
                            store.put(w)
                            if which == "second", let j = w.items[1].sets.indices.first {
                                w.items[1].sets[j].weight = w.items[1].sets[j].weight ?? 20
                                w.items[1].sets[j].reps = 10
                                store.put(w)
                            }
                        }
                        nav.tab = .workout
                    }
                    if let i = args.firstIndex(of: "-openTab"), i + 1 < args.count, args[i + 1] == "workout" { nav.tab = .workout }
                    #endif
                }
        }
    }
}

/// In the order the bar shows them: Workout sits in the middle.
enum AppTab: Hashable { case home, plan, workout, history, settings }

@Observable
final class AppNav {
    var tab: AppTab = .home
    /// Bumped to ask the Workout page to go back to your set; `focusGlides` says whether it animates.
    var focusRequest = 0
    var focusGlides = true
    /// When the screen was last touched, anywhere. Read by timers, never by a view's body.
    @ObservationIgnored var lastTouch = Date()

    func goToSet(glide: Bool) {
        focusGlides = glide
        focusRequest += 1
    }

    /// Straight to the Workout page, already on your set: no tab animation, no scroll animation.
    func openWorkoutAtSet() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { tab = .workout }
        goToSet(glide: false)
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppNav.self) private var nav
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var visited: Set<AppTab> = [.home]
    /// When the app left the screen, so coming back can land on your set if you were gone a while.
    @State private var awayAt: Date? = nil
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
        .background(TouchWatch { nav.lastTouch = Date() })
        .overlay(alignment: .bottom) {
            // Out of the way while typing, like the system bar.
            if !keyboardUp {
                // Placed from the bottom of the screen, below the room the pages keep for it.
                // Tapping the Workout tile while already on the Workout page glides to your set.
                JimmyTabBar(tab: $nav.tab, onReselect: { t in
                    if t == .workout, store.activeWorkout != nil { nav.goToSet(glide: true) }
                })
                    .padding(.bottom, TabBarRoom.lift(device: deviceBottom))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .onChange(of: nav.tab, initial: true) { _, t in visited.insert(t) }
        // A live workout is where you are: the app opens on it, and comes back to it from the lock
        // screen or another app, already at your set, without a tap on the bar. A quick hop out
        // and back (shorter than the wait in Settings) leaves the page where you had it, since you
        // may have been looking ahead; a set always takes longer than that. Never turns this off.
        .onChange(of: store.loaded, initial: true) { _, loaded in
            if loaded, store.activeWorkout != nil { nav.openWorkoutAtSet() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: awayAt = Date()
            case .active:
                guard let since = awayAt else { return }
                awayAt = nil
                let wait = store.settings.returnAfter
                if wait > 0, store.activeWorkout != nil, Date().timeIntervalSince(since) >= Double(wait) {
                    nav.openWorkoutAtSet()
                } else {
                    // Time away doesn't count as sitting still: the wait starts over from here.
                    nav.lastTouch = Date()
                }
            default: break
            }
        }
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
