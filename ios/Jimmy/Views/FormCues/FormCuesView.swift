import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Form cues for one variation: its clips (three per row), its links, and an Add section.
/// Opened from the variation page (pushed) and from the workout card (as a sheet).
struct FormCuesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let versionId: String
    var showsClose = false

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var showLibrary = false
    @State private var showLink = false
    @State private var linkText = ""
    @State private var pending = 0
    @State private var importError: String? = nil
    @State private var playing: PlayerStart? = nil

    struct PlayerStart: Identifiable { let id = UUID(); let clips: [Clip]; let index: Int }

    var body: some View {
        if let v = store.version(versionId) {
            let clips = store.clips(of: v.id)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Form cues").font(.system(size: 28, weight: .heavy)).tracking(-0.5).foregroundStyle(p.text)
                        Text(store.fullName(v)).font(.system(size: 14, weight: .semibold)).foregroundStyle(p.secondary)
                    }
                    if !clips.isEmpty || pending > 0 {
                        LazyVGrid(columns: clipColumns, spacing: 6) {
                            ForEach(Array(clips.enumerated()), id: \.element.id) { i, c in
                                Button { playing = PlayerStart(clips: clips, index: i) } label: { ClipTile(clip: c) }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) { store.detach(c.id, from: v.id) } label: {
                                            Label("Remove from this exercise", systemImage: "minus.square")
                                        }
                                    }
                            }
                            ForEach(0..<pending, id: \.self) { _ in ClipTilePlaceholder() }
                        }
                    }
                    if !v.media.isEmpty {
                        SectionLabel("Links").padding(.top, 4)
                        VStack(spacing: 0) {
                            ForEach(Array(v.media.enumerated()), id: \.element.url) { i, m in
                                if i > 0 { Divider1() }
                                linkRow(m, versionId: v.id)
                            }
                        }
                        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    }
                    SectionLabel("Add").padding(.top, 4)
                    VStack(spacing: 0) {
                        addRow("Photos", icon: "photo.on.rectangle") { showPhotos = true }
                        Divider1()
                        addRow("Files", icon: "folder") { showFiles = true }
                        Divider1()
                        addRow("From my clips", icon: "square.grid.3x3") { showLibrary = true }
                        Divider1()
                        addRow("Paste a link", icon: "link") { linkText = ""; showLink = true }
                    }
                    .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    if let importError {
                        Text(importError).font(.system(size: 13)).foregroundStyle(p.danger)
                    }
                }
                .padding(16)
            }
            .background(p.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(p.bg, for: .navigationBar)
            .toolbar {
                if showsClose {
                    ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() }.tint(p.accent) }
                }
            }
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
            .sheet(isPresented: $showLibrary) {
                NavigationStack { MyClipsView(mode: .pick(versionId: v.id)) }
                    .presentationBackground(p.bg)
            }
            .alert("Paste a link", isPresented: $showLink) {
                TextField("tiktok.com/…", text: $linkText).textInputAutocapitalization(.never).keyboardType(.URL)
                Button("Add") { store.addLink(linkText, to: v.id) }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(item: $playing) { s in ClipPlayerView(clips: s.clips, start: s.index) }
        }
    }

    private func addRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.accent).frame(width: 24)
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                Spacer()
                Chevron()
            }
            .padding(.horizontal, 16).frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func linkRow(_ m: Media, versionId: String) -> some View {
        if let url = URL(string: m.url) {
            Link(destination: url) {
                HStack {
                    Text(linkLabel(m.url)).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.text).lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold)).foregroundStyle(p.muted)
                }
                .padding(.horizontal, 16).frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) { store.removeLink(m.url, from: versionId) } label: { Label("Remove link", systemImage: "trash") }
            }
        }
    }

    // MARK: Import

    private func importPhotos(_ items: [PhotosPickerItem]) {
        importError = nil
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
                    else { importError = "One item could not be loaded from Photos." }
                } catch {
                    importError = "One item could not be loaded from Photos."
                }
                pending -= 1
            }
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        importError = nil
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
                importError = "\(u.lastPathComponent) could not be read."
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

    /// Store one picked file and attach it to this variation. Deletes the temporary copy.
    private func save(_ file: URL, kind: ClipKind) async {
        defer { try? FileManager.default.removeItem(at: file) }
        do {
            let c = try await ClipFiles.importFile(file, kind: kind, existing: store.clips)
            store.attach(c, to: versionId)
        } catch {
            importError = error.localizedDescription
        }
    }
}

let clipColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

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

// MARK: - Tiles

/// One clip in a grid: its thumbnail, cropped to a tall tile, with the length for videos.
struct ClipTile: View {
    @Environment(\.palette) private var p
    let clip: Clip
    var selected = false
    var count: Int? = nil
    @State private var image: UIImage? = nil

    var body: some View {
        Color.clear
            .aspectRatio(9.0 / 14.0, contentMode: .fit)
            .overlay {
                if let image { Image(uiImage: image).resizable().scaledToFill() } else { p.elevated }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if clip.kind == .video, let d = clipDuration(clip.duration) {
                    Text(d).font(.system(size: 11, weight: .bold)).monospacedDigit().foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let count, count > 0 {
                    Text("\(count)").font(.system(size: 11, weight: .heavy)).foregroundStyle(p.onAccent)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(p.accent, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .padding(6)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? p.accent : .clear, lineWidth: 3)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .task(id: clip.id) { image = await ClipFiles.thumbnail(clip) }
    }
}

/// Stands in for a clip that is still being saved.
struct ClipTilePlaceholder: View {
    @Environment(\.palette) private var p
    var body: some View {
        Color.clear
            .aspectRatio(9.0 / 14.0, contentMode: .fit)
            .overlay { p.elevated }
            .overlay { ProgressView().tint(p.accent) }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
