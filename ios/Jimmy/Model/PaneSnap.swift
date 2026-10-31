import CoreGraphics

/// Where a swipe on the Workout page comes to rest.
///
/// The page is one scroll: each exercise (or group) is a pane at least one screen tall, stacked
/// top to bottom. A swipe moves at most one exercise and lands on its title. A pane taller than the
/// screen scrolls freely and stops at its end first, so nothing on it is ever skipped.
///
/// The page used to be a scroll of panes that were each a scroll of their own. Both took the same
/// up and down swipe, so a swipe often moved the card inside its pane instead of changing
/// exercise, and a tall card had to reach its end before another swipe could leave it.
enum PaneSnap {
    /// How far a swipe has to carry, its coast included, to change exercise: a share of the screen.
    /// A light flick is enough; a small drag springs back.
    static let nudge: CGFloat = 0.12
    /// Coming to rest this close to a pane's title or end settles exactly on it, so a swipe never
    /// stops a few points short and leaves the next one stuck on the same pane. A swipe that starts
    /// this close to the end counts as starting at the end, so a card only a little taller than the
    /// screen never spends a whole swipe on its last few points.
    static let magnet: CGFloat = 0.1
    /// Empty space under each pane, taller than the tab bar, so the next exercise never shows
    /// through the bar while you're on this one.
    static let gap: CGFloat = 120

    /// - Parameters:
    ///   - start: the scroll offset when the swipe began
    ///   - coast: where the swipe would come to rest on its own
    ///   - heights: each pane's height, top to bottom; anything under a screen counts as a screen
    ///   - page: the height of the screen the panes scroll in
    ///   - gap: the empty space under each pane
    static func rest(start: CGFloat, coast: CGFloat, heights: [CGFloat], page: CGFloat, gap: CGFloat = 0) -> CGFloat {
        guard page > 0, !heights.isEmpty else { return coast }
        let sizes = heights.map { max($0, page) }
        var tops: [CGFloat] = []
        var y: CGFloat = 0
        for s in sizes { tops.append(y); y += s + max(0, gap) }
        // The last offset that still shows a pane: its bottom on the screen's bottom.
        let ends = zip(tops, sizes).map { $0 + $1 - page }
        let last = sizes.count - 1
        let nudge = page * Self.nudge, magnet = page * Self.magnet
        let eps: CGFloat = 1

        // The pane the swipe began on: the last one whose title had reached the top.
        let i = tops.lastIndex { $0 <= start + eps } ?? 0
        let top = tops[i], end = ends[i]
        let next = i < last ? tops[i + 1] : end

        /// Inside a tall pane the swipe stays where it coasts to, unless that's next to an edge.
        func settle(_ c: CGFloat) -> CGFloat {
            if c <= top + magnet { return top }
            if c >= end - magnet { return end }
            return c
        }

        // Within the magnet of this pane's end or title counts as being there.
        let atEnd = start >= end - max(eps, magnet)
        let atTop = start <= top + max(eps, magnet)

        let goal: CGFloat
        if start > end + eps {
            // Caught between two exercises while the last swipe settled: carry on the way it's going.
            if coast > start + eps { goal = next }
            else if coast < start - eps { goal = end }
            else { goal = start - end < next - start ? end : next }
        } else if coast > start {
            // Toward the next exercise. From the end of this one, a nudge is enough.
            if atEnd {
                goal = i < last && coast - end >= nudge ? next : end
            } else {
                goal = settle(min(coast, end))
            }
        } else if coast < start {
            // Back toward the one before. From this one's title, a nudge lands on that one's title.
            if atTop {
                goal = i > 0 && top - coast >= nudge ? tops[i - 1] : top
            } else {
                goal = settle(max(coast, top))
            }
        } else {
            goal = settle(coast)
        }
        return min(max(goal, 0), ends[last])
    }
}
