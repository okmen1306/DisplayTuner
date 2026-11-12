//
//  ProfilePicker.swift
//  DisplayTuner
//
//  Görev: Segmented profil seçici.
//  Faz: 5  ·  Kararlar: 7.1  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct ProfilePicker: View {
    let profiles: ProfileStore

    var body: some View {
        if profiles.profiles.count > 1 {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Profil").font(.subheadline.weight(.semibold))
                Picker("Profil", selection: Binding(get: { profiles.activeID }, set: { if let id = $0 { profiles.select(id) } })) {
                    ForEach(profiles.profiles) { Text($0.displayName).tag(Optional($0.id)) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }
}
