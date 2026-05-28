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

    @Test(arguments: Array(4...12))
    func circleRingSelectionMatchesClockwiseIconPositions(sectorCount: Int) {
        // 包括副屏上的负坐标，避免把屏幕原点当成圆心。
        let center = CGPoint(x: -900, y: 450)
        let angleSlice = 2 * CGFloat.pi / CGFloat(sectorCount)
        for index in 0..<sectorCount {
            let angle = .pi / 2 - angleSlice * (CGFloat(index) + 0.5)
            let point = CGPoint(x: center.x + 85 * cos(angle), y: center.y + 85 * sin(angle))
            #expect(CircleRingSelection.index(
                at: point, center: center, innerRadius: 30, outerRadius: 140,
                sectorCount: sectorCount
            ) == index)
        }
    }

    @Test func circleRingSelectionRejectsCenterAndOutsideRing() {
        for point in [CGPoint.zero, CGPoint(x: 29, y: 0), CGPoint(x: 141, y: 0)] {
            #expect(CircleRingSelection.index(
                at: point, center: .zero, innerRadius: 30, outerRadius: 140,
                sectorCount: 6
            ) == nil)
        }
        for radius in [30.0, 140.0] {
            #expect(CircleRingSelection.index(
                at: CGPoint(x: radius, y: 0), center: .zero, innerRadius: 30, outerRadius: 140,
                sectorCount: 4
            ) == 1)
        }
        #expect(CircleRingSelection.index(
            at: CGPoint(x: 85, y: 0), center: .zero, innerRadius: 30, outerRadius: 140,
            sectorCount: 0
        ) == nil)
    }

    @Test func circleRingSelectionKeepsScreenEdgeTolerance() {
        for radius in [28.0, 150.0] {
            let point = CGPoint(x: radius, y: 0)
            #expect(CircleRingSelection.index(
                at: point, center: .zero, innerRadius: 30, outerRadius: 140,
                sectorCount: 4
            ) == nil)
            #expect(CircleRingSelection.index(
                at: point, center: .zero, innerRadius: 30, outerRadius: 140,
                sectorCount: 4, isNearScreenEdge: true
            ) == 1)
        }
    }

    @Test func circleRingSelectionWrapsAtTopBoundary() {
        #expect(CircleRingSelection.index(
            at: CGPoint(x: -0.001, y: 85), center: .zero, innerRadius: 30, outerRadius: 140,
            sectorCount: 12
        ) == 11)
        #expect(CircleRingSelection.index(
            at: CGPoint(x: 0.001, y: 85), center: .zero, innerRadius: 30, outerRadius: 140,
            sectorCount: 12
        ) == 0)
    }

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

    @Test(arguments: [4, 8, 12], [[], [""], ["", "", "", ""]])
    func circleRingLeavesEverySectorUnconfiguredWhenNoAppsAreSelected(
        sectorCount: Int,
        configuredBundleIdentifiers: [String]
    ) {
        var lookedUpBundleIdentifiers: [String] = []
        let slots = CircleRingAppSlot.resolve(
            configuredBundleIdentifiers: configuredBundleIdentifiers,
            sectorCount: sectorCount,
            applicationURL: { bundleIdentifier in
                lookedUpBundleIdentifiers.append(bundleIdentifier)
                return URL(fileURLWithPath: "/Applications/\(bundleIdentifier).app")
            }
        )

        #expect(slots.count == sectorCount)
        #expect(slots.map(\.index) == Array(0..<sectorCount))
        #expect(slots.allSatisfy { $0.state == .unconfigured && $0.bundleId.isEmpty && $0.url == nil })
        #expect(lookedUpBundleIdentifiers.isEmpty)
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
