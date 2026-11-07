import Foundation
import Observation

/// One backup file in the chosen folder.
struct BackupFile: Identifiable, Hashable {
    /// The file's real URL, even while iCloud has only a placeholder for it.
    var url: URL
    var date: Date
    /// False while the file is still only in iCloud.
    var downloaded: Bool
    var id: String { url.lastPathComponent }
}

enum BackupError: LocalizedError {
    case noFolder, notJimmy
    var errorDescription: String? {
        switch self {
        case .noFolder: return "The backup folder can't be found. Choose it again."
        case .notJimmy: return "That file has no exercises in it. Is it a Jimmy backup?"
        }
    }
}

/// Backups to a folder picked in Files, usually iCloud Drive > Jimmy.
///
/// No iCloud entitlement is needed. The document picker hands the app a security-scoped URL
/// for the folder, kept as a bookmark so later launches can write there (Apple, "Providing
/// access to directories"). The bookmark belongs to this phone, so it lives in UserDefaults and
/// never in Settings, which travels inside every backup.
///
/// Files are named "Jimmy 2026-10-31 20.14.json" and hold the same JSON as jimmy.json. The newest
/// 30 are kept. Form cue clips are copied once into a Clips folder beside them; their names are
/// content hashes, so a file that is already there is already the right one.
@Observable
final class Backups {
    static let keep = 30
    static let clipsFolder = "Clips"

    private(set) var folderLabel: String?
    private(set) var lastBackupAt: Date?
    private(set) var failed = false
    private(set) var files: [BackupFile] = []
    /// Finished workouts in each backup, by file name, filled in as files are read.
    private(set) var counts: [String: Int] = [:]
    private(set) var hasFolder = false

    private let defaults: UserDefaults?
    @ObservationIgnored private var memory: [String: Any] = [:]
    private let io = DispatchQueue(label: "jimmy.backup", qos: .utility)

    private enum Key {
        static let bookmark = "backup.folderBookmark"
        static let last = "backup.lastAt"
        static let failed = "backup.failed"
    }

    /// `defaults` nil keeps everything in memory, for tests and stores that aren't the app's.
    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        lastBackupAt = value(Key.last) as? Date
        failed = value(Key.failed) as? Bool ?? false
        hasFolder = value(Key.bookmark) != nil
        if let url = folderURL() { folderLabel = Self.label(for: url) }
    }

    private func value(_ key: String) -> Any? { defaults?.object(forKey: key) ?? memory[key] }
    private func store(_ v: Any?, _ key: String) {
        if let defaults { defaults.set(v, forKey: key) } else { memory[key] = v }
    }

    // MARK: Folder

    /// Keep the folder the picker returned.
    func setFolder(_ url: URL) throws {
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        store(data, Key.bookmark)
        hasFolder = true
        folderLabel = Self.label(for: url)
        files = []; counts = [:]
        setFailed(false)
    }

    /// The saved folder, or nil when none is set or it can't be found.
    func folderURL() -> URL? {
        guard let data = value(Key.bookmark) as? Data else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else { return nil }
        if stale {
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }
            if let fresh = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
                store(fresh, Key.bookmark)
            }
        }
        return url
    }

    /// "iCloud Drive - Jimmy", or just the folder's name elsewhere.
    static func label(for url: URL) -> String {
        let name = url.lastPathComponent
        if name == "com~apple~CloudDocs" { return "iCloud Drive" }
        return url.path.contains("/Mobile Documents/") ? "iCloud Drive - \(name)" : name
    }

    private func setFailed(_ f: Bool) {
        failed = f
        store(f, Key.failed)
    }

    // MARK: Back up

    /// Write `data` (the store's JSON) as a new backup, off the main thread. `done` runs on main.
    func backUp(_ data: Data, clips: [Clip], at date: Date = Date(),
                clipSource: @escaping (Clip) -> URL? = { ClipFiles.exists($0) ? ClipFiles.url($0) : nil },
                done: ((Bool) -> Void)? = nil) {
        guard let folder = folderURL() else {
            if hasFolder { setFailed(true) }
            done?(false); return
        }
        io.async {
            let ok = (try? Self.write(data, clips: clips, to: folder, at: date, clipSource: clipSource)) != nil
            let list = ok ? Self.list(folder) : nil
            DispatchQueue.main.async {
                if ok {
                    self.lastBackupAt = date
                    self.store(date, Key.last)
                }
                if let list { self.files = list }
                self.setFailed(!ok)
                done?(ok)
                if ok { self.countMissing() }
            }
        }
    }

    /// Write one backup into `folder`, copy new clips, and drop the oldest backups past `keep`.
    static func write(_ data: Data, clips: [Clip], to folder: URL, at date: Date, keep: Int = Backups.keep,
                      clipSource: (Clip) -> URL?) throws {
        let ok = folder.startAccessingSecurityScopedResource()
        defer { if ok { folder.stopAccessingSecurityScopedResource() } }
        try coordinatedWrite(folder.appendingPathComponent(fileName(for: date))) { url in
            try data.write(to: url, options: .atomic)
        }
        let sources = clips.compactMap { c in clipSource(c).map { (c, $0) } }
        if !sources.isEmpty {
            let dir = folder.appendingPathComponent(clipsFolder, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let have = Set(names(in: dir).map { $0.name })
            for (c, src) in sources where !have.contains(c.fileName) {
                try? coordinatedWrite(dir.appendingPathComponent(c.fileName)) { url in
                    try FileManager.default.copyItem(at: src, to: url)
                }
            }
        }
        prune(folder, keep: keep)
    }

    /// Delete our own backups past the newest `keep`. Other files in the folder are never touched.
    static func prune(_ folder: URL, keep: Int) {
        for f in list(folder).dropFirst(keep) {
            var err: NSError?
            NSFileCoordinator().coordinate(writingItemAt: f.url, options: .forDeleting, error: &err) { url in
                _ = try? FileManager.default.removeItem(at: url)
            }
            let placeholder = f.url.deletingLastPathComponent().appendingPathComponent("." + f.url.lastPathComponent + ".icloud")
            try? FileManager.default.removeItem(at: placeholder)
        }
    }

    // MARK: List

    /// Re-read the folder. Cheap; runs off the main thread. `done` runs on main with the list.
    func refresh(done: (([BackupFile]) -> Void)? = nil) {
        guard let folder = folderURL() else { files = []; done?([]); return }
        io.async {
            let list = Self.list(folder)
            DispatchQueue.main.async {
                self.files = list
                self.countMissing()
                done?(list)
            }
        }
    }

    /// Count finished workouts in the backups that are on this phone and not counted yet.
    private func countMissing() {
        guard let folder = folderURL() else { return }
        let todo = files.filter { $0.downloaded && counts[$0.id] == nil }
        guard !todo.isEmpty else { return }
        io.async {
            let ok = folder.startAccessingSecurityScopedResource()
            defer { if ok { folder.stopAccessingSecurityScopedResource() } }
            var found: [String: Int] = [:]
            for f in todo { if let n = Self.finishedCount(f.url) { found[f.id] = n } }
            DispatchQueue.main.async { self.counts.merge(found) { _, new in new } }
        }
    }

    /// Our backups in `folder`, newest first.
    static func list(_ folder: URL) -> [BackupFile] {
        let ok = folder.startAccessingSecurityScopedResource()
        defer { if ok { folder.stopAccessingSecurityScopedResource() } }
        return names(in: folder).compactMap { n in
            date(fromFileName: n.name).map { BackupFile(url: folder.appendingPathComponent(n.name), date: $0, downloaded: !n.placeholder) }
        }
        .sorted { $0.date > $1.date }
    }

    /// File names in `dir`. iCloud can show a file it hasn't downloaded as ".name.icloud";
    /// those come back as "name" with `placeholder` set.
    static func names(in dir: URL) -> [(name: String, placeholder: Bool)] {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return items.compactMap { (raw: String) -> (name: String, placeholder: Bool)? in
            if raw.hasPrefix("."), raw.hasSuffix(".icloud") {
                return (String(raw.dropFirst().dropLast(".icloud".count)), true)
            }
            if raw.hasPrefix(".") { return nil }
            return (raw, false)
        }
    }

    // MARK: Names

    private static let stampFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH.mm"
        return f
    }()

    static func fileName(for date: Date) -> String { "Jimmy \(stampFormat.string(from: date)).json" }

    static func date(fromFileName name: String) -> Date? {
        guard name.hasPrefix("Jimmy "), name.hasSuffix(".json") else { return nil }
        let stamp = name.dropFirst("Jimmy ".count).dropLast(".json".count)
        return stampFormat.date(from: String(stamp))
    }

    // MARK: Restore

    /// Read a backup and bring back any clip files this phone is missing, off the main thread.
    /// `folder` is nil for a file picked on its own, which brings no clips.
    func read(_ url: URL, folder: URL?) async throws -> Snapshot {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Snapshot, Error>) in
            io.async {
                let scope = folder ?? url
                let ok = scope.startAccessingSecurityScopedResource()
                defer { if ok { scope.stopAccessingSecurityScopedResource() } }
                do {
                    let s = try Self.read(url)
                    if let folder { Self.restoreClips(s.clips, from: folder) { ClipFiles.url($0) } }
                    cont.resume(returning: s)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// The snapshot in a backup file. Throws when it isn't a Jimmy backup.
    static func read(_ url: URL) throws -> Snapshot {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        let s = try Snapshot.decode(coordinatedRead(url))
        guard !s.versions.isEmpty else { throw BackupError.notJimmy }
        return s
    }

    /// Copy clip files from the backup folder's Clips folder to where this phone keeps them.
    static func restoreClips(_ clips: [Clip], from folder: URL, to dest: (Clip) -> URL) {
        let dir = folder.appendingPathComponent(clipsFolder, isDirectory: true)
        for c in clips {
            let target = dest(c)
            guard !FileManager.default.fileExists(atPath: target.path) else { continue }
            let src = dir.appendingPathComponent(c.fileName)
            try? FileManager.default.startDownloadingUbiquitousItem(at: src)
            var err: NSError?
            NSFileCoordinator().coordinate(readingItemAt: src, options: [], error: &err) { url in
                _ = try? FileManager.default.copyItem(at: url, to: target)
            }
        }
    }

    /// Finished workouts in a backup, without building the whole model.
    static func finishedCount(_ url: URL) -> Int? {
        struct W: Decodable { var endedAt: Double? }
        struct S: Decodable { var workouts: [W]? }
        guard let data = try? coordinatedRead(url), let s = try? JSONDecoder().decode(S.self, from: data) else { return nil }
        return (s.workouts ?? []).filter { $0.endedAt != nil }.count
    }

    /// The local copy kept before every restore, in case a restore was the wrong one.
    static var beforeRestoreURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("before-restore.json")
    }

    // MARK: File coordination

    static func coordinatedWrite(_ url: URL, _ body: (URL) throws -> Void) throws {
        var coordError: NSError?
        var bodyError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { u in
            do { try body(u) } catch { bodyError = error }
        }
        if let e = coordError ?? bodyError { throw e }
    }

    static func coordinatedRead(_ url: URL) throws -> Data {
        var coordError: NSError?
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { u in
            result = Result { try Data(contentsOf: u) }
        }
        if let e = coordError { throw e }
        return try result.get()
    }
}

extension AppStore {
    /// Save a backup to the chosen folder. Runs after every finished workout and from Back up now.
    func backUp(done: ((Bool) -> Void)? = nil) {
        guard backups.hasFolder, let data = try? snapshot().encoded() else { done?(false); return }
        backups.backUp(data, clips: clips, done: done)
    }

    /// Replace everything with a backup. What was on the phone is kept locally first.
    func restore(_ s: Snapshot) {
        if let data = try? snapshot().encoded() {
            let url = Backups.beforeRestoreURL
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url, options: .atomic)
        }
        importSnapshot(s)
        saveNow()
    }
}

/// "Today", "Yesterday", "Thu, Oct 30", or "Oct 30, 2025" in another year.
func backupDay(_ d: Date, now: Date = Date()) -> String {
    let cal = Calendar.current
    if cal.isDate(d, inSameDayAs: now) { return "Today" }
    if let y = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(d, inSameDayAs: y) { return "Yesterday" }
    let f = DateFormatter()
    f.dateFormat = cal.component(.year, from: d) == cal.component(.year, from: now) ? "EEE, MMM d" : "MMM d, yyyy"
    return f.string(from: d)
}

func backupTime(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f.string(from: d)
}
