//
//  HeadsetEQ.swift
//  DisplayTuner
//
//  Görev: Kulaklık EQ hazır ayarları (uygulama tarafında) + kullanıcı ayarları.
//  Kararlar: D-152  (bkz. AGENT_BRIEF.md)
//
//  Kulaklığın kendi hazır ayarları (00/07/08/09) değiştirilemez. Bu yüzden her hazır ayar
//  kulaklığın "Özel" (FF) eğrisine yazılır; böylece her ayar düzenlenebilir ve sıfırlanabilir.
//  Eğriler kulaklığın ölçülmüş tonuna göre kuruldu (RTINGS: parlak, bas zayıf ≈ -2 dB):
//  "Dengeli" önce bunu düzeltir, diğerleri onun üstüne kurulur. Donanım aralığı -9…+6 dB.
//

import Foundation
import os

struct EQPreset: Codable, Hashable, Identifiable, Sendable {
    enum Category: String, Codable, CaseIterable, Sendable {
        case general, gaming, music, media, user
        var title: String {
            switch self {
            case .general: String(localized: "Genel")
            case .gaming: String(localized: "Oyun")
            case .music: String(localized: "Müzik")
            case .media: String(localized: "Film ve Konuşma")
            case .user: String(localized: "Benim Ayarlarım")
            }
        }
    }

    let id: String
    var name: String
    var detail: String
    var symbol: String
    var category: Category
    var bands: [Int]

    var isUser: Bool { category == .user }
}

extension EQPreset {
    static let frequencies = ["31", "63", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
    static let range = -9...6
    static let flatBands = [Int](repeating: 0, count: 10)

    //                                         31  63 125 250 500  1K  2K  4K  8K 16K
    static var builtIn: [EQPreset] {[
        .init(id: "flat", name: String(localized: "Düz"), detail: String(localized: "Kulaklığın kendi sesi, hiçbir değişiklik yok."),
              symbol: "line.diagonal", category: .general, bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        .init(id: "balanced", name: String(localized: "Dengeli"), detail: String(localized: "Referans ton: zayıf basları tamamlar, sert üst ortaları yumuşatır."),
              symbol: "dial.medium.fill", category: .general, bands: [4, 4, 3, 1, 0, 0, -1, -2, 1, 2]),
        .init(id: "night", name: String(localized: "Gece"), detail: String(localized: "Kısık seste bas ve tizler kaybolmasın diye (loudness)."),
              symbol: "moon.stars.fill", category: .general, bands: [6, 5, 3, 1, 0, -1, -1, 0, 2, 3]),

        .init(id: "fps", name: String(localized: "Ayak Sesi"), detail: String(localized: "FPS: 2–4 kHz öne çıkar, patlama uğultusu azalır."),
              symbol: "figure.walk", category: .gaming, bands: [-3, -2, -1, -2, -1, 1, 3, 5, 2, 0]),
        .init(id: "battleRoyale", name: String(localized: "Uzak Sesler"), detail: String(localized: "Geniş haritalar: uzaktaki adım ve silah yönleri daha net."),
              symbol: "scope", category: .gaming, bands: [-4, -3, -2, -2, 0, 2, 4, 5, 3, 1]),
        .init(id: "immersive", name: String(localized: "Sinematik Oyun"), detail: String(localized: "Hikâye oyunları: dolgun bas, net diyalog, geniş tizler."),
              symbol: "sparkles", category: .gaming, bands: [5, 4, 2, 0, -1, 0, 1, 1, 2, 3]),

        .init(id: "pop", name: String(localized: "Pop"), detail: String(localized: "Hafif V: canlı vokal, tok bas, parlak üst."),
              symbol: "music.mic", category: .music, bands: [4, 4, 2, 0, -1, 0, 1, 1, 2, 3]),
        .init(id: "electronic", name: String(localized: "Elektronik"), detail: String(localized: "Derin alt bas ve hava; orta bölge geri planda."),
              symbol: "waveform", category: .music, bands: [6, 6, 3, 0, -2, -1, 0, 1, 3, 4]),
        .init(id: "hiphop", name: String(localized: "Hip-Hop"), detail: String(localized: "Güçlü 808 bas, temiz vokal."),
              symbol: "hifispeaker.fill", category: .music, bands: [6, 6, 4, 1, -1, -1, 1, 0, 1, 2]),
        .init(id: "rock", name: String(localized: "Rock"), detail: String(localized: "Gitar gövdesi ve davul vuruşu öne çıkar."),
              symbol: "guitars.fill", category: .music, bands: [4, 3, 2, 0, -1, 0, 2, 2, 2, 2]),
        .init(id: "acoustic", name: String(localized: "Akustik"), detail: String(localized: "Doğal enstrüman tınısı, sıcak orta bölge."),
              symbol: "music.quarternote.3", category: .music, bands: [3, 3, 2, 2, 1, 0, 0, -1, 1, 2]),
        .init(id: "bassBoost", name: String(localized: "Bas Güçlendirme"), detail: String(localized: "Maksimum bas; vokaller korunur."),
              symbol: "speaker.wave.3.fill", category: .music, bands: [6, 6, 5, 2, 0, 0, -1, -1, 0, 1]),

        .init(id: "movie", name: String(localized: "Film"), detail: String(localized: "Patlamalar dolgun, konuşmalar net."),
              symbol: "film.fill", category: .media, bands: [6, 5, 3, 0, -1, 1, 2, 1, 1, 1]),
        .init(id: "voice", name: String(localized: "Konuşma"), detail: String(localized: "Podcast ve toplantı: vokal netliği, bas uğultusu yok."),
              symbol: "person.wave.2.fill", category: .media, bands: [-5, -4, -2, 0, 2, 3, 4, 2, 0, -2]),
    ]}
}

@MainActor
@Observable
final class HeadsetEQStore {
    private(set) var userPresets: [EQPreset] = []
    private(set) var selectedID: String?

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.muhammed.DisplayTuner", category: "EQ")

    init() {
        if let data = defaults.data(forKey: "eq.userPresets"), let list = try? JSONDecoder().decode([EQPreset].self, from: data) {
            userPresets = list
        }
        selectedID = defaults.string(forKey: "eq.selected")
    }

    var all: [EQPreset] { EQPreset.builtIn + userPresets }
    var selected: EQPreset? { all.first { $0.id == selectedID } }

    /// Kulaklıktaki eğri bilinen bir ayara eşitse onu seçili say (kulaklık başka yerden değiştiyse).
    func adopt(bands: [Int]) {
        if let selected, selected.bands == bands { return }
        if let match = all.first(where: { $0.bands == bands }) { select(match.id) }
    }

    func select(_ id: String?) {
        selectedID = id
        defaults.set(id, forKey: "eq.selected")
    }

    /// Kulaklığa yazar: önce "Özel" moda alır, sonra eğriyi yazar (D-152).
    @discardableResult
    func apply(_ bands: [Int], to headset: BlackSharkV2HS) async -> Bool {
        let clamped = bands.map { min(max($0, EQPreset.range.lowerBound), EQPreset.range.upperBound) }
        if await headset.readByte(.eqPreset) != RazerEQPreset.custom.rawValue {
            await headset.write(.eqPreset, [RazerEQPreset.custom.rawValue])
        }
        let ok = await headset.setEQBands(clamped)
        if !ok { logger.error("EQ yazılamadı") }
        return ok
    }

    func saveUserPreset(name: String, bands: [Int]) -> EQPreset {
        let preset = EQPreset(id: "user-\(UUID().uuidString)", name: name, detail: String(localized: "Kendi ayarın"),
                              symbol: "slider.horizontal.3", category: .user, bands: bands)
        userPresets.append(preset)
        persist()
        select(preset.id)
        return preset
    }

    func updateUserPreset(_ id: String, bands: [Int]) {
        guard let index = userPresets.firstIndex(where: { $0.id == id }) else { return }
        userPresets[index].bands = bands
        persist()
    }

    func deleteUserPreset(_ id: String) {
        userPresets.removeAll { $0.id == id }
        if selectedID == id { select(nil) }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(userPresets) { defaults.set(data, forKey: "eq.userPresets") }
    }

    /// ⌃⌥E kısayolunun döndüğü sıra.
    static let hotkeyCycle = ["balanced", "fps", "pop", "movie", "flat"]
}
