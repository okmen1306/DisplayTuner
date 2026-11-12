//
//  SettingRow.swift
//  DisplayTuner
//
//  Görev: Etiket + kontrol + sıfırlama (↺) satırı.
//  Faz: 1  ·  Kararlar: 9  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct SettingRow<Control: View>: View {
    let title: LocalizedStringKey
    var symbol: String?
    var onReset: (() -> Void)?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }
            Text(title)
            Spacer(minLength: Theme.Spacing.m)
            control
            if let onReset {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Varsayılana döndür")
                .accessibilityLabel("Varsayılana döndür")
            }
        }
    }
}
