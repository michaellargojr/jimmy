import Foundation
import Testing
@testable import Jimmy

// Form cues: one shared clip library, clips attached to variations, links kept apart.

@Suite struct FormCuesTests {
    private func freshStore() -> AppStore {
        let s = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("formcues-\(uid()).json"))
        s.resetToSeed()
        return s
    }

    private func clip(_ id: String = uid()) -> Clip {
        Clip(id: id, kind: .video, ext: "mp4", bytes: 1_000, duration: 34, addedAt: Date().timeIntervalSince1970 * 1000)
    }

    @Test func oneClipSharedByManyVariations() throws {
        let store = freshStore()
        let a = try #require(store.versions.first)
        let b = try #require(store.versions.dropFirst().first)
        let c = clip()
        store.attach(c, to: a.id)
        store.attach(c, to: b.id)
        store.attach(c, to: a.id)                       // again: no duplicate
        #expect(store.clips.filter { $0.id == c.id }.count == 1)
        #expect(store.version(a.id)?.clipIds == [c.id])
        #expect(store.usage(of: c.id).count == 2)
        #expect(store.formCueCount(b.id) == 1)
    }

    @Test func deleteOnlyWhenUnused() throws {
        let store = freshStore()
        let a = try #require(store.versions.first)
        let c = clip()
        store.attach(c, to: a.id)
        store.deleteClip(c.id)
        #expect(store.clip(c.id) != nil)                // still on a variation
        store.detach(c.id, from: a.id)
        #expect(store.clip(c.id) != nil)                // detaching keeps it in the library
        store.deleteClip(c.id)
        #expect(store.clip(c.id) == nil)
    }

    @Test func linksStaySeparate() throws {
        let store = freshStore()
        let a = try #require(store.versions.first)
        store.addLink("tiktok.com/@creator/video/123", to: a.id)
        store.addLink("https://tiktok.com/@creator/video/123", to: a.id)   // same link
        store.addLink("not a link", to: a.id)
        let v = try #require(store.version(a.id))
        #expect(v.media.count == 1)
        #expect(v.media[0].type == "tiktok")
        #expect(v.clipIds.isEmpty)
        #expect(linkLabel(v.media[0].url) == "tiktok.com · @creator")
        store.removeLink(v.media[0].url, from: a.id)
        #expect(store.version(a.id)?.media.isEmpty == true)
    }

    @Test func exportRoundTripRelinksStoredFiles() throws {
        let store = freshStore()
        let a = try #require(store.versions.first)
        let here = clip("test" + uid())
        let gone = clip("test" + uid())
        try Data("x".utf8).write(to: ClipFiles.url(here))
        defer { ClipFiles.remove(here) }
        store.attach(here, to: a.id)
        store.attach(gone, to: a.id)
        let data = try store.snapshot().encoded()

        let other = AppStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("formcues-\(uid()).json"))
        other.importSnapshot(try Snapshot.decode(data))
        #expect(other.clip(here.id) != nil)
        #expect(other.clip(gone.id) == nil)             // its file is not on this phone
        #expect(other.version(a.id)?.clipIds == [here.id])
    }

    @Test func oldExportsDecodeWithoutClips() throws {
        let json = """
        {"version":2,"exportedAt":"","exercises":[],"versions":[{"id":"v1","exerciseId":"e1","name":"x","equipment":"cable","arms":"one","repMin":5,"repMax":8,"defaultWarmup":true,"defaultSets":2,"media":[{"type":"tiktok","url":"https://tiktok.com/@a"}]}],
         "workouts":[],"routines":[],"gyms":[],"ideas":[],"splits":[]}
        """
        let s = try Snapshot.decode(Data(json.utf8))
        #expect(s.clips.isEmpty)
        #expect(s.versions[0].clipIds.isEmpty)
        #expect(s.versions[0].media.count == 1)
    }

    @Test func fingerprintIsStable() throws {
        let f = FileManager.default.temporaryDirectory.appendingPathComponent("fp-\(uid()).bin")
        try Data(repeating: 7, count: 3_000_000).write(to: f)
        defer { try? FileManager.default.removeItem(at: f) }
        let a = try ClipFiles.fingerprint(f)
        let b = try ClipFiles.fingerprint(f)
        #expect(a == b)
        #expect(a.count == 24)
    }

    @Test func addToLibraryOnly() throws {
        // Settings > Jimmy library > Add stores a clip without putting it on any exercise.
        let store = freshStore()
        let c = clip()
        store.attach(c, to: nil)
        store.attach(c, to: nil)                        // the same file again: still one
        #expect(store.clips.filter { $0.id == c.id }.count == 1)
        #expect(store.usage(of: c.id).isEmpty)
        let a = try #require(store.versions.first)
        store.attach(clipIds: [c.id], to: a.id)         // later, from Form cues > From my Jimmy library
        #expect(store.version(a.id)?.clipIds == [c.id])
    }

    @Test func libraryCountLine() {
        #expect(clipCountLine([]).hasPrefix("0 clips - "))
        #expect(clipCountLine([clip()]).hasPrefix("1 clip - "))
        #expect(clipCountLine([clip(), clip()]).hasPrefix("2 clips - "))
        #expect(!clipCountLine([clip()]).contains("·"))
    }

    @Test func durationsReadPlainly() {
        #expect(clipDuration(34) == "0:34")
        #expect(clipDuration(62.4) == "1:02")
        #expect(clipDuration(nil) == nil)
    }
}

import AVFoundation
import CoreVideo

/// The import path end to end: a 1080 x 1920 portrait video goes in, a 720-wide copy is
/// stored, a thumbnail is made, and a second import of the same file reuses the copy.
@Suite struct ClipImportTests {
    @Test func portraitVideoShrinksTo720() async throws {
        let src = FileManager.default.temporaryDirectory.appendingPathComponent("src-\(uid()).mp4")
        try await makeVideo(at: src, width: 1080, height: 1920, seconds: 2)
        defer { try? FileManager.default.removeItem(at: src) }

        let c = try await ClipFiles.importFile(src, kind: .video, existing: [])
        defer { ClipFiles.remove(c) }
        #expect(ClipFiles.exists(c))
        #expect(c.kind == .video && c.ext == "mp4")
        #expect(c.width == 720 && c.height == 1280)
        #expect(abs((c.duration ?? 0) - 2) < 0.3)
        #expect(c.bytes > 0)

        let again = try await ClipFiles.importFile(src, kind: .video, existing: [c])
        #expect(again == c)

        let thumb = await ClipFiles.thumbnail(c)
        #expect(thumb != nil)
    }

    /// Writes a plain grey H.264 video, 30 frames a second.
    private func makeVideo(at url: URL, width: Int, height: Int, seconds: Int) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        for f in 0..<(seconds * 30) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
            var pb: CVPixelBuffer?
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &pb)
            guard let pb else { continue }
            CVPixelBufferLockBaseAddress(pb, [])
            memset(CVPixelBufferGetBaseAddress(pb), Int32(40 + f % 100), CVPixelBufferGetDataSize(pb))
            CVPixelBufferUnlockBaseAddress(pb, [])
            adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        #expect(writer.status == .completed)
    }
}
