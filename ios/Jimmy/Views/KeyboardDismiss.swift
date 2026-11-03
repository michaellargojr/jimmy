import SwiftUI
import UIKit

// How the keyboard goes away, on every page, sheet and cover:
// - a tap anywhere away from the field you're typing in,
// - a scroll,
// - Return, in fields that never need a line break.
// Taps on the field's own row keep it up: a search box's clear button, Ideas' Add, the padding
// around the field, and anywhere in a box marked keepsKeyboard(). Long fields (goals, notes) keep
// Return for a new line.

extension View {
    /// Once, at the root of the window.
    func keyboardDismissal() -> some View {
        background(KeyboardDismisser()).scrollDismissesKeyboard(.immediately)
    }

    /// A box around a field that is all for typing in: taps anywhere in it keep the keyboard up.
    func keepsKeyboard() -> some View {
        background(KeyboardKeeper())
    }

    /// For a field that wraps onto more lines but is one thought: Return closes the keyboard
    /// instead of starting a new line.
    func returnCloses(_ text: Binding<String>) -> some View {
        submitLabel(.done)
            .onChange(of: text.wrappedValue) { _, t in
                guard let one = KeyboardDismiss.withoutLineBreaks(t) else { return }
                text.wrappedValue = one
                KeyboardDismiss.close()
            }
    }
}

enum KeyboardDismiss {
    /// Taps this close above or below the field still count as its row.
    static let rowSlack: CGFloat = 16

    /// A tap at `y` closes the keyboard unless it lands on the field's own row.
    static func closes(tapY y: CGFloat, fieldTop: CGFloat, fieldBottom: CGFloat) -> Bool {
        y < fieldTop - rowSlack || y > fieldBottom + rowSlack
    }

    /// The text with Return taken out, or nil when it has no line break.
    static func withoutLineBreaks(_ s: String) -> String? {
        guard s.contains(where: \.isNewline) else { return nil }
        return String(s.filter { !$0.isNewline })
    }

    @MainActor static func close() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Puts one tap recognizer on the window. It only listens while the keyboard is up, never takes
/// a touch from anything under it, and leaves alerts alone (their buttons close them).
struct KeyboardDismisser: UIViewRepresentable {
    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ v: Probe, context: Context) {}

    final class Probe: UIView, UIGestureRecognizerDelegate {
        private lazy var tap: UITapGestureRecognizer = {
            let t = UITapGestureRecognizer(target: self, action: #selector(tapped))
            t.cancelsTouchesInView = false
            t.delaysTouchesEnded = false
            t.isEnabled = false
            t.delegate = self
            return t
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            let nc = NotificationCenter.default
            nc.addObserver(self, selector: #selector(keyboardShows), name: UIResponder.keyboardWillShowNotification, object: nil)
            nc.addObserver(self, selector: #selector(keyboardHides), name: UIResponder.keyboardWillHideNotification, object: nil)
        }

        required init?(coder: NSCoder) { return nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard tap.view !== window else { return }
            tap.view?.removeGestureRecognizer(tap)
            window?.addGestureRecognizer(tap)
        }

        @objc private func keyboardShows() { tap.isEnabled = true }
        @objc private func keyboardHides() { tap.isEnabled = false }
        @objc private func tapped() { tap.view?.endEditing(true) }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let root = g.view, let field = FirstResponder.current as? UIView else { return false }
            if field.sits(in: UIAlertController.self) { return false }
            // A tap on a field, this one or another, puts the cursor there instead.
            var v = touch.view
            while let x = v {
                if x is UITextInput { return false }
                v = x.superview
            }
            let p = touch.location(in: root)
            for box in KeyboardKeeper.Box.all.allObjects where box.window === root {
                if box.convert(box.bounds, to: root).contains(p) { return false }
            }
            let r = field.convert(field.bounds, to: root)
            return KeyboardDismiss.closes(tapY: p.y, fieldTop: r.minY, fieldBottom: r.maxY)
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

/// Marks where `keepsKeyboard()` was put, for the tap recognizer to look up.
struct KeyboardKeeper: UIViewRepresentable {
    func makeUIView(context: Context) -> Box { Box() }
    func updateUIView(_ v: Box, context: Context) {}

    final class Box: UIView {
        static let all = NSHashTable<Box>.weakObjects()

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            Self.all.add(self)
        }

        required init?(coder: NSCoder) { return nil }
    }
}

@MainActor
private enum FirstResponder {
    static weak var found: UIResponder?

    /// Whatever has the keyboard right now, found by asking the responder chain.
    static var current: UIResponder? {
        found = nil
        UIApplication.shared.sendAction(#selector(UIResponder.jimmyReportFirstResponder), to: nil, from: nil, for: nil)
        return found
    }
}

private extension UIResponder {
    @objc func jimmyReportFirstResponder() { FirstResponder.found = self }

    func sits<T: UIResponder>(in kind: T.Type) -> Bool {
        var r: UIResponder? = self
        while let x = r {
            if x is T { return true }
            r = x.next
        }
        return false
    }
}
