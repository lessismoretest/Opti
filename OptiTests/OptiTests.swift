//
//  OptiTests.swift
//  OptiTests
//
//  Created by Less is more on 2025/1/15.
//

import Foundation
import Testing
@testable import Opti

struct OptiTests {

    @Test func circleRingPreservesConfiguredSlotsWhenAppsBecomeUnavailable() {
        let configuredBundleIdentifiers = [
            "com.electron.lark",
            "com.bot.pc.doubao",
            "com.anthropic.claudefordesktop",
            "com.google.GeminiMacOS",
            "com.openai.chat",
            "com.apple.finder",
            "com.google.Chrome",
            "ai.opencode.desktop",
            "com.openai.atlas",
            "com.openai.codex",
            "com.apple.AppStore",
            "com.apple.systempreferences"
        ]
        let unavailableBundleIdentifiers: Set<String> = ["com.openai.chat", "com.openai.atlas"]
        let slots = CircleRingAppSlot.resolve(
            configuredBundleIdentifiers: configuredBundleIdentifiers,
            sectorCount: 12,
            applicationURL: { bundleIdentifier in
                unavailableBundleIdentifiers.contains(bundleIdentifier)
                    ? nil
                    : URL(fileURLWithPath: "/Applications/\(bundleIdentifier).app")
            }
        )

        #expect(slots.count == 12)
        #expect(slots[4].bundleId == "com.openai.chat")
        #expect(slots[4].state == .unavailable)
        #expect(slots[6].bundleId == "com.google.Chrome")
        #expect(slots[8].bundleId == "com.openai.atlas")
        #expect(slots[8].state == .unavailable)
        #expect(slots[10].bundleId == "com.apple.AppStore")
        #expect(slots[11].bundleId == "com.apple.systempreferences")
    }

    @Test func circleRingKeepsUnconfiguredSectorsInPlace() {
        let slots = CircleRingAppSlot.resolve(
            configuredBundleIdentifiers: ["app.one", "", "app.three"],
            sectorCount: 4,
            applicationURL: { URL(fileURLWithPath: "/Applications/\($0).app") }
        )

        #expect(slots.count == 4)
        #expect(slots[0].bundleId == "app.one")
        #expect(slots[1].state == .unconfigured)
        #expect(slots[2].bundleId == "app.three")
        #expect(slots[3].state == .unconfigured)
    }

}
