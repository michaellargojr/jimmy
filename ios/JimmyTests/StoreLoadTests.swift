import Foundation
import Testing
@testable import Jimmy

// Loading jimmy.json never destroys a file it can't read.

@Suite struct StoreLoadTests {
    private func tempDir() -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("load-\(uid())", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private func unreadableCopies(in dir: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasPrefix("jimmy-unreadable-") }
    }

    private let junk = Data("not a Jimmy file".utf8)

    @Test func noFileStartsFromTheSeed() {
        let dir = tempDir()
        let store = AppStore(fileURL: dir.appendingPathComponent("jimmy.json"))
        store.load()
        #expect(store.loaded)
        #expect(!store.versions.isEmpty)
        #expect(!store.savesPaused)
        #expect(unreadableCopies(in: dir).isEmpty)
    }

    @Test func aGoodFileLoadsAsItIs() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("jimmy.json")
        let first = AppStore(fileURL: url)
        first.resetToSeed()
        first.saveNow()
        let store = AppStore(fileURL: url)
        store.load()
        #expect(store.workouts.count == first.workouts.count)
        #expect(unreadableCopies(in: dir).isEmpty)
    }

    @Test func aFileThatCantBeReadIsKeptAside() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("jimmy.json")
        try junk.write(to: url)
        let store = AppStore(fileURL: url)
        store.load()
        let kept = unreadableCopies(in: dir)
        #expect(kept.count == 1)
        #expect(!store.savesPaused)
        store.saveNow()
        // The new save replaces jimmy.json, and the copy keeps what was there.
        #expect(try Data(contentsOf: dir.appendingPathComponent(kept[0])) == junk)
    }

    @Test func savingPausesWhenTheFileCantBeCopiedAside() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("jimmy.json")
        try junk.write(to: url)
        // A folder that can't be written to: no copy can be made beside the file.
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path) }
        let store = AppStore(fileURL: url)
        store.load()
        #expect(store.savesPaused)
        store.saveNow()
        #expect(try Data(contentsOf: url) == junk)
        // A restore replaces the data on purpose, so saving starts again.
        store.importSnapshot(store.snapshot())
        #expect(!store.savesPaused)
    }

    @Test func theCopyIsNamedByDateAndTime() throws {
        let dir = tempDir()
        let url = dir.appendingPathComponent("jimmy.json")
        try junk.write(to: url)
        let date = Backups.date(fromFileName: "Jimmy 2026-11-02 01.42.json")!
        #expect(AppStore.keepAside(url, at: date))
        #expect(unreadableCopies(in: dir) == ["jimmy-unreadable-2026-11-02 01.42.00.json"])
    }
}
