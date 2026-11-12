//
//  CABackdropLayerBridge.swift
//  DisplayTuner
//
//  Görev: CABackdropLayer oluşturma ve KVC anahtarları.
//  Faz: 5  ·  Kararlar: 10.4, R8  (bkz. AGENT_BRIEF.md)
//

import QuartzCore

enum CABackdropLayerBridge {
    static var isAvailable: Bool { NSClassFromString("CABackdropLayer") != nil }

    /// Arkasındaki ekran içeriğini filtreleyen katman (10.4'teki KVC anahtarları).
    static func make(scale: CGFloat) -> CALayer? {
        guard let type = NSClassFromString("CABackdropLayer") as? CALayer.Type else { return nil }
        let layer = type.init()
        let settings: [String: Any] = [
            "enabled": true, "windowServerAware": true, "allowsInPlaceFiltering": true, "ignoresScreenClip": true,
            "captureOnly": false, "reducesCaptureBitDepth": false, "disableFilterCache": true,
            "bleedAmount": 0.0, "marginWidth": 0.0, "scale": scale,
        ]
        for (key, value) in settings where layer.responds(to: NSSelectorFromString(key)) || true {
            layer.setValue(value, forKey: key)
        }
        return layer
    }
}
