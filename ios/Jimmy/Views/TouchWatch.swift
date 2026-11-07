import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Notes every touch on the window, so the Workout page knows how long you've been still.
/// The recognizer never wins: it fails the moment a touch begins and cancels nothing, so every
/// tap, swipe and scroll works exactly as before.
struct TouchWatch: UIViewRepresentable {
    var onTouch: () -> Void

    func makeUIView(context: Context) -> Probe {
        let v = Probe()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ v: Probe, context: Context) {
        v.onTouch = onTouch
        v.attach()
    }

    final class Probe: UIView {
        var onTouch: () -> Void = {}
        private var watcher: AnyTouch?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attach()
        }

        /// Once, on the window, when there is one.
        func attach() {
            guard let window, watcher == nil else { return }
            let w = AnyTouch(target: nil, action: nil)
            w.cancelsTouchesInView = false
            w.delaysTouchesBegan = false
            w.delaysTouchesEnded = false
            w.onTouch = { [weak self] in self?.onTouch() }
            window.addGestureRecognizer(w)
            watcher = w
        }
    }

    final class AnyTouch: UIGestureRecognizer, UIGestureRecognizerDelegate {
        var onTouch: () -> Void = {}

        override init(target: Any?, action: Selector?) {
            super.init(target: target, action: action)
            delegate = self
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            onTouch()
            state = .failed
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

/// True while a sheet, popover, alert or cover is up anywhere, so the page under it stays put.
@MainActor
func somethingPresented() -> Bool {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .contains { $0.rootViewController?.presentedViewController != nil }
}
