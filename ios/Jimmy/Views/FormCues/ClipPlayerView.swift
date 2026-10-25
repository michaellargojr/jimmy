import SwiftUI
import AVFoundation

/// Full-screen viewer for a variation's clips. Videos start muted and loop. Grab the round
/// handle to scrub frame by frame; ½× plays at half speed. Swipe sideways on the picture
/// for the next clip, down to close.
struct ClipPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var p
    let clips: [Clip]
    @State private var index: Int
    @State private var dragY: CGFloat = 0

    init(clips: [Clip], start: Int) {
        self.clips = clips
        _index = State(initialValue: min(max(start, 0), max(clips.count - 1, 0)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if clips.indices.contains(index) {
                let c = clips[index]
                Group {
                    switch c.kind {
                    case .video: VideoPage(clip: c, onSwipe: swipe)
                    case .photo: PhotoPage(clip: c, onSwipe: swipe)
                    }
                }
                .id(c.id)
                .transition(.opacity)
            }
            HStack {
                Text(clips.count > 1 ? "\(index + 1) of \(clips.count)" : "")
                    .font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(.white.opacity(0.8))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16).padding(.top, 8)
        }
        .offset(y: dragY)
        .statusBarHidden()
        .onAppear { PlayerAudio.quiet() }
        .onDisappear { PlayerAudio.release() }
    }

    /// Called by a page when the picture is dragged.
    private func swipe(_ t: CGSize, ended: Bool) {
        let vertical = abs(t.height) > abs(t.width)
        if !ended {
            if vertical, t.height > 0 { dragY = t.height }
            return
        }
        if vertical {
            if t.height > 120 { dismiss() } else { withAnimation(.spring(duration: 0.25)) { dragY = 0 } }
        } else if t.width < -60, index < clips.count - 1 {
            withAnimation(.easeOut(duration: 0.15)) { index += 1 }
        } else if t.width > 60, index > 0 {
            withAnimation(.easeOut(duration: 0.15)) { index -= 1 }
        }
    }
}

// MARK: - Video

private struct VideoPage: View {
    @Environment(\.palette) private var p
    let clip: Clip
    let onSwipe: (CGSize, Bool) -> Void
    @State private var model = PlayerModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            PlayerLayerView(player: model.player).ignoresSafeArea()
            // Gestures live on a clear layer over the picture, not on the controls.
            Color.clear.contentShape(Rectangle())
                .onTapGesture { model.toggle() }
                .gesture(DragGesture(minimumDistance: 24)
                    .onChanged { onSwipe($0.translation, false) }
                    .onEnded { onSwipe($0.translation, true) })
            controls
        }
        .onAppear { model.load(ClipFiles.url(clip)); model.play() }
        .onDisappear { model.stop() }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Scrubber(progress: model.progress, dragging: model.scrubbing,
                     onBegin: model.beginScrub, onChange: model.scrub(to:), onEnd: model.endScrub)
            HStack(spacing: 0) {
                Text("\(timeText(model.current)) / \(timeText(model.duration))")
                    .font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { model.toggle() } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 60, height: 48)
                }
                .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
                HStack(spacing: 6) {
                    speedButton("½×", rate: 0.5)
                    speedButton("1×", rate: 1)
                    Button { model.toggleMute() } label: {
                        Image(systemName: model.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 36, height: 32)
                            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .accessibilityLabel(model.muted ? "Sound on" : "Sound off")
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 20).padding(.top, 40).padding(.bottom, 12)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private func speedButton(_ title: String, rate: Float) -> some View {
        let on = model.rate == rate
        return Button { model.setRate(rate) } label: {
            Text(title).font(.system(size: 13, weight: .heavy))
                .foregroundStyle(on ? p.onAccent : .white)
                .frame(width: 40, height: 32)
                .background(on ? p.accent : .white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .accessibilityLabel(rate == 1 ? "Normal speed" : "Half speed")
    }

    private func timeText(_ s: Double) -> String { clipDuration(max(0, s)) ?? "0:00" }
}

/// Progress bar with a round handle you can grab. Touching anywhere on the bar jumps there
/// and keeps following the finger. The picture pauses while you hold it.
private struct Scrubber: View {
    @Environment(\.palette) private var p
    let progress: Double
    let dragging: Bool
    let onBegin: () -> Void
    let onChange: (Double) -> Void
    let onEnd: () -> Void

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let x = CGFloat(min(max(progress, 0), 1)) * w
            let knob: CGFloat = dragging ? 26 : 20
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.25)).frame(height: 4)
                RoundedRectangle(cornerRadius: 2).fill(p.accent).frame(width: x, height: 4)
                Circle().fill(p.accent)
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .offset(x: x - knob / 2)
                    .animation(.easeOut(duration: 0.12), value: dragging)
            }
            .frame(width: w, height: 44)
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if !dragging { onBegin() }
                    onChange(Double(min(max(g.location.x / w, 0), 1)))
                }
                .onEnded { _ in onEnd() })
        }
        .frame(height: 44)
        .accessibilityElement()
        .accessibilityLabel("Position")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

/// Owns one AVPlayer. Seeks while scrubbing are exact and chained (a new one starts only
/// when the last finished) so dragging stays smooth.
@Observable
final class PlayerModel {
    let player = AVPlayer()
    var current: Double = 0
    var duration: Double = 0
    var isPlaying = false
    var rate: Float = 1
    var muted = true
    var scrubbing = false

    @ObservationIgnored private var wasPlaying = false
    @ObservationIgnored private var timeObserver: Any? = nil
    @ObservationIgnored private var endObserver: NSObjectProtocol? = nil
    @ObservationIgnored private var seeking = false
    @ObservationIgnored private var nextSeek: Double? = nil

    var progress: Double { duration > 0 ? current / duration : 0 }

    func load(_ url: URL) {
        guard player.currentItem == nil else { return }
        let item = AVPlayerItem(url: url)
        item.audioTimePitchAlgorithm = .timeDomain
        player.replaceCurrentItem(with: item)
        player.isMuted = muted
        player.actionAtItemEnd = .none
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] t in
            guard let self, !self.scrubbing else { return }
            self.current = t.seconds
            if let d = self.player.currentItem?.duration.seconds, d.isFinite, d > 0 { self.duration = d }
        }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.player.seek(to: .zero) { _ in
                DispatchQueue.main.async { if self.isPlaying { self.player.rate = self.rate } }
            }
        }
    }

    func play() { player.rate = rate; isPlaying = true }
    func pause() { player.pause(); isPlaying = false }
    func toggle() { isPlaying ? pause() : play() }
    func stop() {
        pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil; endObserver = nil
    }

    func setRate(_ r: Float) {
        rate = r
        if isPlaying { player.rate = r }
    }

    func toggleMute() {
        muted.toggle()
        player.isMuted = muted
        if muted { PlayerAudio.quiet() } else { PlayerAudio.loud() }
    }

    func beginScrub() {
        scrubbing = true
        wasPlaying = isPlaying
        player.pause()
    }

    func scrub(to fraction: Double) {
        guard duration > 0 else { return }
        current = fraction * duration
        chase(current)
    }

    func endScrub() {
        scrubbing = false
        if wasPlaying { play() } else { isPlaying = false }
    }

    private func chase(_ t: Double) {
        if seeking { nextSeek = t; return }
        seeking = true
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.seeking = false
                if let n = self.nextSeek { self.nextSeek = nil; self.chase(n) }
            }
        }
    }
}

/// Muted clips must not stop the music you have playing. Sound on ducks it instead.
enum PlayerAudio {
    static func quiet() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }
    static func loud() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    static func release() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }
}

private final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> PlayerUIView {
        let v = PlayerUIView()
        v.backgroundColor = .black
        v.playerLayer.videoGravity = .resizeAspect
        v.playerLayer.player = player
        return v
    }
    func updateUIView(_ v: PlayerUIView, context: Context) {
        if v.playerLayer.player !== player { v.playerLayer.player = player }
    }
}

// MARK: - Photo

private struct PhotoPage: View {
    let clip: Clip
    let onSwipe: (CGSize, Bool) -> Void
    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            Color.clear.contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 24)
                    .onChanged { onSwipe($0.translation, false) }
                    .onEnded { onSwipe($0.translation, true) })
        }
        .ignoresSafeArea()
        .task(id: clip.id) {
            let u = ClipFiles.url(clip)
            image = await Task.detached { UIImage(contentsOfFile: u.path) }.value
        }
    }
}
