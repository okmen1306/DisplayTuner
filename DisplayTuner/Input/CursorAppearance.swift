//
//  CursorAppearance.swift
//  DisplayTuner
//
//  Görev: İmleç şekli ve rengi (dolgu/kenar). Sistem ok imleci özel görüntüyle değiştirilir.
//  Faz: 4  ·  Kararlar: D-53, D-146  (bkz. AGENT_BRIEF.md)
//

import AppKit
import os

@MainActor
@Observable
final class CursorAppearance {
    enum Shape: String, CaseIterable, Identifiable {
        case system, arrow, boldArrow, dot
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: String(localized: "Sistem")
            case .arrow: String(localized: "Ok")
            case .boldArrow: String(localized: "Kalın ok")
            case .dot: String(localized: "Nokta")
            }
        }
    }

    static let cursorNames = ["com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowCtx"]
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Cursor")

    var shape: Shape { didSet { save(); apply() } }
    var fill: NSColor { didSet { save(); apply() } }
    var outline: NSColor { didSet { save(); apply() } }

    var isAvailable: Bool { CGSPrivate.canCustomizeCursor }

    init() {
        shape = Shape(rawValue: UserDefaults.standard.string(forKey: "cursorShape") ?? "") ?? .system
        fill = Self.color(UserDefaults.standard.string(forKey: "cursorFill")) ?? .black
        outline = Self.color(UserDefaults.standard.string(forKey: "cursorOutline")) ?? .white
    }

    func reset() {
        shape = .system
        fill = .black
        outline = .white
    }

    func apply() {
        guard isAvailable else { return }
        guard shape != .system else {
            Self.cursorNames.forEach(CGSPrivate.removeCursor)
            return
        }
        let points: CGFloat = 32
        guard let image = render(points: points, scale: 2) else { return }
        let hotspot = shape == .dot ? CGPoint(x: points / 2, y: points / 2) : CGPoint(x: 5, y: 3)
        for name in Self.cursorNames {
            let ok = CGSPrivate.registerCursor(name, image: image, size: CGSize(width: points, height: points), hotspot: hotspot)
            logger.info("İmleç \(name, privacy: .public): \(ok)")
        }
    }

    /// 2x çözünürlükte çizilmiş imleç görüntüsü (y aşağı doğru, sol üst = hotspot tarafı).
    private func render(points: CGFloat, scale: CGFloat) -> CGImage? {
        let px = Int(points * scale)
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: 0, y: points)
        ctx.scaleBy(x: 1, y: -1)               // üstten aşağı koordinat
        let path = CGMutablePath()
        switch shape {
        case .dot:
            path.addEllipse(in: CGRect(x: points / 2 - 6, y: points / 2 - 6, width: 12, height: 12))
        case .arrow, .boldArrow, .system:
            let s: CGFloat = shape == .boldArrow ? 1.25 : 1
            let pts: [CGPoint] = [(0, 0), (0, 17), (4.2, 13.2), (7, 19.6), (9.6, 18.5), (6.9, 12.2), (12.4, 12.2)]
                .map { CGPoint(x: 5 + $0.0 * s, y: 3 + $0.1 * s) }
            path.addLines(between: pts)
            path.closeSubpath()
        }
        ctx.addPath(path)
        ctx.setFillColor(fill.cgColor)
        ctx.setStrokeColor(outline.cgColor)
        ctx.setLineWidth(shape == .boldArrow ? 2.2 : 1.4)
        ctx.setLineJoin(.round)
        ctx.drawPath(using: .fillStroke)
        return ctx.makeImage()
    }

    private func save() {
        defaults.set(shape.rawValue, forKey: "cursorShape")
        defaults.set(Self.hex(fill), forKey: "cursorFill")
        defaults.set(Self.hex(outline), forKey: "cursorOutline")
    }

    private static func hex(_ c: NSColor) -> String {
        let c = c.usingColorSpace(.sRGB) ?? c
        return String(format: "%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }

    private static func color(_ hex: String?) -> NSColor? {
        guard let hex, hex.count == 6, let v = Int(hex, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}
