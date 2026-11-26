//
//  MouseSideButtonsView.swift
//  DisplayTuner
//
//  Görev: Tuş önizlemesi: mouse çizimi + orta tuş + iki yan tuş; basınca yanar, her tuşa eylem seçilir.
//  Kararlar: D-156  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct MouseSideButtonsView: View {
    @Bindable var buttons: MouseButtonMapper
    @State private var lit: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            mouseDrawing
                .frame(width: 150, height: 210)
            VStack(alignment: .leading, spacing: 14) {
                buttonRow(number: 2, title: String(localized: "Orta tuş (tekerleğe bas)"), selection: $buttons.button2, color: .orange,
                          options: MouseButtonMapper.Action.gestureFirst)
                buttonRow(number: 4, title: String(localized: "Ön yan tuş"), selection: $buttons.button4, color: .blue)
                buttonRow(number: 3, title: String(localized: "Arka yan tuş"), selection: $buttons.button3, color: .purple)
                dpiRow
                Text(buttons.isEnabled
                     ? String(localized: "Bir yan tuşa bas: çizimde yanar, hangisi olduğunu görürsün.")
                     : String(localized: "Yan tuşlar kapalı; mouse tuşları macOS'un varsayılanıyla çalışır."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .onChange(of: buttons.pressTick) {
            guard let n = buttons.lastPressed, [2, 3, 4].contains(n) else { return }
            withAnimation(.easeOut(duration: 0.12)) { lit = n }
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeIn(duration: 0.3)) { if lit == n { lit = nil } }
            }
        }
    }

    // MARK: Çizim (soldan görünüm; yan tuşlar başparmak tarafında)

    private var mouseDrawing: some View {
        ZStack {
            // Gövde
            RoundedRectangle(cornerRadius: 70, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.32), Color(white: 0.14)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 70, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
                .frame(width: 120, height: 200)
                .offset(x: 12)
            // Sol/sağ tık ayrımı ve tekerlek
            Rectangle().fill(.black.opacity(0.45)).frame(width: 1.5, height: 70).offset(x: 12, y: -62)
            Capsule().fill(lit == 2 ? AnyShapeStyle(Color.orange) : AnyShapeStyle(Color(white: 0.55)))
                .overlay(Capsule().strokeBorder(Color.orange.opacity(0.8), lineWidth: 2))
                .shadow(color: lit == 2 ? .orange : .clear, radius: 10)
                .scaleEffect(lit == 2 ? 1.15 : 1)
                .frame(width: 12, height: 30).offset(x: 12, y: -64)
            // DPI tuşu (tekerleğin arkasında); mouse'un kendi içinde DPI değiştirir
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.45), Color(white: 0.25)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Color.green.opacity(0.75), lineWidth: 1.5))
                .frame(width: 14, height: 18)
                .offset(x: 12, y: -30)
            // ROG logosu yerine ince ışık şeridi
            Capsule().fill(LinearGradient(colors: [.red.opacity(0.8), .pink.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                .frame(width: 4, height: 34).offset(x: 12, y: 40).blur(radius: 0.6)
            // Yan tuşlar (sol kenar): ön = üstte, arka = altta
            sideButton(number: 4, color: .blue).offset(x: -46, y: -14)
            sideButton(number: 3, color: .purple).offset(x: -46, y: 22)
        }
    }

    private func sideButton(number: Int, color: Color) -> some View {
        let on = lit == number
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(on ? AnyShapeStyle(color) : AnyShapeStyle(LinearGradient(colors: [Color(white: 0.5), Color(white: 0.3)], startPoint: .top, endPoint: .bottom)))
            .frame(width: 14, height: 32)
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(color.opacity(on ? 1 : 0.7), lineWidth: 2))
            .shadow(color: on ? color.opacity(0.9) : .clear, radius: on ? 10 : 0)
            .scaleEffect(on ? 1.12 : 1)
    }

    /// D-162: DPI tuşu Mac'e olay göndermiyor (iki kayıtta da hiçbir arayüzden gelmedi); mouse kendi içinde DPI değiştirir.
    /// Atanabilmesi için mouse'un tuş haritasının yazılması gerekiyor (51 21 … E6 → F18); kullanıcı sonraya bıraktı.
    private var dpiRow: some View {
        HStack(spacing: 10) {
            Circle().fill(Color.green).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text("DPI tuşu").font(.callout.weight(.semibold))
                Text("DPI değiştirir (mouse'un kendi içinde)").font(.callout).foregroundStyle(.secondary)
                Text("Atama yakında: mouse'un tuş ayarı yazılınca bu tuşa da eylem verilebilecek.")
                    .font(.caption).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
    }

    private func buttonRow(number: Int, title: String, selection: Binding<MouseButtonMapper.Action>, color: Color,
                           options: [MouseButtonMapper.Action] = MouseButtonMapper.Action.allCases) -> some View {
        let on = lit == number
        return HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
                .shadow(color: on ? color : .clear, radius: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.callout.weight(.semibold))
                Picker("", selection: selection) {
                    ForEach(options) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .disabled(!buttons.isEnabled)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? color.opacity(0.18) : .clear))
    }
}
