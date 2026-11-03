import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

extension View {
    /// The Photos and Files pickers for clips. Each pick is stored in the Jimmy library (videos
    /// at 720p) and, when a variation is given, added to that variation too. `pending` counts the
    /// picks still saving; `error` holds the last thing that went wrong.
    func clipImport(photos: Binding<Bool>, files: Binding<Bool>, pending: Binding<Int>, error: Binding<String?>,
                    to versionId: String?) -> some View {
        modifier(ClipImport(showPhotos: photos, showFiles: files, pending: pending, error: error, versionId: versionId))
    }
}

/// Shared by Form cues (adds to one variation) and the Jimmy library in Settings (library only).
@MainActor
private struct ClipImport: ViewModifier {
    @Environment(AppStore.self) private var store
    @Binding var showPhotos: Bool
    @Binding var showFiles: Bool
    @Binding var pending: Int
    @Binding var error: String?
    let versionId: String?

    @State private var photoItems: [PhotosPickerItem] = []

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: nil, selectionBehavior: .ordered,
                          matching: .any(of: [.videos, .images]))
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                photoItems = []
                importPhotos(items)
            }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: [.movie, .image], allowsMultipleSelection: true) { result in
                importFiles(result)
            }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) {
        error = nil
        pending += items.count
        Task {
            for item in items {
                let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
                do {
                    var picked: URL? = nil
                    if isVideo {
                        picked = try await item.loadTransferable(type: PickedMovie.self)?.url
                    } else {
                        picked = try await item.loadTransferable(type: PickedImage.self)?.url
                    }
                    if let picked { await save(picked, kind: isVideo ? .video : .photo) }
                    else { error = "One item could not be loaded from Photos." }
                } catch {
                    self.error = "One item could not be loaded from Photos."
                }
                pending -= 1
            }
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        error = nil
        guard case .success(let urls) = result else { return }
        // Copy out of the security scope right away; encoding happens after.
        var copies: [(URL, ClipKind)] = []
        for u in urls {
            let scoped = u.startAccessingSecurityScopedResource()
            defer { if scoped { u.stopAccessingSecurityScopedResource() } }
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("pick-\(uid()).\(u.pathExtension)")
            do {
                try FileManager.default.copyItem(at: u, to: tmp)
                let isVideo = UTType(filenameExtension: u.pathExtension)?.conforms(to: .movie) ?? false
                copies.append((tmp, isVideo ? .video : .photo))
            } catch {
                self.error = "\(u.lastPathComponent) could not be read."
            }
        }
        pending += copies.count
        Task {
            for (u, kind) in copies {
                await save(u, kind: kind)
                pending -= 1
            }
        }
    }

    /// Store one picked file in the library, and on the variation if there is one. Deletes the temporary copy.
    private func save(_ file: URL, kind: ClipKind) async {
        defer { try? FileManager.default.removeItem(at: file) }
        do {
            let c = try await ClipFiles.importFile(file, kind: kind, existing: store.clips)
            store.attach(c, to: versionId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// A video handed over by the Photos picker, copied to a temporary file we own.
struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { received in
            try PickedMovie(url: copyToTemp(received.file))
        }
    }
}

/// A photo handed over by the Photos picker, copied to a temporary file we own.
struct PickedImage: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .image) { SentTransferredFile($0.url) } importing: { received in
            try PickedImage(url: copyToTemp(received.file))
        }
    }
}

private func copyToTemp(_ file: URL) throws -> URL {
    let ext = file.pathExtension.isEmpty ? "dat" : file.pathExtension
    let dest = FileManager.default.temporaryDirectory.appendingPathComponent("pick-\(uid()).\(ext)")
    try FileManager.default.copyItem(at: file, to: dest)
    return dest
}
