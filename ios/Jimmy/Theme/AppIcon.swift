import UIKit

/// Keeps the home-screen icon in the same color as the app. iOS always shows a short
/// "You have changed the icon" notice when an app switches its own icon.
enum AppIcon {
    @MainActor static func match(_ scheme: AccentScheme) {
        let app = UIApplication.shared
        guard app.supportsAlternateIcons, app.alternateIconName != scheme.iconName else { return }
        app.setAlternateIconName(scheme.iconName) { _ in }
    }
}
