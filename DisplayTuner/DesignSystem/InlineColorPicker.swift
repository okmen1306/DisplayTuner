//
//  InlineColorPicker.swift
//  DisplayTuner
//
//  Görev: Renk düğmesi; tıklanınca ana pencere sağa genişler ve tam renk seçici
//         (çark, parlaklık, HEX, RGB, ekrandan seç, palet) pencerenin içinde açılır.
//  Kararlar: D-147, D-149  (bkz. AGENT_BRIEF.md)
//

import AppKit
import SwiftUI

/// Ana pencerenin sağ renk panelini yönetir (D-149). Pencere denetleyicisi genişlik değişimini dinler.
@MainActor
@Observable
final class ColorPanelHost {
    struct Edit: Identifiable {
        let id: UUID
        let title: LocalizedStringKey
        let color: Binding<Color>
    }

    static let panelWidth: CGFloat = 300
    private(set) var edit: Edit?
    /// true: panel açıldı (pencere genişlemeli), false: kapandı.
    @ObservationIgnored var onVisibilityChange: ((Bool) -> Void)?

    func toggle(id: UUID, title: LocalizedStringKey, color: Binding<Color>) {
        if edit?.id == id { close(); return }
        let wasOpen = edit != nil
        if !wasOpen { onVisibilityChange?(true) }
        edit = Edit(id: id, title: title, color: color)
    }

    func close() {
        guard edit != nil else { return }
        edit = nil
        onVisibilityChange?(false)
    }
}

extension EnvironmentValues {
    @Entry var colorPanel: ColorPanelHost? = nil
}

/// Formdaki renk satırı: sadece renk kutusu; düzenleme sağ panelde.
struct InlineColorPicker: View {
    let title: LocalizedStringKey
    @Binding var color: Color
    @Environment(\.colorPanel) private var host
    @State private var id = UUID()

    var body: some View {
        let active = host?.edit?.id == id
        LabeledContent(title) {
            Button { host?.toggle(id: id, title: title, color: $color) } label: {
                RoundedRectangle(cornerRadius: 5).fill(color)
                    .frame(width: 44, height: 22)
                    .overlay(RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(active ? Color.accentColor : .secondary.opacity(0.5), lineWidth: active ? 2 : 1))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Pencerenin sağına eklenen tam renk seçici.
struct ColorSidePanel: View {
    let edit: ColorPanelHost.Edit
    let onClose: () -> Void

    @State private var hue = 0.0
    @State private var saturation = 0.0
    @State private var brightness = 1.0
    @State private var hex = ""
    @AppStorage("recentColors") private var recentRaw = ""

    private static let palette: [String] = [
        "FFFFFF", "BFBFBF", "808080", "404040", "000000", "FF3B30",
        "FF9500", "FFCC00", "34C759", "00C7BE", "30B0C7", "32ADE6",
        "007AFF", "5856D6", "AF52DE", "FF2D55", "A2845E", "FF00FC",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text(edit.title).font(.headline)
                Spacer()
                Button { onClose() } label: { Image(systemName: "xmark.circle.fill").font(.title3) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
            }

            wheel.frame(width: 220, height: 220).frame(maxWidth: .infinity)

            labeledSlider("Parlaklık", value: $brightness,
                          gradient: [Color(hue: hue, saturation: saturation, brightness: 0),
                                     Color(hue: hue, saturation: saturation, brightness: 1)])

            HStack(spacing: Theme.Spacing.s) {
                RoundedRectangle(cornerRadius: 6).fill(current)
                    .frame(width: 44, height: 28)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.secondary.opacity(0.4)))
                TextField("HEX", text: $hex)
                    .textFieldStyle(.roundedBorder).font(.body.monospaced())
                    .onSubmit { applyHex(hex) }
                Button { sampleScreen() } label: { Image(systemName: "eyedropper") }
                    .help("Ekrandan renk seç")
            }

            rgbRow

            section("Hazır renkler", Self.palette)
            if !recents.isEmpty { section("Son kullanılanlar", recents) }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .frame(width: ColorPanelHost.panelWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.background)
        .onAppear(perform: loadFromBinding)
        .onDisappear { remember(hexValue) }
        .onChange(of: edit.id) { loadFromBinding() }
    }

    // MARK: Çark (ton + doygunluk)

    private var wheel: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let r = size / 2
            ZStack {
                Circle().fill(AngularGradient(colors: (0...12).map { Color(hue: Double($0) / 12, saturation: 1, brightness: 1) },
                                              center: .center))
                Circle().fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: r))
                Circle().fill(.black.opacity(1 - brightness))
                Circle().strokeBorder(.secondary.opacity(0.3))
                Circle()
                    .fill(current)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                    .shadow(radius: 2)
                    .position(x: r + cos(hue * 2 * .pi) * saturation * r,
                              y: r + sin(hue * 2 * .pi) * saturation * r)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let dx = g.location.x - r, dy = g.location.y - r
                var angle = atan2(dy, dx) / (2 * .pi)
                if angle < 0 { angle += 1 }
                hue = angle
                saturation = min(1, hypot(dx, dy) / r)
                if brightness < 0.05 { brightness = 1 }
                push()
            })
        }
    }

    // MARK: RGB

    private var rgbRow: some View {
        let (r, g, b) = rgb
        return HStack(spacing: Theme.Spacing.s) {
            channel("R", r) { setRGB($0, g, b) }
            channel("G", g) { setRGB(r, $0, b) }
            channel("B", b) { setRGB(r, g, $0) }
        }
    }

    private func channel(_ label: String, _ value: Int, set: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, value: Binding(get: { value }, set: { set(max(0, min(255, $0))) }), format: .number)
                .textFieldStyle(.roundedBorder).font(.callout.monospacedDigit())
        }
    }

    // MARK: Paletler

    private func section(_ title: LocalizedStringKey, _ hexes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 8), count: 6), spacing: 8) {
                ForEach(hexes, id: \.self) { h in
                    Button { applyHex(h) } label: {
                        Circle().fill(Self.color(hex: h) ?? .clear).frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(.secondary.opacity(0.4)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recents: [String] { recentRaw.split(separator: ",").map(String.init) }

    private func remember(_ h: String) {
        var list = recents.filter { $0 != h }
        list.insert(h, at: 0)
        recentRaw = list.prefix(12).joined(separator: ",")
    }

    // MARK: Dönüşümler

    private var current: Color { Color(hue: hue, saturation: saturation, brightness: brightness) }

    private var rgb: (Int, Int, Int) {
        let ns = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
        return (Int((ns.redComponent * 255).rounded()), Int((ns.greenComponent * 255).rounded()),
                Int((ns.blueComponent * 255).rounded()))
    }

    private func loadFromBinding() {
        let ns = NSColor(edit.color.wrappedValue).usingColorSpace(.sRGB) ?? .white
        set(ns, push: false)
    }

    private func set(_ ns: NSColor, push shouldPush: Bool = true) {
        let c = ns.usingColorSpace(.sRGB) ?? .white
        if c.saturationComponent > 0.001 { hue = c.hueComponent }   // gri tonlarda tonu koru
        saturation = c.saturationComponent
        brightness = c.brightnessComponent
        hex = hexValue
        if shouldPush { edit.color.wrappedValue = current }
    }

    private func push() {
        hex = hexValue
        edit.color.wrappedValue = current
    }

    private func setRGB(_ r: Int, _ g: Int, _ b: Int) {
        set(NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1))
    }

    private func applyHex(_ h: String) {
        guard let c = Self.nsColor(hex: h) else { hex = hexValue; return }
        set(c)
        remember(hexValue)
    }

    private func sampleScreen() {
        NSColorSampler().show { picked in
            guard let picked else { return }
            Task { @MainActor in
                set(picked)
                remember(hexValue)
            }
        }
    }

    private func labeledSlider(_ label: LocalizedStringKey, value: Binding<Double>, gradient: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            ZStack {
                Capsule().fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)).frame(height: 6)
                Slider(value: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0; push() }), in: 0...1)
            }
        }
    }

    private var hexValue: String {
        let (r, g, b) = rgb
        return String(format: "%02X%02X%02X", r, g, b)
    }

    private static func nsColor(hex: String) -> NSColor? {
        let s = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    private static func color(hex: String) -> Color? { nsColor(hex: hex).map { Color(nsColor: $0) } }
}
