import SwiftUI
import UIKit

/// A drag that only starts when it's mostly sideways, so an up or down swipe that begins on a set
/// row goes straight to the Workout page's scroll.
///
/// The set rows used a SwiftUI DragGesture for swipe-to-delete. Inside a ScrollView, from iOS 18 on,
/// that gesture holds on to every touch that starts on it, even as a simultaneous gesture, so a swipe
/// up from the set grid could stall the page or snap it back. A UIKit pan can refuse to begin when
/// the drag is vertical, which hands the swipe to the scroll.
@available(iOS 18.0, *)
struct SidewaysPan: UIGestureRecognizerRepresentable {
    /// The sideways distance so far.
    var changed: (CGFloat) -> Void
    /// The sideways distance and where the drag would carry to on its own; zero, zero if cancelled.
    var ended: (_ distance: CGFloat, _ predicted: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        let x = pan.translation(in: pan.view).x
        switch pan.state {
        case .began, .changed:
            changed(x)
        case .ended:
            // About a quarter second of coasting, close to what SwiftUI predicts for a drag.
            ended(x, x + pan.velocity(in: pan.view).x * 0.25)
        case .cancelled, .failed:
            ended(0, 0)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// Mostly sideways, or it's the page's swipe.
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let pan = g as? UIPanGestureRecognizer else { return true }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y) * 1.5
        }

        /// The page's scroll keeps working alongside, so a sideways swipe never locks it.
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

extension View {
    /// Sideways drags for this view, leaving up and down swipes to the scroll around it. Before
    /// iOS 18 a SwiftUI drag doesn't hold the scroll, so the older gesture is kept there.
    @ViewBuilder
    func sidewaysDrag<Older: Gesture>(_ older: Older, changed: @escaping (CGFloat) -> Void,
                                       ended: @escaping (_ distance: CGFloat, _ predicted: CGFloat) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            gesture(SidewaysPan(changed: changed, ended: ended))
        } else {
            simultaneousGesture(older)
        }
    }
}
