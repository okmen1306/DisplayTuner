//
//  SidebarIcon.swift
//  DisplayTuner
//
//  Görev: Renkli yuvarlatılmış kare üzerinde SF Symbol.
//  Faz: 1  ·  Kararlar: 9  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

/// Sistem Ayarları tarzı sidebar ikonu.
struct SidebarIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.sidebarIcon, style: .continuous)
            .fill(color.gradient)
            .frame(width: 20, height: 20)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
