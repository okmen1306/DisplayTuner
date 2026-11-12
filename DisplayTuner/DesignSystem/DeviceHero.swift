//
//  DeviceHero.swift
//  DisplayTuner
//
//  Görev: Cihaz sayfalarının üst kartı (büyük ikon, durum, pil) ve sayfa arka planı.
//  Kararlar: D-153  (bkz. AGENT_BRIEF.md)
//

import SwiftUI

struct DeviceHero: View {
    let title: String
    let subtitle: String
    var detail: String? = nil
    let symbol: String
    var tint: Color = .accentColor
    var percent: Int? = nil
    var isCharging = false
    var isStale = false
    var connected = true

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [tint.opacity(0.9), tint.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: tint.opacity(0.45), radius: 14, y: 6)
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 78, height: 78)
            .overlay {
                if percent != nil {
                    Circle()
                        .trim(from: 0, to: CGFloat(percent ?? 0) / 100)
                        .stroke(Theme.batteryColor(percent), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(-7)
                        .animation(Theme.spring, value: percent)
                }
            }
            .opacity(connected ? 1 : 0.45)

            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.title2.weight(.bold))
                HStack(spacing: 6) {
                    Circle().fill(connected ? Color.green : Color.secondary).frame(width: 7, height: 7)
                    Text(subtitle).font(.callout).foregroundStyle(.secondary)
                }
                if let detail {
                    Text(detail).font(.caption.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.quaternary.opacity(0.6), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let percent {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        if isCharging { Image(systemName: "bolt.fill").font(.title3).foregroundStyle(.green) }
                        Text(String(localized: "%\(percent)"))
                            .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                    }
                    Text(isStale ? String(localized: "Son bilinen") : String(localized: "Pil"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .opacity(isStale ? 0.6 : 1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.03)], startPoint: .top, endPoint: .bottom))
        }
    }
}

/// Form içinde kenarsız/arka plansız tam genişlik satır.
extension View {
    func heroRow() -> some View {
        self.listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
    }
}

/// Sayfa arka planı: üstte sayfanın renginde yumuşak bir ışıma.
struct PageBackground: View {
    let tint: Color
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(colors: [tint.opacity(0.22), .clear], center: .topTrailing, startRadius: 20, endRadius: 520)
            RadialGradient(colors: [tint.opacity(0.10), .clear], center: .bottomLeading, startRadius: 20, endRadius: 600)
        }
        .ignoresSafeArea()
    }
}
