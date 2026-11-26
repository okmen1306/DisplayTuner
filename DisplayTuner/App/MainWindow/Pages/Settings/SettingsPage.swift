//
//  SettingsPage.swift
//  DisplayTuner
//
//  Görev: Genel ayarlar: tema, dil, açılışta başlat, hakkında.
//  Kararlar: D-151  (bkz. AGENT_BRIEF.md)
//

import ServiceManagement
import SwiftUI

struct SettingsPage: View {
    @State private var appearance = AppAppearance.current
    @State private var language = AppLanguage.current
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Görünüm") {
                HStack(spacing: 12) {
                    ForEach(AppAppearance.allCases) { option in appearanceTile(option) }
                }
                .padding(.vertical, 6)
            }

            Section {
                Picker(selection: Binding(get: { language }, set: { new in
                    guard new != language else { return }
                    language = new
                    AppLanguage.select(new)
                })) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                } label: {
                    Label("Dil", systemImage: "globe")
                }
            } header: {
                Text("Dil / Language")
            } footer: {
                Text("Dil değişince uygulama yeniden başlar.")
            }

            menuBarSection

            Section("Genel") {
                Toggle(isOn: Binding(get: { launchAtLogin }, set: { on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        UserDefaults.standard.set(on, forKey: "launchAtLoginWanted")
                    } catch {}
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                })) {
                    Label("Açılışta başlat", systemImage: "power")
                }
            }

            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DisplayTuner").font(.headline)
                        Text("Sürüm \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Link(destination: URL(string: "https://github.com/okmen1306/DisplayTuner")!) {
                        Label("GitHub", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Menü bar paneli (D-161)

    @State private var dragging: String?
    private var layout: PopoverLayout { PopoverLayout.shared }

    private var displayKeys: [String] {
        let connected = ArrangementService.displays().map { PopoverLayout.key(for: $0.id) }
        return layout.sorted(Array(Set(["builtin", "monitor"] + connected)))
    }

    private var menuBarSection: some View {
        Section {
            ForEach(displayKeys, id: \.self) { key in
                HStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                        .help("Sürükleyip sırala")
                    Image(systemName: key == "builtin" ? "laptopcomputer" : "display")
                        .frame(width: 22).foregroundStyle(Color.accentColor)
                    TextField(text: Binding(get: { layout.names[key] ?? "" }, set: { layout.rename(key, to: $0) }),
                              prompt: Text(PopoverLayout.defaultName(key))) { EmptyView() }
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                    Spacer()
                    Button { step(key, -1) } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(.borderless).disabled(displayKeys.first == key)
                    Button { step(key, 1) } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(.borderless).disabled(displayKeys.last == key)
                    Toggle("", isOn: Binding(get: { layout.isVisible(key) }, set: { layout.setVisible(key, $0) }))
                        .labelsHidden().toggleStyle(.switch)
                }
                .padding(.vertical, 2)
                .opacity(dragging == key ? 0.4 : 1)
                .contentShape(Rectangle())
                .draggable(key) { Label(layout.name(key), systemImage: "display").padding(6) }
                .dropDestination(for: String.self) { items, _ in
                    guard let moved = items.first else { return false }
                    withAnimation { layout.move(moved, onto: key, in: displayKeys) }
                    return true
                } isTargeted: { on in if on { dragging = nil } }
            }
            Toggle(isOn: Binding(get: { layout.showEyeComfort }, set: { layout.showEyeComfort = $0 })) {
                Label("Göz konforu düğmesi", systemImage: "moon.stars")
            }
            Toggle(isOn: Binding(get: { layout.showBatteries }, set: { layout.showBatteries = $0 })) {
                Label("Pil durumu", systemImage: "battery.75percent")
            }
        } header: {
            Text("Menü bar paneli")
        } footer: {
            Text("Ekranları sürükleyerek (ya da oklarla) sırala, adını değiştir, panelde gösterip gizle. Ad ve sıra Ekran sayfasında da kullanılır.")
        }
    }

    private func step(_ key: String, _ delta: Int) {
        let keys = displayKeys
        guard let i = keys.firstIndex(of: key), keys.indices.contains(i + delta) else { return }
        withAnimation { layout.move(key, onto: keys[i + delta], in: keys) }
    }

    private func appearanceTile(_ option: AppAppearance) -> some View {
        let selected = option == appearance
        return Button {
            appearance = option
            AppAppearance.apply(option)
        } label: {
            VStack(spacing: 8) {
                preview(option)
                    .frame(width: 96, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : .secondary.opacity(0.3), lineWidth: selected ? 2.5 : 1))
                Label(option.title, systemImage: option.symbol)
                    .font(.callout.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.accentColor : .primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func preview(_ option: AppAppearance) -> some View {
        switch option {
        case .light: mini(bg: Color(white: 0.95), card: .white, line: Color(white: 0.8))
        case .dark: mini(bg: Color(white: 0.12), card: Color(white: 0.2), line: Color(white: 0.35))
        case .system:
            HStack(spacing: 0) {
                mini(bg: Color(white: 0.95), card: .white, line: Color(white: 0.8))
                mini(bg: Color(white: 0.12), card: Color(white: 0.2), line: Color(white: 0.35))
            }
        }
    }

    private func mini(bg: Color, card: Color, line: Color) -> some View {
        ZStack(alignment: .topLeading) {
            bg
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(Color.accentColor).frame(width: 22, height: 5)
                RoundedRectangle(cornerRadius: 4).fill(card).frame(height: 28)
                    .overlay(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Capsule().fill(line).frame(width: 30, height: 3)
                            Capsule().fill(line).frame(width: 20, height: 3)
                        }.padding(.leading, 6)
                    }
            }
            .padding(8)
        }
    }
}
