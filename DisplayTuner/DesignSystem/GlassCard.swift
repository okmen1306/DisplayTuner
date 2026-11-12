//
//  GlassCard.swift
//  DisplayTuner
//
//  Görev: Liquid Glass / ultraThinMaterial kart.
//  Faz: 1  ·  Kararlar: 9  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = Theme.Radius.card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassBackground(cornerRadius: cornerRadius)
    }
}

extension View {
    /// macOS 26+ Liquid Glass, eski sürümlerde ultraThinMaterial.
    @ViewBuilder
    func glassBackground(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
