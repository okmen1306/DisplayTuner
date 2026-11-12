//
//  HUDView.swift
//  DisplayTuner
//
//  Görev: Dynamic Island tarzı kapsül görünümü.
//  Faz: 2  ·  Kararlar: D-70, 8.3  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct HUDView: View {
    let symbol: String
    let text: String
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
            if expanded {
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .transition(.opacity)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(Capsule().fill(.black))
        .frame(maxWidth: .infinity)
        .onAppear {
            if reduceMotion { expanded = true } else { withAnimation(Theme.spring) { expanded = true } }
        }
        .accessibilityElement(children: .combine)
    }
}
