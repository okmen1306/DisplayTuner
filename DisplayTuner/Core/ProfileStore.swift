//
//  ProfileStore.swift
//  DisplayTuner
//
//  Görev: Profillerin JSON kaydı, yüklenmesi ve monitöre uygulanması.
//  Faz: 5  ·  Kararlar: D-38, D-100, 4  (bkz. AGENT_BRIEF.md)
//

import CoreGraphics
import Foundation
import os

@MainActor
@Observable
final class ProfileStore {
    private(set) var profiles: [DisplayProfile] = []
    let filter = CompositorFilter()

    /// D-34: doygunluk/canlılık/ton/sepya varsayılandan farklıysa overlay katmanı açılır.
    func applyFilter(_ profile: DisplayProfile) {
        let values = CompositorFilter.Values(saturation: profile.saturation, vibrance: profile.vibrance,
                                             hue: profile.hue, sepia: profile.sepia)
        filter.update(isColorManagementEnabled ? values : .init(), on: Self.monitorDisplayID)
    }
    var activeID: UUID? { didSet { save() } }

    /// R3: Kullanıcı onay verene kadar monitöre otomatik uygulama kapalı.
    var isColorManagementEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "colorManagementEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "colorManagementEnabled") }
    }

    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "Profiles")
    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DisplayTuner", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("profiles.json")
    }()

    private struct Stored: Codable { var profiles: [DisplayProfile]; var activeID: UUID? }

    var active: DisplayProfile? { profiles.first { $0.id == activeID } }

    /// Kayıt yoksa "Masa (Kayıtlı)" profili içe aktarılır ve varsayılan yapılır (D-38).
    func load() {
        if let data = try? Data(contentsOf: fileURL), let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            profiles = stored.profiles
            activeID = stored.activeID
        } else if var baseline = BaselineImporter.load() {
            baseline.resolution?.refreshRate = 60    // D-126: varsayılan 60 Hz
            profiles = [baseline]
            activeID = baseline.id
        }
    }

    // MARK: - Profil yönetimi

    /// Profili seçer ve tam uygular.
    func select(_ id: UUID) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        activeID = id
        Task { await apply(profile) }
    }

    /// Aktif profilin kopyası ("Gece" vb.); yeni profil aktif olur.
    func duplicateActive(named name: String) {
        guard var copy = active else { return }
        copy.id = UUID()
        copy.name = name
        profiles.append(copy)
        activeID = copy.id
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = profiles.firstIndex(where: { $0.id == id }), !name.isEmpty else { return }
        profiles[i].name = name
        save()
    }

    /// Son profil silinemez.
    func delete(_ id: UUID) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == id }
        if activeID == id, let first = profiles.first { select(first.id) } else { save() }
    }

    /// ⌃⌥1…4 kısayolları için sıra ile seçim.
    func select(index: Int) {
        guard profiles.indices.contains(index) else { return }
        select(profiles[index].id)
    }

    /// Aktif profili değiştirir, kaydeder ve LUT'u canlı uygular (Ekran sekmesi slider'ları).
    func updateActive(applyGamma: Bool = true, _ change: (inout DisplayProfile) -> Void) {
        guard let index = profiles.firstIndex(where: { $0.id == activeID }) else { return }
        change(&profiles[index])
        save()
        applyFilter(profiles[index])
        guard applyGamma, isColorManagementEnabled, let id = Self.monitorDisplayID else { return }
        GammaEngine.apply(profiles[index].lut(size: GammaEngine.capacity(of: id)), to: id)
    }

    /// Çözünürlük/ölçek + Hz seçimi profile kaydedilir; dock takılınca geri gelir (D-126).
    func setResolution(_ r: ModeService.Resolution, hz: Int) {
        guard let id = Self.monitorDisplayID, let applied = ModeService.set(r, hz: hz, on: id),
              let index = profiles.firstIndex(where: { $0.id == activeID }) else { return }
        profiles[index].resolution = .init(width: r.width, height: r.height, pixelWidth: r.pixelWidth, refreshRate: Double(applied))
        save()
    }

    /// Kullanıcının elle seçtiği Hz profile kaydedilir; dock takılınca bu değer geri gelir (D-126).
    func setRefreshRate(_ hz: Int) {
        guard let id = Self.monitorDisplayID, ModeService.setRefreshRate(hz, on: id),
              let index = profiles.firstIndex(where: { $0.id == activeID }) else { return }
        profiles[index].resolution?.refreshRate = Double(hz)
        save()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(Stored(profiles: profiles, activeID: activeID)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 4. bölümdeki sıra: bağlantı modu → gamma → DDC (preset önce, sonra kazançlar, sonra parlaklık/kontrast).
    /// `includeDDC == false`: sadece mod/çözünürlük/gamma (ColorGuard sapma düzeltmesi; DDC'yi her 10 sn'de yazmamak için).
    func apply(_ profile: DisplayProfile, includeDDC: Bool = true) async {
        guard isColorManagementEnabled else {
            logger.info("Renk yönetimi kapalı; profil uygulanmadı")
            return
        }
        if let id = Self.monitorDisplayID {
            if ArrangementService.monitorShouldBeMain { ArrangementService.makeMain(id) }   // D-41
            if let resolution = profile.resolution { Self.applyResolution(resolution, to: id) }
            // D-130: bu süreçteki CADisplay bayat olabilir (D-127); mod taze yardımcı süreçte değiştirilir.
            if includeDDC {
                _ = await ConnectionModeService.applyViaHelper(.init(colorMode: profile.colorMode, bitDepth: profile.bitDepth))
            }
            GammaEngine.apply(profile.lut(size: GammaEngine.capacity(of: id)), to: id)
        }
        applyFilter(profile)
        guard includeDDC else { return }
        let order: [DDCService.VCP] = [.colorPreset, .redGain, .greenGain, .blueGain, .blackLevelRed, .brightness, .contrast]
        for vcp in order {
            if let value = profile.ddc[vcp.rawValue] { await DDCService.shared.write(vcp, value: value) }
        }
        logger.info("Profil uygulandı: \(profile.name, privacy: .public)")
    }

    /// Kayıtlı çözünürlük ve Hz (ör. 2048×1152 HiDPI @ 120 Hz). Zaten aynıysa dokunulmaz.
    static func applyResolution(_ r: DisplayProfile.Resolution, to id: CGDirectDisplayID) {
        if let current = CGDisplayCopyDisplayMode(id), current.width == r.width, current.height == r.height,
           current.pixelWidth == r.pixelWidth, Int(current.refreshRate.rounded()) == Int(r.refreshRate.rounded()) { return }
        let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
        let modes = (CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode]) ?? []
        guard let target = modes.first(where: {
            $0.width == r.width && $0.height == r.height && $0.pixelWidth == r.pixelWidth
                && Int($0.refreshRate.rounded()) == Int(r.refreshRate.rounded())
        }) else { return }
        CGDisplaySetDisplayMode(id, target, nil)
        Logger(subsystem: "com.muhammed.DisplayTuner", category: "Profiles")
            .info("Çözünürlük: \(r.width)x\(r.height) @\(Int(r.refreshRate)) Hz")
    }

    /// Monitör tespiti CoreGraphics ile (CADisplay bayat olabilir, D-127). PR27R165QC: vendor 13924, model 9984.
    static var monitorDisplayID: CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &ids, &count) == .success else { return nil }
        return ids.prefix(Int(count)).first { CGDisplayVendorNumber($0) == 13924 && CGDisplayModelNumber($0) == 9984 }
    }
}
