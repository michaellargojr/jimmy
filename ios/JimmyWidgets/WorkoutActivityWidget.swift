import ActivityKit
import SwiftUI
import WidgetKit

/// The lock screen card during a workout: the workout and its clock, your set's exercise, which
/// set it is and what you did last time. Everything it shows comes worked out from the app; a tap
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
}

/// Two big cues on one line, the set and the clock, as big as each other; under them the
/// exercise and its chips. Nothing else, so it reads at a glance mid-workout.
struct LockCard: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        let accent = Color(hex: state.accent)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                setCue(accent)
                Spacer(minLength: 0)
                // Counts by itself from Start; nothing updates it while you rest.
                Text(timerInterval: state.startedAt...state.startedAt.addingTimeInterval(24 * 3600), countsDown: false)
                    .font(.system(size: 48, weight: .heavy)).tracking(-1).monospacedDigit().foregroundStyle(Card.text)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 190, alignment: .trailing)
            }
            .frame(height: 52)
            Text(state.exercise)
                .font(.system(size: 20, weight: .heavy)).tracking(-0.3).foregroundStyle(Card.text)
                .lineLimit(1).minimumScaleFactor(0.7)
            if state.groupLabel != nil || !state.tags.isEmpty {
                HStack(spacing: 6) {
                    if let g = state.groupLabel { GroupChip(text: g, accent: accent, onAccent: Color(hex: state.onAccent)) }
                    if !state.tags.isEmpty { TagChip(parts: state.tags, accent: accent) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "of 2", or a warm-up or drop set by name, with the side in white for one arm ("of 2 - Left").
    private var setRest: Text {
        var words = state.setOf ?? state.setLine
        guard let side = state.side else { return Text(words).foregroundColor(Card.secondary) }
        if state.setOf == nil, words.hasSuffix(" - " + side) { words = String(words.dropLast(side.count + 3)) }
        return Text(words + " - ").foregroundColor(Card.secondary) + Text(side).fontWeight(.heavy).foregroundColor(Card.text)
    }

    /// "1 of 2", "1 of 2 - Left", "W Warm-up", or a check with "Done" once every set is logged.
    @ViewBuilder
    private func setCue(_ accent: Color) -> some View {
        if state.allDone {
            HStack(spacing: 8) {
                Image(systemName: "checkmark").font(.system(size: 34, weight: .heavy)).foregroundStyle(accent)
                Text("Done").font(.system(size: 17, weight: .semibold)).foregroundStyle(Card.secondary)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // Never squeezed: the clock gives way first.
                Text(state.setMark ?? "").font(.system(size: 52, weight: .heavy)).monospacedDigit().foregroundStyle(Card.text)
                    .fixedSize()
                setRest.font(.system(size: 17, weight: .semibold)).lineLimit(1).fixedSize()
            }
        }
    }
}

/// "Triset 1", filled with the accent like the chip on the Workout card.
struct GroupChip: View {
    let text: String
    let accent: Color
    let onAccent: Color
    var body: some View {
        Text(text).font(.system(size: 12.5, weight: .heavy)).foregroundStyle(onAccent).lineLimit(1)
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
                Text(t).font(.system(size: 12.5, weight: .heavy)).foregroundStyle(accent).lineLimit(1)
                    .padding(.horizontal, 8)
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
