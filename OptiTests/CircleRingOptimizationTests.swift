import AppKit
import Foundation
import Testing
@testable import Opti

struct CircleRingOptimizationTests {
    @Test func websiteSlotsPreserveEmptyDeletedAndInvalidEntries() {
        let first = Website(url: "https://first.example")
        let last = Website(url: "https://last.example")
        let invalid = Website(url: "relative-path")
        let slots = CircleRingWebsiteSlot.resolve(
            configuredIDs: [first.id.uuidString, "", "invalid-id", UUID().uuidString,
                            invalid.id.uuidString, last.id.uuidString],
            sectorCount: 8, websites: [last, invalid, first]
        )
        #expect(slots.map(\.index) == Array(0..<8))
        #expect(slots[0].website == first)
        #expect(slots[5].website == last)
        #expect(slots[5].url == URL(string: last.url))
        for index in [1, 2, 3, 4, 6, 7] {
            #expect(slots[index].website == nil && slots[index].url == nil)
        }
        #expect(CircleRingWebsiteSlot.resolve(configuredIDs: [], sectorCount: 4, websites: []).count == 4)
        #expect(CircleRingWebsiteSlot.resolve(configuredIDs: [], sectorCount: 0, websites: []).isEmpty)
    }

    @Test @MainActor func applicationInfoReusesLookupsAndRefreshesAfterExpiry() {
        var now = Date()
        var path = URL(fileURLWithPath: "/Applications/First.app")
        var lookups = 0
        var iconLoads = 0
        let cache = ApplicationInfoCache(applicationURL: { _ in lookups += 1; return path },
                                         applicationIcon: { _ in iconLoads += 1; return NSImage() }, now: { now })
        for _ in 0..<100 { #expect(cache.info(for: "app.one")?.url == path) }
        #expect(lookups == 1 && iconLoads == 1)
        now.addTimeInterval(61)
        path = URL(fileURLWithPath: "/Applications/Moved.app")
        #expect(cache.info(for: "app.one")?.name == "Moved")
        #expect(lookups == 2 && iconLoads == 2)
        cache.retain(bundleIDs: ["app.two"])
        _ = cache.info(for: "app.one")
        #expect(lookups == 3)
    }

    @Test @MainActor func missingApplicationsAreRetriedWithoutRepeatedIconLoads() {
        var now = Date()
        var installed = false
        var lookups = 0
        var iconLoads = 0
        let cache = ApplicationInfoCache(applicationURL: { _ in
            lookups += 1
            return installed ? URL(fileURLWithPath: "/Applications/New.app") : nil
        }, applicationIcon: { _ in iconLoads += 1; return NSImage() }, now: { now })
        for _ in 0..<20 { #expect(cache.info(for: "app.new") == nil) }
        #expect(lookups == 1 && iconLoads == 0)
        installed = true
        now.addTimeInterval(6)
        #expect(cache.info(for: "app.new")?.name == "New")
        #expect(lookups == 2 && iconLoads == 1)
    }
}

private final class IconProbe: @unchecked Sendable {
    enum Mode { case success, fallback, failure, hold }
    private let lock = NSLock()
    private var urls: [URL] = []
    private var stopped = 0
    let mode: Mode
    init(_ mode: Mode) { self.mode = mode }
    func started(_ url: URL) { lock.withLock { urls.append(url) } }
    func stop() { lock.withLock { stopped += 1 } }
    var requestCount: Int { lock.withLock { urls.count } }
    var stopCount: Int { lock.withLock { stopped } }
}

private final class IconURLProtocol: URLProtocol, @unchecked Sendable {
    static var probe = IconProbe(.success)
    private var ownProbe: IconProbe?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let probe = Self.probe
        ownProbe = probe
        let url = request.url!
        probe.started(url)
        if probe.mode == .hold { return }
        let success = probe.mode == .success || (probe.mode == .fallback && url.host == "www.google.com")
        let response = HTTPURLResponse(url: url, statusCode: success ? 200 : 500,
                                       httpVersion: nil, headerFields: ["Content-Type": "image/png"])!
        // 错误响应也包含可解码的图片，验证只接受成功状态码。
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==")!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: png)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { ownProbe?.stop() }
}

@Suite(.serialized)
@MainActor
struct WebIconLoadingTests {
    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [IconURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<200 {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(predicate(), "图标加载应在两秒内完成")
    }

    @Test func duplicateLoadsShareRequestAndReuseDiskCache() async throws {
        IconURLProtocol.probe = IconProbe(.success)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = session()
        defer { session.invalidateAndCancel() }
        let manager = WebIconManager(cacheDirectory: directory, session: session)
        let website = Website(url: "https://dedup.example")
        var completions = 0
        for _ in 0..<2 {
            manager.loadIcon(for: website) { icon in
                #expect(icon != nil)
                completions += 1
            }
        }
        await waitUntil { completions == 2 }
        #expect(IconURLProtocol.probe.requestCount == 1)
        #expect(manager.icon(for: website) != nil)
        manager.loadIcon(for: website) { _ in completions += 1 }
        #expect(completions == 3)
        #expect(await manager.getCacheSize() > 0)

        let reloaded = WebIconManager(cacheDirectory: directory, session: session)
        reloaded.loadIcon(for: website) { icon in
            #expect(icon != nil)
            completions += 1
        }
        await waitUntil { completions == 4 }
        #expect(IconURLProtocol.probe.requestCount == 1)
    }

    @Test func failedOriginUsesFallbackAndFailuresHaveCooldown() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = session()
        defer { session.invalidateAndCancel() }
        let manager = WebIconManager(cacheDirectory: directory, session: session)
        IconURLProtocol.probe = IconProbe(.fallback)
        let website = Website(url: "https://fallback.example")
        var completed = false
        manager.loadIcon(for: website) { icon in #expect(icon != nil); completed = true }
        await waitUntil { completed }
        #expect(IconURLProtocol.probe.requestCount == 2)
        _ = await manager.getCacheSize()

        IconURLProtocol.probe = IconProbe(.failure)
        let failed = Website(url: "https://failure.example")
        completed = false
        manager.loadIcon(for: failed) { icon in #expect(icon == nil); completed = true }
        await waitUntil { completed }
        var retryCallbacks = 0
        for _ in 0..<10 {
            manager.loadIcon(for: failed) { icon in #expect(icon == nil); retryCallbacks += 1 }
        }
        #expect(retryCallbacks == 10)
        #expect(IconURLProtocol.probe.requestCount == 2)
    }

    @Test func cancellationStopsNetworkAndAllowsFreshRequest() async {
        IconURLProtocol.probe = IconProbe(.hold)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = session()
        defer { session.invalidateAndCancel() }
        let manager = WebIconManager(cacheDirectory: directory, session: session)
        let website = Website(url: "https://cancel.example")
        var completions = 0
        manager.loadIcon(for: website) { icon in #expect(icon == nil); completions += 1 }
        await waitUntil { IconURLProtocol.probe.requestCount == 1 }
        let cancelledProbe = IconURLProtocol.probe
        manager.cancelLoading(for: website.id)
        await waitUntil { cancelledProbe.stopCount == 1 }
        #expect(completions == 1)
        #expect(manager.icon(for: website) == nil)

        IconURLProtocol.probe = IconProbe(.success)
        manager.loadIcon(for: website) { icon in #expect(icon != nil); completions += 1 }
        await waitUntil { completions == 2 }
        #expect(IconURLProtocol.probe.requestCount == 1)
        _ = await manager.getCacheSize()
    }

    @Test func clearingCacheCancelsActiveAndQueuedLoads() async {
        IconURLProtocol.probe = IconProbe(.hold)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = session()
        defer { session.invalidateAndCancel() }
        let manager = WebIconManager(cacheDirectory: directory, session: session)
        var completions = 0
        for index in 0..<6 {
            manager.loadIcon(for: Website(url: "https://queue\(index).example")) { icon in
                #expect(icon == nil)
                completions += 1
            }
        }
        await waitUntil { IconURLProtocol.probe.requestCount == 3 }
        manager.clearCache()
        await waitUntil { IconURLProtocol.probe.stopCount == 3 }
        #expect(completions == 6)
        #expect(IconURLProtocol.probe.requestCount == 3)
        #expect(manager.getCachedIconCount() == 0)
        #expect(await manager.getCacheSize() == 0)
    }

    @Test func changingURLCancelsOldRequestAndManualIconWins() async {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = session()
        defer { session.invalidateAndCancel() }
        let manager = WebIconManager(cacheDirectory: directory, session: session)
        let original = Website(url: "https://old.example")
        let updated = Website(id: original.id, url: "https://updated.example")
        IconURLProtocol.probe = IconProbe(.hold)
        let oldProbe = IconURLProtocol.probe
        var completions = 0
        manager.loadIcon(for: original) { icon in #expect(icon == nil); completions += 1 }
        await waitUntil { oldProbe.requestCount == 1 }
        IconURLProtocol.probe = IconProbe(.hold)
        let updatedProbe = IconURLProtocol.probe
        manager.loadIcon(for: updated) { icon in #expect(icon != nil); completions += 1 }
        await waitUntil { oldProbe.stopCount == 1 && updatedProbe.requestCount == 1 }
        let custom = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)!
        manager.setIcon(custom, for: updated)
        await waitUntil { updatedProbe.stopCount == 1 }
        #expect(completions == 2)
        #expect(manager.icon(for: original) == nil)
        #expect(manager.icon(for: updated) === custom)
        manager.clearCache()
        #expect(await manager.getCacheSize() == 0)
        #expect(manager.icon(for: updated) == nil)
    }
}
