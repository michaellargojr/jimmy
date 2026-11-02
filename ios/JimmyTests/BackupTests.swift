import Foundation
import Testing
@testable import Jimmy

// Backups to a folder picked in iCloud Drive, and restoring from them.

@Suite struct BackupTests {
    private func tempDir() -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("backup-\(uid())", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private func storeURL() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("backup-store-\(uid()).json") }

    private func seededStore(_ backups: Backups? = nil) -> AppStore {
        let s = AppStore(fileURL: storeURL(), backups: backups)
        s.resetToSeed()
        return s
    }

    /// "2026-10-31 20.14" as a date, the way backup names carry it.
    private func at(_ stamp: String) -> Date { Backups.date(fromFileName: "Jimmy \(stamp).json")! }

    private func path(_ u: URL?) -> String? { u?.resolvingSymlinksInPath().standardizedFileURL.path }

    @Test func namesCarryTheDateAndTime() {
        #expect(Backups.fileName(for: at("2026-10-31 20.14")) == "Jimmy 2026-10-31 20.14.json")
        #expect(Backups.date(fromFileName: "Jimmy export.json") == nil)
        #expect(Backups.date(fromFileName: "notes.txt") == nil)
    }

    @Test func writeListAndReadBack() throws {
        let dir = tempDir()
        let store = seededStore()
        let data = try store.snapshot().encoded()
        try Backups.write(data, clips: [], to: dir, at: at("2026-10-30 19.02"), clipSource: { _ in nil })
        try Backups.write(data, clips: [], to: dir, at: at("2026-10-31 20.14"), clipSource: { _ in nil })
        let files = Backups.list(dir)
        #expect(files.map(\.id) == ["Jimmy 2026-10-31 20.14.json", "Jimmy 2026-10-30 19.02.json"])
        #expect(files.allSatisfy { $0.downloaded })
        let back = try Backups.read(files[0].url)
        #expect(back.workouts.count == store.workouts.count)
        #expect(back.versions.count == store.versions.count)
        #expect(Backups.finishedCount(files[0].url) == store.finishedWorkouts.count)
    }

    @Test func keepsTheNewestAndLeavesOtherFilesAlone() throws {
        let dir = tempDir()
        try Data("mine".utf8).write(to: dir.appendingPathComponent("notes.txt"))
        for day in 1...5 {
            try Backups.write(Data("{}".utf8), clips: [], to: dir, at: at("2026-10-0\(day) 08.00"), keep: 3, clipSource: { _ in nil })
        }
        #expect(Backups.list(dir).map(\.id) == ["Jimmy 2026-10-05 08.00.json", "Jimmy 2026-10-04 08.00.json", "Jimmy 2026-10-03 08.00.json"])
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("notes.txt").path))
    }

    @Test func iCloudPlaceholdersListUnderTheirRealNames() throws {
        let dir = tempDir()
        try Data().write(to: dir.appendingPathComponent(".Jimmy 2026-10-29 07.30.json.icloud"))
        let files = Backups.list(dir)
        #expect(files.map(\.id) == ["Jimmy 2026-10-29 07.30.json"])
        #expect(files.first?.downloaded == false)
    }

    @Test func clipsAreCopiedOnceAndComeBack() throws {
        let dir = tempDir(), src = tempDir(), dest = tempDir()
        let clip = Clip(id: "abc123", kind: .video, ext: "mp4", bytes: 4, addedAt: 1)
        let file = src.appendingPathComponent(clip.fileName)
        try Data("clip".utf8).write(to: file)
        try Backups.write(Data("{}".utf8), clips: [clip], to: dir, at: at("2026-10-31 20.14"), clipSource: { _ in file })
        let copied = dir.appendingPathComponent(Backups.clipsFolder).appendingPathComponent(clip.fileName)
        #expect(try Data(contentsOf: copied) == Data("clip".utf8))
        // The next backup leaves the copy alone: same name, same clip.
        try Data("changed".utf8).write(to: file)
        try Backups.write(Data("{}".utf8), clips: [clip], to: dir, at: at("2026-10-31 20.15"), clipSource: { _ in file })
        #expect(try Data(contentsOf: copied) == Data("clip".utf8))
        // The Clips folder is not a backup.
        #expect(Backups.list(dir).count == 2)
        Backups.restoreClips([clip], from: dir) { dest.appendingPathComponent($0.fileName) }
        #expect(try Data(contentsOf: dest.appendingPathComponent(clip.fileName)) == Data("clip".utf8))
    }

    @Test func readRejectsFilesThatAreNotJimmy() throws {
        let url = tempDir().appendingPathComponent("Jimmy 2026-10-31 20.14.json")
        try Data("{\"workouts\": []}".utf8).write(to: url)
        #expect(throws: BackupError.self) { try Backups.read(url) }
    }

    @Test func folderIsRememberedAndLabelled() throws {
        let dir = tempDir()
        let b = Backups(defaults: nil)
        #expect(!b.hasFolder)
        try b.setFolder(dir)
        #expect(b.hasFolder)
        #expect(path(b.folderURL()) == path(dir))
        #expect(Backups.label(for: URL(fileURLWithPath: "/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Jimmy")) == "iCloud Drive - Jimmy")
        #expect(Backups.label(for: dir) == dir.lastPathComponent)
    }

    @Test func backUpWritesIntoTheChosenFolder() async throws {
        let dir = tempDir()
        let b = Backups(defaults: nil)
        try b.setFolder(dir)
        let store = seededStore(b)
        let ok = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in store.backUp { c.resume(returning: $0) } }
        #expect(ok)
        #expect(Backups.list(dir).count == 1)
        #expect(b.lastBackupAt != nil)
        #expect(!b.failed)
    }

    @Test func refreshListsBackupsAlreadyInAChosenFolder() async throws {
        let dir = tempDir()
        try Backups.write(Data("{}".utf8), clips: [], to: dir, at: at("2026-11-01 05.50"), clipSource: { _ in nil })
        let b = Backups(defaults: nil)
        try b.setFolder(dir)
        let found = await withCheckedContinuation { (c: CheckedContinuation<[BackupFile], Never>) in b.refresh { c.resume(returning: $0) } }
        #expect(found.map(\.id) == ["Jimmy 2026-11-01 05.50.json"])
        #expect(b.files.count == 1)
    }

    @Test func noFolderMeansNoBackup() async {
        let store = seededStore()
        #expect(!store.backups.hasFolder)
        let ok = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in store.backUp { c.resume(returning: $0) } }
        #expect(!ok)
        #expect(!store.backups.failed)
    }

    @Test func restoreReplacesEverythingAndKeepsACopy() throws {
        let store = seededStore()
        let before = store.workouts.count
        var s = store.snapshot()
        s.workouts = Array(s.workouts.prefix(1))
        store.restore(s)
        #expect(store.workouts.count == 1)
        let kept = try Snapshot.decode(Data(contentsOf: Backups.beforeRestoreURL))
        #expect(kept.workouts.count == before)
    }

    @Test func dayLabels() {
        let now = at("2026-10-31 20.14")
        #expect(backupDay(at("2026-10-31 08.00"), now: now) == "Today")
        #expect(backupDay(at("2026-10-30 19.02"), now: now) == "Yesterday")
        #expect(backupDay(at("2026-10-28 18.40"), now: now) == "Wed, Oct 28")
        #expect(backupDay(at("2025-12-24 09.15"), now: now) == "Dec 24, 2025")
    }
}
