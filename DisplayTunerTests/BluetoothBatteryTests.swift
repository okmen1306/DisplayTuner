//
//  BluetoothBatteryTests.swift
//  DisplayTunerTests
//
//  Kapsam: system_profiler çıktısından kulaklık pili (AirPods sol/sağ/kutu, tek değerli kulaklık).  (D-160)
//

import Foundation
import Testing
@testable import DisplayTuner

struct BluetoothBatteryTests {
    private let sample = """
    {"SPBluetoothDataType":[{"controller_properties":{},
      "device_connected":[
        {"Magic Keyboard":{"device_minorType":"Keyboard","device_batteryLevelMain":"70%"}},
        {"AirPods Pro":{"device_minorType":"Headphones","device_batteryLevelLeft":"85%","device_batteryLevelRight":"90%","device_batteryLevelCase":"40%"}},
        {"JBL Tune":{"device_minorType":"Headset","device_batteryLevelMain":"55%"}}
      ],
      "device_not_connected":[{"Old Buds":{"device_minorType":"Headphones","device_batteryLevelMain":"10%"}}]
    }]}
    """

    @Test func airPodsPairAndCase() throws {
        let e = try #require(BluetoothBattery.parse(Data(sample.utf8), preferredName: "AirPods Pro"))
        #expect(e.left == 85 && e.right == 90 && e.caseLevel == 40)
        #expect(e.hasPair)
        #expect(e.lowest == 85)
    }

    @Test func singleValueHeadset() throws {
        let e = try #require(BluetoothBattery.parse(Data(sample.utf8), preferredName: "JBL Tune"))
        #expect(e.main == 55 && !e.hasPair)
    }

    @Test func ignoresKeyboardsAndDisconnected() throws {
        let e = try #require(BluetoothBattery.parse(Data(sample.utf8), preferredName: "Old Buds"))
        #expect(e.name != "Old Buds" && e.name != "Magic Keyboard")
    }
}
