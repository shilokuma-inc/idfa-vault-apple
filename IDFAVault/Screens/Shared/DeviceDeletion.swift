//
//  DeviceDeletion.swift
//  IDFAVault
//
//  他の端末のレコードを 1 台ずつ消す（手放した端末など）。iPhone の一覧・visionOS の板・iPad / Mac のサイドバーと詳細で共通に使う。
//  あわせて、長く同期していない端末に付ける印を置く。
//

import SwiftUI

extension View {
    /// 長押しのメニューで持ち上げる形（角丸にしないため）。Mac の右クリックのメニューには持ち上げる形が無いので付けない
    @ViewBuilder
    func contextMenuPreviewShape(_ shape: some Shape) -> some View {
        #if os(macOS)
        self
        #else
        contentShape(.contextMenuPreview, shape)
        #endif
    }

    /// device に端末を入れたら、iCloud から消すかを確かめて消す。消せなかったら知らせる
    func confirmsDeviceDeletion(_ device: Binding<DeviceRecord?>) -> some View {
        modifier(DeviceDeletionConfirmation(device: device))
    }
}

private struct DeviceDeletionConfirmation: ViewModifier {
    @Environment(AppModel.self) private var model
    @Binding var device: DeviceRecord?
    @State private var deletionFailed = false

    func body(content: Content) -> some View {
        content
            .alert(Text("Remove “\(device?.name ?? "")” from iCloud?"), isPresented: isPresented, presenting: device) { device in
                Button(role: .destructive) {
                    Task { deletionFailed = !(await model.deleteDevice(device)) }
                } label: {
                    Text("Remove")
                }
                Button(role: .cancel) {} label: {
                    Text("Cancel")
                }
            } message: { _ in
                // swiftlint:disable:next line_length
                Text("This device's IDFA will be removed from iCloud. If sync is still turned on for it, it will be added again the next time IDFA Vault is opened on it.")
            }
            .alert(Text("Couldn't Delete the Data"), isPresented: $deletionFailed) {
                Button(role: .cancel) {} label: {
                    Text("OK")
                }
            } message: {
                Text("Check your connection and iCloud settings, and try again.")
            }
    }

    private var isPresented: Binding<Bool> {
        Binding {
            device != nil
        } set: { isPresented in
            if !isPresented {
                device = nil
            }
        }
    }
}

/// 長押し（右クリック）のメニューの「iCloud から削除」
struct RemoveDeviceMenuItem: View {
    var action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Label("Remove from iCloud", systemImage: "trash")
        }
    }
}

/// 長く同期していない端末の印（DeviceRecord.staleInterval）
struct StaleDeviceLabel: View {
    var font: Font = .caption

    var body: some View {
        Label("Not synced in over 30 days", systemImage: "clock.badge.exclamationmark")
            .font(font)
            .foregroundStyle(HeatTint.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}
