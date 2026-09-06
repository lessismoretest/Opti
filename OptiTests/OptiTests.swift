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

    @Test func appSelectionFindsNestedChromeAppsWithoutBundledHelpers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let grokURL = directory.appendingPathComponent("Chrome Apps.localized/Grok.app")
        let hostURL = directory.appendingPathComponent("Browser.app")
        let fixtures: [(URL, String, String)] = [
            (grokURL, "test.chrome.grok", "Grok"),
            (hostURL, "test.browser", "Browser"),
            (hostURL.appendingPathComponent("Contents/Helpers/Helper.app"), "test.browser.helper", "Helper")
        ]
        for (appURL, bundleId, name) in fixtures {
            let contentsURL = appURL.appendingPathComponent("Contents")
            try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
            let info = ["CFBundleIdentifier": bundleId, "CFBundleName": name, "CFBundlePackageType": "APPL"]
            let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            try data.write(to: contentsURL.appendingPathComponent("Info.plist"))
        }

        let apps = AppSelectionView.scanInstalledApps(in: [directory, directory])
        let grok = try #require(apps.first { $0.bundleId == "test.chrome.grok" })
        #expect(grok.appURL.resolvingSymlinksInPath().path == grokURL.resolvingSymlinksInPath().path)
        #expect(grok.searchableText.contains("grok"))
        #expect(apps.filter { $0.bundleId == "test.chrome.grok" }.count == 1)
        #expect(apps.contains { $0.bundleId == "test.browser" })
        #expect(!apps.contains { $0.bundleId == "test.browser.helper" })
    }

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
