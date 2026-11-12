//
//  InlineColorPicker.swift
//  DisplayTuner
//
//  Görev: Ayrı sistem penceresi yerine düğmenin sağında açılan renk paleti.
//  Kararlar: D-147  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct InlineColorPicker: View {
    let title: LocalizedStringKey
    @Binding var color: Color
    @State private var open = false
    @State private var hue = 0.0
    @State private var saturation = 1.0
    @State private var brightness = 1.0

    private static let palette: [Color] = [
        .white, Color(white: 0.75), Color(white: 0.5), Color(white: 0.25), .black,
        .red, .orange, .yellow, .green, .mint,
        .teal, .cyan, .blue, .indigo, .purple,
        .pink, .brown, Color(red: 1, green: 0, blue: 0.99), Color(red: 0.2, green: 1, blue: 0.4), Color(red: 1, green: 0.85, blue: 0.6),
    ]

    var body: some View {
        LabeledContent(title) {
            Button { open.toggle() } label: {
                RoundedRectangle(cornerRadius: 5).fill(color)
                    .frame(width: 44, height: 22)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.secondary.opacity(0.5)))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $open, arrowEdge: .trailing) { panel }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 6), count: 5), spacing: 6) {
                ForEach(Array(Self.palette.enumerated()), id: \.offset) { _, c in
                    Button { color = c } label: {
                        Circle().fill(c).frame(width: 24, height: 24)
                            .overlay(Circle().strokeBorder(.secondary.opacity(0.4)))
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider()
            slider("Ton", $hue)
            slider("Doygunluk", $saturation)
            slider("Parlaklık", $brightness)
        }
        .padding(Theme.Spacing.m)
        .frame(width: 200)
        .onAppear {
            let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
            hue = ns.hueComponent; saturation = ns.saturationComponent; brightness = ns.brightnessComponent
        }
    }

    private func slider(_ label: LocalizedStringKey, _ value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Slider(value: Binding(get: { value.wrappedValue }, set: {
                value.wrappedValue = $0
                color = Color(hue: hue, saturation: saturation, brightness: brightness)
            }), in: 0...1)
        }
    }
}
