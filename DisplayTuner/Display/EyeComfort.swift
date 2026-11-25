//
//  EyeComfort.swift
//  DisplayTuner
//
//  Görev: Göz konforu (gece) modu: mavi ışığı azaltan sıcak ton; ekran başına, elle / gün batımı / zamanlama.
//  Kararlar: D-157  (bkz. AGENT_BRIEF.md)
//
//  Sıcak ton gamma tablosuna çarpan olarak eklenir (`GammaEngine.apply` her tabloyu bu çarpanla uygular).
//  Böylece monitördeki renk profiliyle (RGB Full + LUT) çakışmaz, ColorGuard da aynı beklenen tabloyu görür.
//  macOS Night Shift DisplayLink ekranında çalışmayabildiği için kendi yolumuzu kullanıyoruz.
//  Gün batımı/doğumu konum izni olmadan saat diliminden tahmin edilir.
//

import AppKit
import CoreGraphics
import os

@MainActor
@Observable
final class EyeComfort {
    enum Mode: String, CaseIterable, Identifiable {
        case off, on, sunset, schedule
        var id: String { rawValue }
        var title: String {
            switch self {
            case .off: String(localized: "Kapalı")
            case .on: String(localized: "Açık")
            case .sunset: String(localized: "Gün batımından gün doğumuna")
            case .schedule: String(localized: "Zamanlama")
            }
        }
    }

    // MARK: Ayarlar

    var mode: Mode { didSet { save(); evaluate() } }
    /// 0.1…1: ne kadar sıcak.
    var strength: Double { didSet { save(); applyNow() } }
    var builtinEnabled: Bool { didSet { save(); applyNow(force: true) } }
    var monitorEnabled: Bool { didSet { save(); applyNow(force: true) } }
    /// Gece başlangıç/bitiş (gece yarısından dakika).
    var scheduleStart: Int { didSet { save(); evaluate() } }
    var scheduleEnd: Int { didSet { save(); evaluate() } }

    /// 0 = kapalı, 1 = tam; yumuşak geçiş için ara değerler.
    private(set) var level: Double = 0
    var isActive: Bool { targetLevel > 0 }

    /// GammaEngine'in okuduğu ekran başına çarpan (r, g, b).
    nonisolated(unsafe) static var multipliers: [CGDirectDisplayID: (Double, Double, Double)] = [:]

    /// Ekranın değiştirilmemiş tablosu (renk yönetimi kapalıyken temel alınır).
    private var baselines: [CGDirectDisplayID: LUTMath.Table] = [:]
    private let store: ProfileStore
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "EyeComfort")
    private var ticker: Task<Void, Never>?
    private var fade: Task<Void, Never>?
    private var targetLevel: Double = 0

    init(store: ProfileStore) {
        self.store = store
        mode = Mode(rawValue: defaults.string(forKey: "eye.mode") ?? "") ?? .off
        strength = defaults.object(forKey: "eye.strength") as? Double ?? 0.6
        builtinEnabled = defaults.object(forKey: "eye.builtin") as? Bool ?? true
        monitorEnabled = defaults.object(forKey: "eye.monitor") as? Bool ?? true
        scheduleStart = defaults.object(forKey: "eye.start") as? Int ?? 22 * 60
        scheduleEnd = defaults.object(forKey: "eye.end") as? Int ?? 7 * 60
    }

    private func save() {
        defaults.set(mode.rawValue, forKey: "eye.mode")
        defaults.set(strength, forKey: "eye.strength")
        defaults.set(builtinEnabled, forKey: "eye.builtin")
        defaults.set(monitorEnabled, forKey: "eye.monitor")
        defaults.set(scheduleStart, forKey: "eye.start")
        defaults.set(scheduleEnd, forKey: "eye.end")
    }

    func start() {
        captureBaselines()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.captureBaselines()
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))   // ColorGuard'ın profili uygulamasından sonra
                    self?.applyNow(force: true)
                }
            }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            }
        }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.evaluate()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    /// Kısayol / popover: elle aç-kapa (zamanlamayı geçici olarak ezmez, modu değiştirir).
    func toggle() {
        mode = isActive ? .off : .on
    }

    // MARK: Zaman

    func shouldBeOn(at date: Date = .now) -> Bool {
        switch mode {
        case .off: return false
        case .on: return true
        case .schedule:
            return Self.inWindow(minutes: Self.minutes(of: date), start: scheduleStart, end: scheduleEnd)
        case .sunset:
            guard let (rise, set) = Self.sunTimes(on: date) else {
                return Self.inWindow(minutes: Self.minutes(of: date), start: 20 * 60, end: 7 * 60)
            }
            return date >= set || date < rise
        }
    }

    /// Bugünkü gün doğumu/batımı (arayüzde gösterilir).
    var todaySunTimes: (Date, Date)? { Self.sunTimes(on: .now) }

    private static func minutes(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private static func inWindow(minutes m: Int, start: Int, end: Int) -> Bool {
        start <= end ? (m >= start && m < end) : (m >= start || m < end)
    }

    /// Saat diliminden yaklaşık konum (izin gerektirmez).
    static var approximateLocation: (lat: Double, lon: Double) {
        let known: [String: (Double, Double)] = [
            "Europe/Istanbul": (41.01, 28.98), "Asia/Istanbul": (41.01, 28.98), "Europe/London": (51.5, -0.12),
            "Europe/Berlin": (52.52, 13.4), "Europe/Paris": (48.85, 2.35), "Europe/Amsterdam": (52.37, 4.9),
            "America/New_York": (40.71, -74.0), "America/Chicago": (41.88, -87.63), "America/Los_Angeles": (34.05, -118.24),
            "Asia/Tokyo": (35.68, 139.69), "Asia/Dubai": (25.2, 55.27), "Australia/Sydney": (-33.87, 151.21),
        ]
        let tz = TimeZone.current
        if let hit = known[tz.identifier] { return hit }
        let standardOffset = Double(tz.secondsFromGMT() - Int(tz.daylightSavingTimeOffset())) / 3600
        return (40, standardOffset * 15)
    }

    /// NOAA yaklaşımıyla gün doğumu/batımı (±birkaç dakika).
    static func sunTimes(on date: Date) -> (Date, Date)? {
        let (lat, lon) = approximateLocation
        let cal = Calendar.current
        guard let day = cal.ordinality(of: .day, in: .year, for: date) else { return nil }
        let rad = Double.pi / 180
        let gamma = 2 * Double.pi / 365 * Double(day - 1)
        let eqTime = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
                               - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let decl = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
        let cosH = (cos(90.833 * rad) / (cos(lat * rad) * cos(decl))) - tan(lat * rad) * tan(decl)
        guard cosH > -1, cosH < 1 else { return nil }
        let ha = acos(cosH) / rad
        let sunriseUTC = 720 - 4 * (lon + ha) - eqTime   // dakika
        let sunsetUTC = 720 - 4 * (lon - ha) - eqTime
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let ymd = cal.dateComponents([.year, .month, .day], from: date)
        guard let midnightUTC = utc.date(from: ymd) else { return nil }
        return (midnightUTC.addingTimeInterval(sunriseUTC * 60), midnightUTC.addingTimeInterval(sunsetUTC * 60))
    }

    // MARK: Uygulama

    func evaluate() {
        let target = shouldBeOn() ? 1.0 : 0.0
        guard target != targetLevel || level != target else { return }
        targetLevel = target
        fade?.cancel()
        fade = Task { [weak self] in
            // ~3 sn yumuşak geçiş
            for _ in 0..<30 {
                guard let self, !Task.isCancelled else { return }
                let step = (target - self.level)
                if abs(step) < 0.04 { self.level = target } else { self.level += step / 4 }
                self.applyNow()
                if self.level == target { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            self?.logger.info("Göz konforu \(target > 0 ? "açık" : "kapalı", privacy: .public)")
        }
    }

    /// Sıcak ton çarpanı. Tam güçte ≈ 3400 K (Night Shift'e yakın).
    static func warmth(_ amount: Double) -> (Double, Double, Double) {
        let a = min(max(amount, 0), 1)
        return (1, 1 - 0.20 * a, 1 - 0.45 * a)
    }

    func applyNow(force: Bool = false) {
        let amount = level * strength
        var targets: [CGDirectDisplayID] = []
        if let builtin = BuiltinBrightness.displayID { targets.append(builtin) }
        if let monitor = ProfileStore.monitorDisplayID { targets.append(monitor) }
        for id in targets {
            let enabled = CGDisplayIsBuiltin(id) != 0 ? builtinEnabled : monitorEnabled
            let mult = enabled ? Self.warmth(amount) : (1, 1, 1)
            let previous = Self.multipliers[id] ?? (1, 1, 1)
            if !force && previous == mult { continue }
            Self.multipliers[id] = mult
            if let base = baseTable(for: id) { GammaEngine.apply(base, to: id) }
        }
    }

    /// Renk yönetimi açık monitörde aktif profilin tablosu; diğerlerinde ekranın kendi tablosu.
    private func baseTable(for id: CGDirectDisplayID) -> LUTMath.Table? {
        if id == ProfileStore.monitorDisplayID, store.isColorManagementEnabled, let profile = store.active {
            return profile.lut(size: GammaEngine.capacity(of: id))
        }
        return baselines[id] ?? LUTMath.identity(size: GammaEngine.capacity(of: id))
    }

    /// Sıcak ton yokken ekranların tablosunu saklar (renk yönetimi kapalıyken geri dönülecek değer).
    private func captureBaselines() {
        for id in [BuiltinBrightness.displayID, ProfileStore.monitorDisplayID].compactMap({ $0 }) {
            let mult = Self.multipliers[id] ?? (1, 1, 1)
            guard mult == (1, 1, 1) || baselines[id] == nil, let table = GammaEngine.read(id) else { continue }
            if mult == (1, 1, 1) { baselines[id] = table }
            else {   // sıcak ton uygulanmışken okunduysa çarpanı geri al
                baselines[id] = LUTMath.Table(red: table.red.map { $0 / Float(mult.0) },
                                              green: table.green.map { $0 / Float(mult.1) },
                                              blue: table.blue.map { $0 / Float(mult.2) })
            }
        }
    }
}
