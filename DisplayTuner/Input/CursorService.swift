//
//  CursorService.swift
//  DisplayTuner
//
//  Görev: İmleç boyutu (CGSSetCursorScale).
//  Faz: 4  ·  Kararlar: D-53  (bkz. AGENT_BRIEF.md)
//

import Foundation

@MainActor
@Observable
final class CursorService {
    /// 1…4. Açılışta yeniden uygulanır (kalıcı değil).
    var scale: Double {
        didSet {
            UserDefaults.standard.set(scale, forKey: "cursorScale")
            CGSPrivate.setCursorScale(Float(scale))
        }
    }

    init() {
        scale = UserDefaults.standard.object(forKey: "cursorScale") as? Double ?? Double(CGSPrivate.cursorScale() ?? 1)
    }

    func applySaved() {
        if UserDefaults.standard.object(forKey: "cursorScale") != nil { CGSPrivate.setCursorScale(Float(scale)) }
    }
}
