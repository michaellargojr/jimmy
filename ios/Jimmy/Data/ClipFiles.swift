import Foundation
import AVFoundation
import CryptoKit
import UIKit

/// Where Form cues clips live and how they get there.
///
/// Files: Documents/Media/<id>.<ext>. Documents is included in iCloud Backup and in
/// Finder/iTunes backups, so clips come back with the phone. Thumbnails are a cache
/// (Library/Caches/ClipThumbs) and are rebuilt when missing.
///
/// Videos are re-encoded on the way in so the short side is at most 720 pixels and the
/// bit rate is never higher than the source's. Photos are stored as picked.
enum ClipFiles {
    static var mediaDir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static var thumbDir: URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ClipThumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func url(_ c: Clip) -> URL { mediaDir.appendingPathComponent(c.fileName) }
    static func thumbURL(_ c: Clip) -> URL { thumbDir.appendingPathComponent("\(c.id).jpg") }
    static func exists(_ c: Clip) -> Bool { FileManager.default.fileExists(atPath: url(c).path) }
    static func remove(_ c: Clip) {
        try? FileManager.default.removeItem(at: url(c))
        try? FileManager.default.removeItem(at: thumbURL(c))
    }
    /// Total bytes of every stored clip.
    static func totalBytes(_ clips: [Clip]) -> Int { clips.reduce(0) { $0 + $1.bytes } }

    enum ImportError: LocalizedError {
        case unreadable, encodeFailed(String)
        var errorDescription: String? {
            switch self {
            case .unreadable: return "That file could not be read."
            case .encodeFailed(let why): return "That video could not be saved. \(why)"
            }
        }
    }

    /// Fingerprint of a file's bytes, used as the clip id.
    static func fingerprint(_ file: URL) throws -> String {
        guard let h = try? FileHandle(forReadingFrom: file) else { throw ImportError.unreadable }
        defer { try? h.close() }
        var hasher = SHA256()
        while let chunk = try h.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    /// Store a picked file. `existing` is the current library, so a repeat import is a no-op.
    /// The source file is only read; the caller may delete it afterwards.
    static func importFile(_ source: URL, kind: ClipKind, existing: [Clip]) async throws -> Clip {
        let id = try fingerprint(source)
        if let c = existing.first(where: { $0.id == id }), exists(c) { return c }
        switch kind {
        case .photo: return try importPhoto(source, id: id)
        case .video: return try await importVideo(source, id: id)
        }
    }

    private static func importPhoto(_ source: URL, id: String) throws -> Clip {
        let ext = source.pathExtension.isEmpty ? "jpg" : source.pathExtension.lowercased()
        var c = Clip(id: id, kind: .photo, ext: ext, bytes: 0, addedAt: Date().timeIntervalSince1970 * 1000)
        let dest = url(c)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: source, to: dest)
        c.bytes = (try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if let img = UIImage(contentsOfFile: dest.path) {
            c.width = Int(img.size.width * img.scale); c.height = Int(img.size.height * img.scale)
        }
        return c
    }

    private static func importVideo(_ source: URL, id: String) async throws -> Clip {
        var c = Clip(id: id, kind: .video, ext: "mp4", bytes: 0, addedAt: Date().timeIntervalSince1970 * 1000)
        let dest = url(c)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("enc-\(id).mp4")
        try? FileManager.default.removeItem(at: tmp)
        try await VideoShrinker.encode(source: source, to: tmp, maxShortSide: 720)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
        c.bytes = (try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let asset = AVURLAsset(url: dest)
        if let d = try? await asset.load(.duration) { c.duration = d.seconds.isFinite ? d.seconds : nil }
        if let track = try? await asset.loadTracks(withMediaType: .video).first,
           let size = try? await track.load(.naturalSize), let t = try? await track.load(.preferredTransform) {
            let r = CGRect(origin: .zero, size: size).applying(t)
            c.width = Int(abs(r.width)); c.height = Int(abs(r.height))
        }
        return c
    }

    // MARK: Thumbnails

    /// A thumbnail, from the cache or made now. About 480 px on the long side.
    static func thumbnail(_ c: Clip) async -> UIImage? {
        let t = thumbURL(c)
        if let img = UIImage(contentsOfFile: t.path) { return img }
        var img: UIImage?
        switch c.kind {
        case .photo:
            if let full = UIImage(contentsOfFile: url(c).path) { img = full.preparingThumbnail(of: fitting(full.size, long: 480)) ?? full }
        case .video:
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url(c)))
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 480, height: 480)
            let at = CMTime(seconds: min(1, (c.duration ?? 2) / 3), preferredTimescale: 600)
            if let r = try? await gen.image(at: at) { img = UIImage(cgImage: r.image) }
        }
        if let img, let data = img.jpegData(compressionQuality: 0.8) { try? data.write(to: t, options: .atomic) }
        return img
    }

    private static func fitting(_ size: CGSize, long: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: long, height: long) }
        let s = min(1, long / max(size.width, size.height))
        return CGSize(width: size.width * s, height: size.height * s)
    }
}

/// Re-encode a video to H.265 (H.264 if the phone cannot) with the short side at most
/// `maxShortSide`, keeping orientation, with AAC audio.
enum VideoShrinker {
    static func encode(source: URL, to dest: URL, maxShortSide: CGFloat) async throws {
        let asset = AVURLAsset(url: source)
        guard let vTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ClipFiles.ImportError.encodeFailed("It has no picture.")
        }
        let aTrack = try await asset.loadTracks(withMediaType: .audio).first
        let natural = try await vTrack.load(.naturalSize)
        let transform = try await vTrack.load(.preferredTransform)
        let sourceRate = try await vTrack.load(.estimatedDataRate)
        let fps = try await vTrack.load(.nominalFrameRate)

        // Scale in the track's own (unrotated) frame; the transform rotates it on playback.
        let short = min(natural.width, natural.height)
        let scale = short > maxShortSide ? maxShortSide / short : 1
        let w = Int((natural.width * scale / 2).rounded()) * 2
        let h = Int((natural.height * scale / 2).rounded()) * 2

        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: dest, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true

        let vOut = AVAssetReaderTrackOutput(track: vTrack, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        ])
        vOut.alwaysCopiesSampleData = false
        guard reader.canAdd(vOut) else { throw ClipFiles.ImportError.encodeFailed("Unsupported video.") }
        reader.add(vOut)

        // ~1.6 Mbit/s HEVC is plenty for 720p form clips; never more than the source.
        let hevcRate = min(1_600_000, sourceRate > 0 ? Double(sourceRate) : 1_600_000)
        var vSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: w, AVVideoHeightKey: h,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: hevcRate,
                                              AVVideoExpectedSourceFrameRateKey: fps > 0 ? fps : 30],
        ]
        if !writer.canApply(outputSettings: vSettings, forMediaType: .video) {
            vSettings[AVVideoCodecKey] = AVVideoCodecType.h264
            vSettings[AVVideoCompressionPropertiesKey] = [AVVideoAverageBitRateKey: min(2_400_000, sourceRate > 0 ? Double(sourceRate) : 2_400_000),
                                                          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel]
        }
        let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings)
        vIn.transform = transform
        vIn.expectsMediaDataInRealTime = false
        guard writer.canAdd(vIn) else { throw ClipFiles.ImportError.encodeFailed("Could not write video.") }
        writer.add(vIn)

        var pairs: [(AVAssetReaderOutput, AVAssetWriterInput)] = [(vOut, vIn)]
        if let aTrack {
            let aOut = AVAssetReaderTrackOutput(track: aTrack, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
            let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 2, AVSampleRateKey: 44_100, AVEncoderBitRateKey: 96_000,
            ])
            aIn.expectsMediaDataInRealTime = false
            if reader.canAdd(aOut), writer.canAdd(aIn) {
                reader.add(aOut); writer.add(aIn); pairs.append((aOut, aIn))
            }
        }

        guard reader.startReading() else { throw ClipFiles.ImportError.encodeFailed(reader.error?.localizedDescription ?? "") }
        guard writer.startWriting() else { throw ClipFiles.ImportError.encodeFailed(writer.error?.localizedDescription ?? "") }
        writer.startSession(atSourceTime: .zero)

        await withTaskGroup(of: Void.self) { group in
            for (i, pair) in pairs.enumerated() {
                group.addTask {
                    await pump(output: pair.0, input: pair.1, label: "jimmy.encode.\(i)")
                }
            }
        }

        if reader.status == .failed {
            writer.cancelWriting()
            throw ClipFiles.ImportError.encodeFailed(reader.error?.localizedDescription ?? "")
        }
        await writer.finishWriting()
        if writer.status != .completed {
            throw ClipFiles.ImportError.encodeFailed(writer.error?.localizedDescription ?? "")
        }
    }

    /// Copy samples from a reader output into a writer input until the output runs dry.
    private static func pump(output: AVAssetReaderOutput, input: AVAssetWriterInput, label: String) async {
        let queue = DispatchQueue(label: label)
        let state = PumpState()
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData && !state.finished {
                    if let buf = output.copyNextSampleBuffer() {
                        if !input.append(buf) { state.finished = true }
                    } else {
                        state.finished = true
                    }
                }
                if state.finished && !state.resumed {
                    state.resumed = true
                    input.markAsFinished()
                    done.resume()
                }
            }
        }
    }
}

/// Flags for one pump, touched only on its own serial queue.
private final class PumpState: @unchecked Sendable {
    var finished = false
    var resumed = false
}

/// "tiktok.com/@creator/video/123" -> https URL string, or nil if it is not a link.
func normalizedLink(_ raw: String) -> String? {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty, !t.contains(" ") else { return nil }
    let withScheme = t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://") ? t : "https://" + t
    guard let u = URL(string: withScheme), let host = u.host, host.contains(".") else { return nil }
    return withScheme
}

/// "tiktok.com · @creator" for a saved link.
func linkLabel(_ url: String) -> String {
    guard let u = URL(string: url), let host = u.host else { return url }
    let h = host.replacingOccurrences(of: "www.", with: "").replacingOccurrences(of: "m.", with: "", options: .anchored)
    let handle = u.pathComponents.first { $0.hasPrefix("@") }
    return handle.map { "\(h) · \($0)" } ?? h
}

/// "0:34"
func clipDuration(_ s: Double?) -> String? {
    guard let s, s.isFinite else { return nil }
    let t = Int(s.rounded())
    return "\(t / 60):" + String(format: "%02d", t % 60)
}

/// "120 MB"
func byteLabel(_ b: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .file)
}
