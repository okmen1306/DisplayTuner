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
