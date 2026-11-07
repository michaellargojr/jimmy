import SwiftUI
import UIKit

/// Press and hold, then move up or down: the set row lifts after the hold and follows the finger.
///
/// A UIKit long press, like SidewaysPan, because a SwiftUI drag inside the Workout page's scroll
/// holds on to every touch from iOS 18 on. This one only starts once the finger has stayed still
/// for the hold; a swipe before then fails it and goes to the page. Once it has started, the
/// page's scroll and the row's sideways swipe can't, so the page stays put while the row moves.
@available(iOS 18.0, *)
struct HoldDrag: UIGestureRecognizerRepresentable {
    var began: () -> Void
    /// How far the finger has moved up (negative) or down since the row lifted.
    var moved: (CGFloat) -> Void
    /// True when the system cut it short (a call, the app going away), so the row goes back.
    var ended: (_ cancelled: Bool) -> Void

    static let hold: TimeInterval = 0.35

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let g = UILongPressGestureRecognizer()
        g.minimumPressDuration = Self.hold
        g.allowableMovement = 10
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UILongPressGestureRecognizer, context: Context) {
        // Window points, so the distance doesn't depend on where the row sits.
        let y = g.location(in: nil).y
        switch g.state {
        case .began:
            context.coordinator.startY = y
            began()
        case .changed:
            moved(y - context.coordinator.startY)
        case .ended:
            ended(false)
        case .cancelled, .failed:
            ended(true)
        default:
            break
        }
    }

    final class Coordinator {
        var startY: CGFloat = 0
    }
}

extension View {
    /// Press-and-hold drag for a set row. Before iOS 18 rows don't move; the label cycle still works.
    @ViewBuilder
    func holdDrag(began: @escaping () -> Void, moved: @escaping (CGFloat) -> Void,
                  ended: @escaping (_ cancelled: Bool) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            gesture(HoldDrag(began: began, moved: moved, ended: ended))
        } else {
            self
        }
    }
}
