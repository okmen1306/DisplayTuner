//
//  ThresholdTracker.swift
//  DisplayTuner
//
//  Görev: Eşik bir kez, şarjda/+5'te sıfırlama.
//  Faz: 2  ·  Kararlar: D-71, D-72  (bkz. AGENT_BRIEF.md)
//

import Foundation

/// Pil eşiklerini izler. Her eşik bir kez tetiklenir (D-72).
struct ThresholdTracker: Sendable {
    struct Threshold: Sendable, Equatable {
        let percent: Int
        let isCritical: Bool
    }

    /// D-71 varsayılanları.
    static let headset = [Threshold(percent: 20, isCritical: false), Threshold(percent: 10, isCritical: false),
                          Threshold(percent: 5, isCritical: true), Threshold(percent: 3, isCritical: true)]
    static let mouse = [Threshold(percent: 25, isCritical: false), Threshold(percent: 0, isCritical: true)]

    // MARK: Kullanıcı ayarı (D-148)

    /// Seçilebilir eşikler. Mouse pili %25 adımla raporlar.
    static func options(for kind: DeviceKind) -> [Int] {
        kind == .mouse ? [75, 50, 25, 0] : [50, 40, 30, 20, 15, 10, 5, 3]
    }

    /// Kayıtlı eşikler; %5 ve altı kritik uyarıdır.
    static func saved(for kind: DeviceKind) -> [Threshold] {
        let fallback = (kind == .mouse ? mouse : headset).map(\.percent)
        let percents = UserDefaults.standard.array(forKey: "alerts.\(kind.rawValue)") as? [Int] ?? fallback
        return percents.map { Threshold(percent: $0, isCritical: $0 <= 5) }
    }

    static func save(_ percents: [Int], for kind: DeviceKind) {
        UserDefaults.standard.set(percents.sorted(by: >), forKey: "alerts.\(kind.rawValue)")
    }

    let thresholds: [Threshold]
    private(set) var fired: Set<Int> = []

    init(thresholds: [Threshold]) {
        self.thresholds = thresholds.sorted { $0.percent > $1.percent }
    }

    /// Yeni bir okuma; tetiklenmesi gereken eşiği döndürür. Aynı anda birden çok eşik aşıldıysa sadece en düşüğü.
    mutating func update(percent: Int, isCharging: Bool) -> Threshold? {
        // Sıfırlama: şarjda veya pil eşiğin 5 puan üstüne çıkınca (D-72).
        if isCharging {
            fired.removeAll()
            return nil
        }
        fired = fired.filter { percent < $0 + 5 }

        let crossed = thresholds.filter { percent <= $0.percent && !fired.contains($0.percent) }
        guard let lowest = crossed.last else { return nil }
        crossed.forEach { fired.insert($0.percent) }
        return lowest
    }
}
