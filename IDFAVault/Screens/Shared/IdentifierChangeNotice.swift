//
//  IdentifierChangeNotice.swift
//  IDFAVault
//
//  前に見たときから IDFA が変わったことの知らせ（IdentifierChangeTracker）。
//  選んでいる端末（iPhone のこの端末・iPad / Mac の詳細）には説明と「確認済みにする」を出し、一覧の行には短い印を出す。
//  コピーしても確認したことになる。
//

import SwiftUI

/// IDFA が変わったことの説明と「確認済みにする」
struct IdentifierChangeNotice: View {
    var onAcknowledge: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HeatTint.warning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("IDFA Changed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HeatTint.text)
                    .accessibilityAddTraits(.isHeader)
                // swiftlint:disable:next line_length
                Text("It's different from the last time it was shown. Update it wherever you registered it, such as test devices in ad SDKs.")
                    .font(.footnote)
                    .foregroundStyle(HeatTint.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onAcknowledge) {
                    Text("Mark as Checked")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(HeatTint.link)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("acknowledgeIdentifierChange")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .plateBackground(chamfer: 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("identifierChangeNotice")
    }
}

/// 一覧の行に出す「IDFA が変わりました」
struct IdentifierChangedLabel: View {
    var body: some View {
        Label("IDFA changed", systemImage: "arrow.triangle.2.circlepath")
            .font(.caption.weight(.semibold))
            .foregroundStyle(HeatTint.warning)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 長押し（右クリック）のメニューの「確認済みにする」
struct AcknowledgeChangeMenuItem: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Mark as Checked", systemImage: "checkmark")
        }
    }
}
