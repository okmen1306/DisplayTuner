//
//  EQCurveView.swift
//  DisplayTuner
//
//  Görev: Sürüklenebilir 10 bant EQ eğrisi (yumuşak eğri + degrade dolgu + tutamaklar).
//  Kararlar: D-152  (bkz. AGENT_BRIEF.md)
//
//  Eski dikey Slider'lar döndürüldüğü için dokunma alanları üst üste biniyordu (16K'nın takılması);
//  burada tek bir sürükleme hareketi en yakın bandı seçer.
//

import SwiftUI

struct EQCurveView: View {
    @Binding var bands: [Int]
    var range: ClosedRange<Int> = EQPreset.range
    var labels: [String] = EQPreset.frequencies
    var tint: Color = .accentColor
    /// Sürükleme bitince (yazma için).
    var onCommit: () -> Void = {}

    @State private var activeBand: Int?

    private let inset: CGFloat = 22

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    grid(size)
                    fill(size)
                    curve(size).stroke(
                        LinearGradient(colors: [tint.opacity(0.9), tint], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .shadow(color: tint.opacity(0.5), radius: 6)
                    handles(size)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let band = activeBand ?? nearestBand(g.startLocation.x, width: size.width)
                        if activeBand == nil {
                            activeBand = band
                        }
                        let value = valueFor(y: g.location.y, height: size.height)
                        if bands[band] != value {
                            bands[band] = value
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                        }
                    }
                    .onEnded { _ in
                        activeBand = nil
                        onCommit()
                    })
            }
            .frame(height: 190)
            GeometryReader { geo in
                ForEach(labels.indices, id: \.self) { i in
                    Text(labels[i])
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(activeBand == i ? tint : .secondary)
                        .fixedSize()
                        .position(x: x(i, geo.size.width), y: geo.size.height / 2)
                }
            }
            .frame(height: 14)
        }
        .animation(.spring(duration: 0.25), value: bands)
    }

    // MARK: Çizim

    private func x(_ i: Int, _ width: CGFloat) -> CGFloat {
        let step = (width - 2 * inset) / CGFloat(max(bands.count - 1, 1))
        return inset + CGFloat(i) * step
    }

    private func y(_ value: Int, _ height: CGFloat) -> CGFloat {
        let span = CGFloat(range.upperBound - range.lowerBound)
        let t = CGFloat(value - range.lowerBound) / span
        return (height - 16) * (1 - t) + 8
    }

    private func valueFor(y: CGFloat, height: CGFloat) -> Int {
        let t = 1 - (y - 8) / (height - 16)
        let raw = CGFloat(range.lowerBound) + t * CGFloat(range.upperBound - range.lowerBound)
        return min(max(Int(raw.rounded()), range.lowerBound), range.upperBound)
    }

    private func nearestBand(_ px: CGFloat, width: CGFloat) -> Int {
        bands.indices.min { abs(x($0, width) - px) < abs(x($1, width) - px) } ?? 0
    }

    private func points(_ size: CGSize) -> [CGPoint] {
        bands.indices.map { CGPoint(x: x($0, size.width), y: y(bands[$0], size.height)) }
    }

    /// Catmull-Rom → Bezier ile yumuşak eğri.
    private func curve(_ size: CGSize) -> Path {
        let p = points(size)
        var path = Path()
        guard let first = p.first else { return path }
        path.move(to: first)
        for i in 0..<(p.count - 1) {
            let p0 = p[max(i - 1, 0)], p1 = p[i], p2 = p[i + 1], p3 = p[min(i + 2, p.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    private func fill(_ size: CGSize) -> some View {
        let zero = y(0, size.height)
        var path = curve(size)
        let p = points(size)
        if let last = p.last, let first = p.first {
            path.addLine(to: CGPoint(x: last.x, y: zero))
            path.addLine(to: CGPoint(x: first.x, y: zero))
            path.closeSubpath()
        }
        return path.fill(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0.02)],
                                        startPoint: .top, endPoint: .bottom))
    }

    private func grid(_ size: CGSize) -> some View {
        Canvas { context, canvas in
            for db in stride(from: range.lowerBound, through: range.upperBound, by: 3) {
                let yy = y(db, canvas.height)
                var line = Path()
                line.move(to: CGPoint(x: 0, y: yy))
                line.addLine(to: CGPoint(x: canvas.width, y: yy))
                context.stroke(line, with: .color(.secondary.opacity(db == 0 ? 0.45 : 0.15)),
                               style: StrokeStyle(lineWidth: db == 0 ? 1 : 0.5, dash: db == 0 ? [] : [3, 3]))
                context.draw(Text(db > 0 ? "+\(db)" : "\(db)").font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.tertiary), at: CGPoint(x: 8, y: yy - 6), anchor: .leading)
            }
            for i in bands.indices {
                var line = Path()
                line.move(to: CGPoint(x: x(i, canvas.width), y: 4))
                line.addLine(to: CGPoint(x: x(i, canvas.width), y: canvas.height - 4))
                context.stroke(line, with: .color(.secondary.opacity(0.08)), lineWidth: 1)
            }
        }
    }

    private func handles(_ size: CGSize) -> some View {
        ForEach(bands.indices, id: \.self) { i in
            let active = activeBand == i
            ZStack {
                Circle().fill(.white).frame(width: active ? 16 : 11, height: active ? 16 : 11)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                Circle().fill(tint).frame(width: active ? 8 : 5, height: active ? 8 : 5)
                if active {
                    Text(bands[i] > 0 ? "+\(bands[i]) dB" : "\(bands[i]) dB")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())
                        .offset(y: -22)
                        .fixedSize()
                }
            }
            .position(x: x(i, size.width), y: y(bands[i], size.height))
        }
    }
}

/// Hazır ayar kartlarında küçük eğri önizlemesi.
struct EQSparkline: View {
    let bands: [Int]
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let p = bands.indices.map { i in
                CGPoint(x: w * CGFloat(i) / CGFloat(max(bands.count - 1, 1)),
                        y: h * (1 - CGFloat(bands[i] - EQPreset.range.lowerBound) / CGFloat(EQPreset.range.count - 1)))
            }
            Path { path in
                guard let first = p.first else { return }
                path.move(to: first)
                for i in 0..<(p.count - 1) {
                    let p0 = p[max(i - 1, 0)], p1 = p[i], p2 = p[i + 1], p3 = p[min(i + 2, p.count - 1)]
                    path.addCurve(to: p2, control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                                  control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }
}
