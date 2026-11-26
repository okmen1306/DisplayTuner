//
//  BluetoothBattery.swift
//  DisplayTuner
//
//  Görev: Bağlı Bluetooth kulaklıkların pili (AirPods: sol / sağ / kutu; diğerleri: tek değer).
//  Kararlar: D-160  (bkz. AGENT_BRIEF.md)
//
//  macOS'un sistem raporundan (`system_profiler SPBluetoothDataType -json`) okunur: ek izin gerektirmez,
//  AirPods ve birçok Bluetooth kulaklık "device_batteryLevelLeft/Right/Case/Main" alanlarını verir.
//  Sadece varsayılan ses çıkışı Bluetooth iken, dakikada bir sorgulanır (~0,1 sn).
//

import Foundation
import os

@MainActor
@Observable
final class BluetoothBattery {
    struct Earbuds: Equatable {
        var name: String
        var left: Int?
        var right: Int?
        var caseLevel: Int?
        var main: Int?
        var hasPair: Bool { left != nil || right != nil }
        var lowest: Int? { [left, right, main].compactMap { $0 }.min() }
    }

    private(set) var earbuds: Earbuds?
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "BTBattery")
    private var loop: Task<Void, Never>?

    /// `isActive`: varsayılan çıkış Bluetooth mu (SystemEQ'dan).
    func start(isActive: @escaping @MainActor () -> (Bool, String?)) {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                let (active, name) = isActive()
                if active {
                    let result = await Self.query(preferredName: name)
                    self?.earbuds = result
                } else {
                    self?.earbuds = nil
                }
                try? await Task.sleep(for: .seconds(active ? 60 : 10))
            }
        }
    }

    func refreshNow(name: String?) async {
        earbuds = await Self.query(preferredName: name)
    }

    /// Sistem raporunu arka planda okur ve bağlı kulaklığı bulur.
    nonisolated static func query(preferredName: String?) async -> Earbuds? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
                p.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = FileHandle.nullDevice
                do { try p.run() } catch { continuation.resume(returning: nil); return }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                continuation.resume(returning: parse(data, preferredName: preferredName))
            }
        }
    }

    nonisolated static func parse(_ data: Data, preferredName: String?) -> Earbuds? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = root["SPBluetoothDataType"] as? [[String: Any]] else { return nil }
        var found: [Earbuds] = []
        for block in blocks {
            for (key, value) in block where key.contains("connected") && !key.contains("not") {
                guard let list = value as? [[String: Any]] else { continue }
                for entry in list {
                    for (name, raw) in entry {
                        guard let info = raw as? [String: Any] else { continue }
                        func level(_ k: String) -> Int? {
                            guard let s = info[k] as? String else { return nil }
                            return Int(s.filter(\.isNumber))
                        }
                        let e = Earbuds(name: name, left: level("device_batteryLevelLeft"), right: level("device_batteryLevelRight"),
                                        caseLevel: level("device_batteryLevelCase"), main: level("device_batteryLevelMain"))
                        let minor = (info["device_minorType"] as? String ?? "").lowercased()
                        let isAudio = minor.contains("head") || e.hasPair || e.caseLevel != nil
                        if isAudio, e.hasPair || e.main != nil { found.append(e) }
                    }
                }
            }
        }
        if let preferredName, let match = found.first(where: { $0.name == preferredName }) { return match }
        return found.first
    }
}
