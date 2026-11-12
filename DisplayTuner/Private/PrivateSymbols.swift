//
//  PrivateSymbols.swift
//  DisplayTuner
//
//  Görev: dlsym/NSClassFromString yardımcıları, varlık kontrolü.
//  Faz: 1  ·  Kararlar: R8  (bkz. AGENT_BRIEF.md)
//

import Foundation

/// Private API sembollerine güvenli erişim. Sembol yoksa nil döner, uygulama çökmez (R8).
enum PrivateSymbols {
    static func loadFramework(_ path: String) {
        _ = dlopen(path, RTLD_NOW)
    }

    static func symbol(_ name: String) -> UnsafeMutableRawPointer? {
        dlsym(dlopen(nil, RTLD_NOW), name)
    }

    static func function<T>(_ name: String, as type: T.Type) -> T? {
        guard let pointer = symbol(name) else { return nil }
        return unsafeBitCast(pointer, to: type)
    }
}
