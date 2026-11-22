//
//  IdentifierFormat.swift
//  IDFAVault
//
//  IDFA をコピー・共有・QR コードにするときの形式。広告 SDK・計測ツールの管理画面によって、
//  小文字やハイフンなしで求められることがあるので、設定で選べるようにする。画面に出す値はいつも大文字・ハイフン付き。
//

import Foundation

enum IdentifierFormat: String, CaseIterable, Identifiable, Sendable {
    /// 大文字・ハイフン付き（例: 6D92078A-8246-4BA4-AE5B-76104861E7DC）。既定
    case uppercaseHyphenated
    /// 小文字・ハイフン付き（例: 6d92078a-8246-4ba4-ae5b-76104861e7dc）
    case lowercaseHyphenated
    /// 大文字・ハイフンなし（例: 6D92078A82464BA4AE5B76104861E7DC）
    case uppercaseCompact
    /// 小文字・ハイフンなし（例: 6d92078a82464ba4ae5b76104861e7dc）
    case lowercaseCompact

    var id: Self { self }

    /// 設定の選択肢の文言
    var title: LocalizedStringResource {
        switch self {
        case .uppercaseHyphenated:
            "Uppercase with Hyphens"
        case .lowercaseHyphenated:
            "Lowercase with Hyphens"
        case .uppercaseCompact:
            "Uppercase Without Hyphens"
        case .lowercaseCompact:
            "Lowercase Without Hyphens"
        }
    }

    /// 設定の行に出す短い例（先頭の 2 区切りだけ）
    var sample: String {
        apply(to: "6D92078A-8246")
    }

    /// 大文字・ハイフン付きの値を、この形式に直す
    func apply(to value: String) -> String {
        switch self {
        case .uppercaseHyphenated:
            value
        case .lowercaseHyphenated:
            value.lowercased()
        case .uppercaseCompact:
            value.replacingOccurrences(of: "-", with: "")
        case .lowercaseCompact:
            value.replacingOccurrences(of: "-", with: "").lowercased()
        }
    }
}

extension AdvertisingIdentifier {
    /// コピー・共有・QR コードに使う、format の形式の文字列
    func formatted(_ format: IdentifierFormat) -> String {
        format.apply(to: value)
    }
}
