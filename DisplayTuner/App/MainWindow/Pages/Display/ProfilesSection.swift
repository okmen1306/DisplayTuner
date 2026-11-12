//
//  ProfilesSection.swift
//  DisplayTuner
//
//  Görev: Profil seç / kopyala / yeniden adlandır / sil; test desenleri.
//  Faz: 5  ·  Kararlar: D-38, 7.2  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct ProfilesSection: View {
    let profiles: ProfileStore
    @State private var newName = ""
    @State private var renaming: UUID?

    var body: some View {
        Section {
            ForEach(Array(profiles.profiles.enumerated()), id: \.element.id) { index, profile in
                HStack {
                    Image(systemName: profile.id == profiles.activeID ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(profile.id == profiles.activeID ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    if renaming == profile.id {
                        TextField("Ad", text: $newName, onCommit: {
                            profiles.rename(profile.id, to: newName)
                            renaming = nil
                        })
                    } else {
                        Text(profile.name)
                    }
                    Spacer()
                    if index < 4 { Text("⌃⌥\(index + 1)").font(.caption.monospaced()).foregroundStyle(.secondary) }
                    Menu {
                        Button("Yeniden Adlandır") { newName = profile.name; renaming = profile.id }
                        Button("Sil", role: .destructive) { profiles.delete(profile.id) }
                            .disabled(profiles.profiles.count < 2)
                    } label: { Image(systemName: "ellipsis.circle") }
                        .menuStyle(.borderlessButton).fixedSize()
                }
                .contentShape(Rectangle())
                .onTapGesture { profiles.select(profile.id) }
            }
            HStack {
                Button("Aktif Profili Kopyala") {
                    profiles.duplicateActive(named: "Profil \(profiles.profiles.count + 1)")
                }
                Spacer()
                Button("Test Desenleri…") { TestPatternWindow.show() }
            }
        } header: {
            Text("Profiller")
        } footer: {
            Text("Gündüz, gece veya film için aktif profili kopyalayıp ayarlarını değiştirin.")
        }
    }
}
