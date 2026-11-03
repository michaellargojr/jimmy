import ActivityKit
import SwiftUI
import WidgetKit

/// The lock screen card during a workout (layout C3): which set it is, the workout clock, and
/// your set's exercise with its chips. Everything it shows comes worked out from the app; a tap
/// anywhere opens the app at your set.
struct WorkoutActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockCard(state: context.state)
                .activityBackgroundTint(Card.bg)
                .activitySystemActionForegroundColor(Color(hex: context.state.accent))
                .widgetURL(Card.url)
        } dynamicIsland: { context in
            // His phone has no Dynamic Island, so this stays bare: the same words, nothing more.
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(s.exercise).font(.system(size: 17, weight: .heavy)).foregroundStyle(Card.text)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(s.setLine).font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: s.accent))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Text(s.setMark ?? "J").font(.system(size: 15, weight: .heavy)).foregroundStyle(Color(hex: s.accent))
            } compactTrailing: {
                Text(s.setOf ?? "").font(.system(size: 13, weight: .semibold)).foregroundStyle(Card.secondary)
            } minimal: {
                Text(s.setMark ?? "J").font(.system(size: 15, weight: .heavy)).foregroundStyle(Color(hex: s.accent))
            }
            .widgetURL(Card.url)
        }
    }
}

/// The app's dark card colors, so the lock screen card looks like the Workout page.
enum Card {
    static let url = URL(string: "jimmy://workout")
    static let bg = Color(hex: 0x141518)
    static let text = Color(hex: 0xF3F4F6)
    static let secondary = Color(hex: 0xA1A3AB)
    static let muted = Color(hex: 0x8B8E97)
    static let tile = Color(hex: 0x1F2024)
}

/// Layout C3: a tall tile with the set ("1" over "of 2", and the side for one arm), and beside it
/// the clock, the exercise and its chips. Nothing else, so it reads at a glance mid-workout.
struct LockCard: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        let accent = Color(hex: state.accent)
        HStack(alignment: .center, spacing: 12) {
            setTile(accent)
            VStack(alignment: .leading, spacing: 5) {
                // Counts by itself from Start; nothing updates it while you rest. Digits have no
                // descenders, so the line is drawn a little shorter than the font to keep the card low.
                Text(timerInterval: state.startedAt...state.startedAt.addingTimeInterval(24 * 3600), countsDown: false)
                    .font(.system(size: 44, weight: .heavy)).tracking(-1).monospacedDigit().foregroundStyle(Card.text)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 46)
                Text(state.exercise)
                    .font(.system(size: 19, weight: .heavy)).tracking(-0.3).foregroundStyle(Card.text)
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                if state.groupLabel != nil || !state.tags.isEmpty {
                    HStack(spacing: 6) {
                        if let g = state.groupLabel { GroupChip(text: g, accent: accent, onAccent: Color(hex: state.onAccent)) }
                        if !state.tags.isEmpty { TagChip(parts: state.tags, accent: accent) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The tile grows to the height of the words beside it, and no taller.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "of 2", or a warm-up or drop set by name ("Warm-up", without the side: that goes under it).
    private var setWords: String {
        if let of = state.setOf { return of }
        guard let side = state.side, state.setLine.hasSuffix(" - " + side) else { return state.setLine }
        return String(state.setLine.dropLast(side.count + 3))
    }

    /// "1" over "of 2", "W" over "Warm-up", the side in white under them for one arm, or a check
    /// once every set is logged.
    private func setTile(_ accent: Color) -> some View {
        VStack(spacing: 2) {
            if state.allDone {
                Image(systemName: "checkmark").font(.system(size: 32, weight: .heavy)).foregroundStyle(accent)
            } else {
                Text(state.setMark ?? "").font(.system(size: 52, weight: .heavy)).monospacedDigit().foregroundStyle(Card.text)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(setWords).font(.system(size: 14, weight: .semibold)).foregroundStyle(Card.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                if let side = state.side {
                    Text(side).font(.system(size: 13, weight: .heavy)).foregroundStyle(Card.text).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .frame(width: 76)
        .frame(maxHeight: .infinity)
        .background(Card.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// "Triset 1", filled with the accent like the chip on the Workout card.
struct GroupChip: View {
    let text: String
    let accent: Color
    let onAccent: Color
    var body: some View {
        Text(text).font(.system(size: 12.5, weight: .heavy)).foregroundStyle(onAccent).lineLimit(1).minimumScaleFactor(0.8)
            .padding(.horizontal, 9).frame(height: 24)
            .background(accent, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

/// The variation's words in one accent outline with a thin line between them, like the small
/// variation chip in the app: "Two arms | Seated".
struct TagChip: View {
    let parts: [String]
    let accent: Color
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { i, t in
                if i > 0 { Rectangle().fill(accent.opacity(0.45)).frame(width: 1, height: 12) }
                Text(t).font(.system(size: 12.5, weight: .heavy)).foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.horizontal, 7)
            }
        }
        .frame(height: 24)
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(accent.opacity(0.7), lineWidth: 1))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
