//
//  CriticalAlertView.swift
//  DisplayTuner
//
//  Görev: iPhone 'Düşük Pil' uyarısı görünümü.
//  Faz: 2  ·  Kararlar: D-70, 8.2  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct CriticalAlertView: View {
    let title: String
    let message: String
    let onDismiss: () -> Void
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.s) {
                Image(systemName: "battery.0percent")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.m)
            .padding(.top, Theme.Spacing.s)

            Divider()
            Button(action: onDismiss) {
                Text("Tamam")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: 270)
        .glassBackground(cornerRadius: Theme.Radius.card)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            if reduceMotion { appeared = true } else { withAnimation(Theme.spring) { appeared = true } }
        }
    }
}
