//
//  IdentifierChangeTests.swift
//  IDFAVaultTests
//
//  前に見たときから IDFA が変わった端末を知らせる（IdentifierChangeTracker）。
//

import Foundation
@testable import IDFAVault
import Testing

struct IdentifierChangeTests {
    // swiftlint:disable force_unwrapping
    private static let first = AdvertisingIdentifier("6D92078A-8246-4BA4-AE5B-76104861E7DC")!
    private static let second = AdvertisingIdentifier("0F1E2D3C-4B5A-4978-8695-A4B3C2D1E0F9")!
    // swiftlint:enable force_unwrapping
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private static func makeDefaults() -> UserDefaults {
        .volatile(named: "tests.\(UUID().uuidString)")
    }

    // MARK: - IdentifierChangeTracker

    /// 初めて見た端末・同じ値は「変わった」にしない。違う値になったら「変わった」にする
    @Test
    func detectsOnlyActualChanges() {
        let tracker = IdentifierChangeTracker(defaults: Self.makeDefaults())

        tracker.observe(deviceID: "a", identifier: Self.first)
        tracker.observe(deviceID: "a", identifier: Self.first)
        #expect(!tracker.hasChanged(deviceID: "a"))

        tracker.observe(deviceID: "a", identifier: Self.second)
        #expect(tracker.hasChanged(deviceID: "a"))
    }

    /// 取得できない（許可を切った）あいだは前の値を残し、また取れたときに比べる
    @Test
    func keepsThePreviousValueWhileUnavailable() {
        let tracker = IdentifierChangeTracker(defaults: Self.makeDefaults())
        tracker.observe(deviceID: "a", identifier: Self.first)

        tracker.observe(deviceID: "a", identifier: nil)
        #expect(!tracker.hasChanged(deviceID: "a"))

        tracker.observe(deviceID: "a", identifier: Self.second)
        #expect(tracker.hasChanged(deviceID: "a"))
    }

    /// 確認済みにしたら消え、次に変わるまで出ない。忘れた端末は、次に見たときに初めて見た扱いにする
    @Test
    func acknowledgeAndForget() {
        let tracker = IdentifierChangeTracker(defaults: Self.makeDefaults())
        tracker.observe(deviceID: "a", identifier: Self.first)
        tracker.observe(deviceID: "a", identifier: Self.second)

        tracker.acknowledge(deviceID: "a")
        tracker.observe(deviceID: "a", identifier: Self.second)
        #expect(!tracker.hasChanged(deviceID: "a"))

        tracker.forget(deviceID: "a")
        tracker.observe(deviceID: "a", identifier: Self.first)
        #expect(!tracker.hasChanged(deviceID: "a"))
    }

    /// 起動し直しても覚えている。保存するのはハッシュで、IDFA そのものは残さない
    @Test
    func persistsOnlyHashes() throws {
        let defaults = Self.makeDefaults()
        IdentifierChangeTracker(defaults: defaults).observe(deviceID: "a", identifier: Self.first)

        let reloaded = IdentifierChangeTracker(defaults: defaults)
        reloaded.observe(deviceID: "a", identifier: Self.second)
        #expect(IdentifierChangeTracker(defaults: defaults).hasChanged(deviceID: "a"))

        let stored = try #require(defaults.dictionary(forKey: "identifierChange.lastSeen") as? [String: String])
        #expect(stored["a"]?.count == 64)
        #expect(!stored.values.contains(Self.second.value))
    }

    // MARK: - AppModel

    private func makeModel(defaults: UserDefaults, identifier: AdvertisingIdentifier, sync: StubDeviceSync) -> AppModel {
        AppModel(dependencies: AppDependencies(
            authenticator: StubAuthenticator(kind: .faceID, outcome: .success),
            tracking: StubTrackingProvider(status: .authorized, identifier: identifier),
            clipboard: NoopClipboard(),
            deviceInfo: StubDeviceInfo(deviceID: "this-device", platform: .iOS, name: "iPhone 16 Pro"),
            sync: sync,
            defaults: defaults,
            trackingPromptDelay: .zero,
            syncRefreshInterval: .seconds(3_600)
        ))
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
        }
    }

    /// この端末の IDFA が前回の起動から変わっていたら知らせ、コピーしたら消す
    @Test
    func ownIdentifierChangeIsShownUntilCopied() async {
        let defaults = Self.makeDefaults()
        let before = makeModel(defaults: defaults, identifier: Self.first, sync: StubDeviceSync())
        await before.unlock()
        #expect(!before.ownIdentifierChanged)

        let after = makeModel(defaults: defaults, identifier: Self.second, sync: StubDeviceSync())
        await after.unlock()
        #expect(after.ownIdentifierChanged)

        after.copy(Self.second)
        #expect(!after.ownIdentifierChanged)
    }

    /// 他の端末の IDFA が同期で変わったら知らせ、確認済みにしたら消す。iCloud から消したら忘れる
    @Test
    func otherDeviceChangeIsShownUntilAcknowledged() async throws {
        let device = DeviceRecord(
            id: "other",
            name: "iPhone 15",
            platform: .iOS,
            identifier: Self.first,
            trackingStatus: .authorized,
            updatedAt: Self.now
        )
        let sync = StubDeviceSync(records: [device])
        let model = makeModel(defaults: Self.makeDefaults(), identifier: Self.first, sync: sync)
        await model.unlock()
        await waitUntil { model.devices.status == .synced }
        #expect(!model.identifierChanged(device))

        var changed = device
        changed.identifier = Self.second
        try await sync.save(changed)
        await model.refreshDevices()
        let listed = try #require(model.devices.otherDevices.first)
        #expect(model.identifierChanged(listed))

        model.acknowledgeIdentifierChange(of: listed)
        #expect(!model.identifierChanged(listed))

        _ = await model.deleteDevice(listed)
        #expect(!model.devices.changes.hasChanged(deviceID: "other"))
    }
}
