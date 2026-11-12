//
//  LUTMath.swift
//  DisplayTuner
//
//  Görev: Gamma tablosu hesapları (saf fonksiyonlar, testli).
//  Faz: 5  ·  Kararlar: 10.5, D-35  (bkz. AGENT_BRIEF.md)
//

import Foundation

/// LUT hattı ayarları. Hepsi 0 → kimlik tablosu; `quantization` 1 → kapalı.
struct ColorAdjustments: Codable, Equatable, Sendable {
    var contrast: Double = 0        // -1…1
    var gamma: Double = 0           // -1…1
    var gain: Double = 0            // -1…1
    var redGain: Double = 0, greenGain: Double = 0, blueGain: Double = 0
    var redGamma: Double = 0, greenGamma: Double = 0, blueGamma: Double = 0
    var highlights: Double = 0      // -1…1
    var shadows: Double = 0         // -1…1
    var temperature: Double = 0     // -1 (soğuk, kırmızı azalır) … 1 (sıcak, mavi azalır)
    var quantization: Double = 1    // 0…1, 1 = kapalı

    static let identity = ColorAdjustments()
}

enum LUTMath {
    struct Table: Equatable, Sendable {
        var red: [Float], green: [Float], blue: [Float]
        var count: Int { red.count }
    }

    /// 10.5'teki sırayla: kazanç → kontrast → gama → parlak alan/gölge → sıcaklık → kuantizasyon. Clamp yok (D-35).
    static func table(_ a: ColorAdjustments, size: Int) -> Table {
        let temp = (r: min(a.temperature, 0) + 1, g: 1 - abs(0.5 * a.temperature), b: 1 - max(a.temperature, 0))
        func channel(gain cGain: Double, gamma cGamma: Double, temperature t: Double) -> [Float] {
            (0..<size).map { i in
                var x = Double(i) / Double(size - 1)
                x *= 1 + a.gain + cGain
                x = (x - 0.5) * (1 + a.contrast) + 0.5
                x = power(x, gamma: a.gamma)
                x = power(x, gamma: cGamma)
                if x < 0.5 { x += a.shadows * x * (1 - 2 * x) } else { x += a.highlights * (1 - x) * (2 * x - 1) }
                x *= t
                x = quantize(x, a.quantization)
                return Float(x)
            }
        }
        return Table(red: channel(gain: a.redGain, gamma: a.redGamma, temperature: temp.r),
                     green: channel(gain: a.greenGain, gamma: a.greenGamma, temperature: temp.g),
                     blue: channel(gain: a.blueGain, gamma: a.blueGamma, temperature: temp.b))
    }

    /// `x ^ (1 / max(g + 1, 0.01))`; negatif girdide işaret korunur.
    static func power(_ x: Double, gamma g: Double) -> Double {
        guard g != 0 else { return x }
        let exponent = 1 / max(g + 1, 0.01)
        return x < 0 ? -pow(-x, exponent) : pow(x, exponent)
    }

    /// Seviye `L = floor(254 q³) + 2`; q = 1 → kapalı.
    static func quantize(_ x: Double, _ q: Double) -> Double {
        guard q < 1 else { return x }
        let levels = floor(254 * pow(max(q, 0), 3)) + 2
        return (x * (levels - 1)).rounded() / (levels - 1)
    }

    static func maxDeviation(_ a: Table, _ b: Table) -> Float {
        guard a.count == b.count else { return .infinity }
        return zip(zip(a.red, a.green), zip(zip(b.red, b.green), zip(a.blue, b.blue)))
            .map { max(abs($0.0 - $1.0.0), abs($0.1 - $1.0.1), abs($1.1.0 - $1.1.1)) }
            .max() ?? 0
    }

    /// macOS uygulanan tabloyu geri okurken [0,1] dışını kırpabiliyor; sapma kontrolü kırpılmış değerlerle yapılır (D-128).
    static func clamped(_ t: Table) -> Table {
        let c: ([Float]) -> [Float] = { $0.map { min(max($0, 0), 1) } }
        return Table(red: c(t.red), green: c(t.green), blue: c(t.blue))
    }
}
