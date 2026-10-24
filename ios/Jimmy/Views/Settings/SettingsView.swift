import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p
    @State private var importing = false
    @State private var confirmReset = false
    @State private var importError: String? = nil
    @State private var newIdea = ""
    @State private var apiKey = Keychain.apiKey ?? ""

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ScreenTitle("Settings")
                    Group {
                        SectionLabel("Look")
                        VStack(spacing: 0) {
                            NavigationLink { AppearanceView() } label: {
                                SettingsRow(title: "Appearance") {
                                    Text("\(store.settings.appearance.rawValue.capitalized) · \(store.settings.scheme.label)").font(.system(size: 14)).foregroundStyle(p.muted)
                                    Chevron()
                                }
                            }
                            .buttonStyle(.plain)
                            Divider1()
                            NavigationLink { HomeBlocksView() } label: {
                                SettingsRow(title: "Home blocks") {
                                    Text("\(store.settings.homeBlocks.filter { $0.on }.count) of \(store.settings.homeBlocks.count) on").font(.system(size: 14)).foregroundStyle(p.muted)
                                    Chevron()
                                }
                            }
                            .buttonStyle(.plain)
                            Divider1()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Wall quote").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                                TextField("Something you'd paint on the gym wall", text: $store.settings.quote, axis: .vertical)
                                    .lineLimit(1...3)
                                    .padding(12)
                                    .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                                    .foregroundStyle(p.text)
                                    .onChange(of: store.settings.quote) { _, _ in store.markDirty() }
                                Text("Shown on Home in block capitals.").font(.system(size: 13)).foregroundStyle(p.muted)
                            }
                            .padding(16)
                        }
                        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    }
                    Group {
                        SectionLabel("Workout").padding(.top, 4)
                        VStack(spacing: 0) {
                            SettingsRow(title: "Rest timer", subtitle: store.settings.restTimer ? "On. Shows a \(store.settings.restSeconds) second timer after each set." : "Off. Shows a timer after each set.") {
                                RectToggle(on: Binding(get: { store.settings.restTimer }, set: { v in store.update { $0.restTimer = v } }))
                            }
                            if store.settings.restTimer {
                                Divider1()
                                SettingsRow(title: "Rest length") {
                                    HStack(spacing: 6) {
                                        ForEach([60, 90, 120, 180], id: \.self) { s in
                                            Chip(text: "\(s)s", on: store.settings.restSeconds == s, small: true) { store.update { $0.restSeconds = s } }
                                        }
                                    }
                                }
                            }
                            Divider1()
                            SettingsRow(title: "Go-up sound", subtitle: "Short chime when you beat the range.") {
                                RectToggle(on: Binding(get: { store.settings.sound }, set: { v in store.update { $0.sound = v } }))
                            }
                            Divider1()
                            SettingsRow(title: "Units") {
                                HStack(spacing: 6) {
                                    Chip(text: "kg", on: store.settings.unit == .kg, small: true) { store.update { $0.unit = .kg } }
                                    Chip(text: "lb", on: store.settings.unit == .lbs, small: true) { store.update { $0.unit = .lbs } }
                                }
                            }
                        }
                        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    }
                    Group {
                        SectionLabel("Assistant").padding(.top, 4)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Claude API key").font(.system(size: 16, weight: .semibold)).foregroundStyle(p.text)
                            SecureField("sk-ant-…", text: $apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                                .foregroundStyle(p.text)
                                .onChange(of: apiKey) { _, v in Keychain.set(v, for: Keychain.apiKeyAccount) }
                            Text(apiKey.isEmpty ? "Coverage uses the built-in rules until a key is set." : "Coverage asks Claude when a split or its goals change.")
                                .font(.system(size: 13)).foregroundStyle(p.muted)
                        }
                        .padding(16)
                        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    }
                    Group {
                        SectionLabel("Data").padding(.top, 4)
                        VStack(spacing: 0) {
                            if let url = store.exportURL {
                                ShareLink(item: url) {
                                    SettingsRow(title: "Export JSON", subtitle: "\(store.workouts.count) workouts, \(store.versions.count) exercises") { Chevron() }
                                }
                                .buttonStyle(.plain)
                            }
                            Divider1()
                            Button { importing = true } label: {
                                SettingsRow(title: "Import", subtitle: "A Jimmy export from the web app or this one. Replaces everything.") { Chevron() }
                            }
                            .buttonStyle(.plain)
                            Divider1()
                            Button { confirmReset = true } label: {
                                SettingsRow(title: "Reset to Notion seed", subtitle: "Erases workouts and routines. Ideas and settings stay.") { EmptyView() }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(p.danger)
                        }
                        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        Text("Data lives on this phone in the app's own folder, so iOS backs it up with the phone. Export now and then until sync exists.")
                            .font(.system(size: 13)).foregroundStyle(p.muted).padding(.horizontal, 2)
                    }
                    Group {
                        SectionLabel("Ideas (\(store.ideas.count))").padding(.top, 4)
                        VStack(spacing: 0) {
                            HStack(spacing: 8) {
                                TextField("A bug or a change you want", text: $newIdea)
                                    .padding(10)
                                    .background(p.elevated, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                                    .foregroundStyle(p.text)
                                Chip(text: "Add", on: true, small: true) {
                                    let t = newIdea.trimmingCharacters(in: .whitespaces)
                                    guard !t.isEmpty else { return }
                                    store.put(Idea(id: uid(), kind: "feature", text: t, createdAt: nowMs()))
                                    newIdea = ""
                                }
                            }
                            .padding(16)
                            ForEach(store.ideas.sorted { $0.createdAt > $1.createdAt }) { i in
                                Divider1()
                                HStack(alignment: .top, spacing: 12) {
                                    Button { var ii = i; ii.done = !(i.done ?? false); store.put(ii) } label: { RectCheck(on: i.done ?? false, size: 26) }.buttonStyle(.plain)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(i.text).font(.system(size: 15)).foregroundStyle(p.text).strikethrough(i.done ?? false)
                                        Text(Date(timeIntervalSince1970: i.createdAt / 1000).formatted(date: .abbreviated, time: .omitted)).font(.system(size: 12)).foregroundStyle(p.muted)
                                    }
                                    Spacer()
                                    Button { store.deleteIdea(i.id) } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(p.muted) }
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                            }
                        }
                        .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    }
                    Text("Jimmy for iOS · v0.1").font(.system(size: 12)).foregroundStyle(p.muted).padding(.top, 8)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            .screen()
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { result in
                switch result {
                case .success(let url):
                    let ok = url.startAccessingSecurityScopedResource()
                    defer { if ok { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try Data(contentsOf: url)
                        let s = try Snapshot.decode(data)
                        guard !s.versions.isEmpty else { importError = "That file has no exercises in it. Is it a Jimmy export?"; return }
                        store.importSnapshot(s)
                    } catch { importError = "Could not read that file: \(error.localizedDescription)" }
                case .failure(let e): importError = e.localizedDescription
                }
            }
            .alert("Import failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK") { importError = nil }
            } message: { Text(importError ?? "") }
            .alert("Reset everything?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { store.resetToSeed() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Workouts, routines and exercises go back to the Notion seed. Export first if you want a copy.") }
        }
    }
}

struct AppearanceView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Mode")
                HStack(spacing: 10) {
                    ForEach([Appearance.dark, .light, .system], id: \.self) { a in
                        Button { store.update { $0.appearance = a } } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(a == .light ? Color(hex: 0xF6F7FB) : Color(hex: 0x0A0A0D))
                                    if a == .system {
                                        HStack(spacing: 0) { Color(hex: 0x0A0A0D); Color(hex: 0xF6F7FB) }.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                    RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(p.border, lineWidth: 1)
                                }
                                .frame(width: 44, height: 30)
                                Text(a.rawValue.capitalized).font(.system(size: 14, weight: store.settings.appearance == a ? .bold : .semibold))
                                    .foregroundStyle(store.settings.appearance == a ? p.text : p.secondary)
                            }
                            .frame(maxWidth: .infinity).frame(height: 92)
                            .background(p.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(store.settings.appearance == a ? p.accent : p.line, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                SectionLabel("Color scheme").padding(.top, 6)
                VStack(spacing: 0) {
                    ForEach(Array(AccentScheme.allCases.enumerated()), id: \.element) { i, s in
                        Button { store.update { $0.scheme = s } } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.swatch(s)).frame(width: 36, height: 36)
                                Text(s.label).font(.system(size: 16, weight: store.settings.scheme == s ? .bold : .semibold)).foregroundStyle(store.settings.scheme == s ? p.text : p.secondary)
                                Spacer()
                                RectCheck(on: store.settings.scheme == s)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if i < AccentScheme.allCases.count - 1 { Divider1() }
                    }
                }
                .background(p.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                SectionLabel("Preview").padding(.top, 6)
                HStack(spacing: 10) {
                    preview(dark: true)
                    preview(dark: false)
                }
                Text("Light mode uses a darker accent so text on buttons stays readable.").font(.system(size: 13)).foregroundStyle(p.muted)
            }
            .padding(16)
        }
        .screen()
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func preview(dark: Bool) -> some View {
        let pp = Palette.make(scheme: store.settings.scheme, dark: dark)
        return VStack(alignment: .leading, spacing: 6) {
            Text(dark ? "DARK" : "LIGHT").font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(pp.muted)
            Text("Start workout").font(.system(size: 13, weight: .bold)).foregroundStyle(pp.onAccent).frame(maxWidth: .infinity).frame(height: 34)
                .background(pp.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text("32 kg").font(.system(size: 13, weight: .semibold)).foregroundStyle(pp.text).frame(maxWidth: .infinity).frame(height: 34)
                .background(pp.elevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(12)
        .background(pp.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(pp.line, lineWidth: 1))
    }
}

struct HomeBlocksView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.palette) private var p

    var body: some View {
        List {
            Section {
                ForEach(store.settings.homeBlocks) { b in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(b.block.title).font(.system(size: 16, weight: .bold)).foregroundStyle(p.text)
                            Text(b.block.subtitle).font(.system(size: 13)).foregroundStyle(p.muted)
                        }
                        Spacer()
                        RectToggle(on: Binding(get: { b.on }, set: { v in
                            store.update { s in if let i = s.homeBlocks.firstIndex(where: { $0.block == b.block }) { s.homeBlocks[i].on = v } }
                        }))
                    }
                    .padding(.horizontal, 14).frame(minHeight: 64)
                    .opacity(b.on ? 1 : 0.7)
                    .rowCard(p, radius: 16)
                }
                .onMove { from, to in store.update { $0.homeBlocks.move(fromOffsets: from, toOffset: to) } }
            } header: {
                Text("Switch blocks on or off and drag to set the order on Home.").font(.system(size: 14)).foregroundStyle(p.muted).padding(.horizontal, 16).textCase(nil)
            }
            if store.settings.homeBlocks.contains(where: { $0.block == .watchExercise && $0.on }) {
                Section {
                    Picker("Exercise to watch", selection: Binding(get: { store.settings.watchVersionId ?? "" }, set: { v in store.update { $0.watchVersionId = v.isEmpty ? nil : v } })) {
                        Text("None").tag("")
                        ForEach(store.versions.sorted { store.fullName($0) < store.fullName($1) }) { v in Text(store.fullName(v)).tag(v.id) }
                    }
                    .foregroundStyle(p.text)
                    .padding(.horizontal, 14).frame(minHeight: 52)
                    .rowCard(p, radius: 16)
                }
            }
        }
        .cardList()
        .navigationTitle("Home blocks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(p.bg, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
    }
}
