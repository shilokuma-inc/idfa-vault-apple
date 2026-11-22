//
//  IdentifierChangeTracker.swift
//  IDFAVault
//
//  前に見たときから IDFA が変わった端末を覚える。IDFA は設定のリセットなどで変わり、
//  広告 SDK に登録したテスト端末が効かなくなるので、変わったことを画面で知らせる。
//  前回の値は IDFA そのものではなく SHA-256 のハッシュだけを、この端末の UserDefaults に残す（同期しない）。
//

import CryptoKit
import Foundation
import Observation

@Observable
final class IdentifierChangeTracker {
    private enum Key {
        /// 端末の ID → 最後に見た IDFA のハッシュ
        static let lastSeen = "identifierChange.lastSeen"
        /// 変わったのに、まだ確認していない端末の ID
        static let changed = "identifierChange.changed"
    }

    /// IDFA が変わったのに、まだ確認していない端末の ID
    private(set) var changedDeviceIDs: Set<String> {
        didSet { defaults.set(changedDeviceIDs.sorted(), forKey: Key.changed) }
    }

    @ObservationIgnored private var lastSeen: [String: String] {
        didSet { defaults.set(lastSeen, forKey: Key.lastSeen) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        lastSeen = defaults.dictionary(forKey: Key.lastSeen) as? [String: String] ?? [:]
        changedDeviceIDs = Set(defaults.stringArray(forKey: Key.changed) ?? [])
    }

    /// 端末の今の IDFA を見る。前に見た値と違えば「変わった」にする。
    /// 取得できない（nil）ときは比べず、前の値も残す（許可を切ってまた許可したあとに、変わったかを比べられるように）
    func observe(deviceID: String, identifier: AdvertisingIdentifier?) {
        guard let identifier else {
            return
        }
        let hash = Self.hash(of: identifier)
        if let previous = lastSeen[deviceID], previous != hash {
            changedDeviceIDs.insert(deviceID)
        }
        if lastSeen[deviceID] != hash {
            lastSeen[deviceID] = hash
        }
    }

    func hasChanged(deviceID: String) -> Bool {
        changedDeviceIDs.contains(deviceID)
    }

    /// 変わったことを確認した（コピーした・「確認済み」にした）
    func acknowledge(deviceID: String) {
        if changedDeviceIDs.contains(deviceID) {
            changedDeviceIDs.remove(deviceID)
        }
    }

    /// 端末を忘れる（iCloud から消したとき）
    func forget(deviceID: String) {
        acknowledge(deviceID: deviceID)
        lastSeen[deviceID] = nil
    }

    /// 撮影と UI テストで、IDFA が変わった端末がある状態から始める
    static func seedChanged(deviceIDs: [String], in defaults: UserDefaults) {
        defaults.set(deviceIDs, forKey: Key.changed)
    }

    private static func hash(of identifier: AdvertisingIdentifier) -> String {
        SHA256.hash(data: Data(identifier.value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
