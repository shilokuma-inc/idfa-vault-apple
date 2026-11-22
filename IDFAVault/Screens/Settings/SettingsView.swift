//
//  SettingsView.swift
//  IDFAVault
//
//  設定（デザインの Settings）。SECURITY / DISPLAY / ICLOUD の 3 グループ（仕様書 3.5）。DISPLAY にはコピーの形式も置く。
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    ToolButtonLabel(systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .toolBackground()
                .accessibilityLabel(Text("Back"))

                Text("Settings")
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(1.36)
                    .headingMetal()
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                    .accessibilityAddTraits(.isHeader)

                SettingsForm()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(HeatTintBackground())
        .hidesNavigationBar()
    }
}

/// 設定の項目。iPhone の設定画面と、iPad・Mac の設定（シート・ウインドウ）で共通に使う
struct SettingsForm: View {
    @Environment(AppModel.self) private var model
    @State private var confirmsDeletion = false
    @State private var deletionFailed = false

    var body: some View {
        @Bindable var settings = model.settings
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "SECURITY")
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                Toggle(isOn: .constant(true)) {
                    SettingLabel(title: model.biometry.requireAtLaunchTitle, detail: "Can't be turned off")
                }
                .toggleStyle(.chamfer)
                .disabled(true)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                SettingsDivider()
                autoLockRow
            }
            .plateBackground(chamfer: 16)

            SectionHeader(title: "DISPLAY")
                .padding(.horizontal, 4)
                .padding(.top, 8)
            VStack(spacing: 0) {
                Toggle(isOn: $settings.masksOtherDevices) {
                    SettingLabel(title: "Mask Other Devices' IDFA", detail: "Tap a device to show all digits")
                }
                .toggleStyle(.chamfer)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .accessibilityIdentifier("masksOtherDevices")
                SettingsDivider()
                Toggle(isOn: $settings.hidesWhileCapturing) {
                    SettingLabel(title: "Hide During Screen Recording or Mirroring")
                }
                .toggleStyle(.chamfer)
                .padding(.horizontal, 16)
                .frame(minHeight: 54)
                .accessibilityIdentifier("hidesWhileCapturing")

                SettingsDivider()

                copyFormatRow
            }
            .plateBackground(chamfer: 16)

            SectionHeader(title: "ICLOUD")
                .padding(.horizontal, 4)
                .padding(.top, 8)
            VStack(spacing: 0) {
                // IDFA を取得できないプラットフォーム（visionOS）では、この端末のレコードを書かないので出さない
                if model.supportsOwnIdentifier {
                    Toggle(isOn: syncsThisDevice) {
                        SettingLabel(title: "Sync This Device's IDFA", detail: "Shown only on devices with the same Apple ID")
                    }
                    .toggleStyle(.chamfer)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .accessibilityIdentifier("syncsThisDevice")
                    SettingsDivider()
                    DeviceNameField()
                    SettingsDivider()
                }
                Button(role: .destructive) {
                    confirmsDeletion = true
                } label: {
                    Text("Delete All iCloud Sync Data")
                        .font(.callout)
                        .foregroundStyle(HeatTint.destructive)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("deleteAll")
            }
            .plateBackground(chamfer: 16)

            // swiftlint:disable:next line_length
            Text("Each device has its own IDFA, and it changes if you reset it. Synced data is updated automatically the next time each device opens the app.")
                .font(.caption)
                .foregroundStyle(HeatTint.tertiaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .alert(Text("Delete All iCloud Sync Data?"), isPresented: $confirmsDeletion) {
            Button(role: .destructive) {
                Task { deletionFailed = !(await model.deleteAllSyncedData()) }
            } label: {
                Text("Delete")
            }
            Button(role: .cancel) {} label: {
                Text("Cancel")
            }
        } message: {
            // swiftlint:disable:next line_length
            Text("The IDFA of all your devices will be removed from iCloud. Devices that have sync turned on add theirs again the next time IDFA Vault is opened on them.")
        }
        .alert(Text("Couldn't Delete the Data"), isPresented: $deletionFailed) {
            Button(role: .cancel) {} label: {
                Text("OK")
            }
        } message: {
            Text("Check your connection and iCloud settings, and try again.")
        }
    }

    /// オフにしたら iCloud のこの端末のレコードを消すので、設定の値を直接は書き換えない
    private var syncsThisDevice: Binding<Bool> {
        Binding {
            model.settings.syncsThisDevice
        } set: { isOn in
            Task { await model.setSyncsThisDevice(isOn) }
        }
    }

    private var autoLockRow: some View {
        @Bindable var settings = model.settings
        return Menu {
            Picker(selection: $settings.autoLock) {
                ForEach(AutoLockTiming.allCases) { timing in
                    Text(timing.title)
                        .tag(timing)
                }
            } label: {
                Text("Auto-Lock")
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 8) {
                Text("Auto-Lock")
                    .font(.callout)
                    .foregroundStyle(HeatTint.text)
                Spacer(minLength: 8)
                Text(model.settings.autoLock.title)
                    .font(.callout)
                    .foregroundStyle(HeatTint.secondaryText)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HeatTint.sectionHeader)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityIdentifier("autoLock")
    }

    /// コピー・共有・QR コードの IDFA の形式。右に今の形式の短い例を出す
    private var copyFormatRow: some View {
        @Bindable var settings = model.settings
        return Menu {
            Picker(selection: $settings.identifierFormat) {
                ForEach(IdentifierFormat.allCases) { format in
                    Text(format.title)
                        .tag(format)
                }
            } label: {
                Text("Copy Format")
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 8) {
                SettingLabel(title: "Copy Format", detail: "Also used for sharing and QR codes")
                Spacer(minLength: 8)
                Text(verbatim: "\(model.settings.identifierFormat.sample)…")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(HeatTint.secondaryText)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityLabel(Text(model.settings.identifierFormat.title))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(HeatTint.sectionHeader)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityIdentifier("copyFormat")
    }
}

/// この端末の名前（iPhone・iPad）。同じ機種の端末を見分けられるよう、他の端末の一覧に出す名前を変える。
/// 入力を終えたら（return・フォーカスが外れたら）保存して、同期のレコードを書き直す
private struct DeviceNameField: View {
    @Environment(AppModel.self) private var model
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingLabel(title: "This Device's Name", detail: "Leave empty to use the model name")
            TextField(text: $draft, prompt: Text(verbatim: model.ownDeviceName ?? "")) {
                Text("This Device's Name")
            }
            .textFieldStyle(.plain)
            .font(.callout)
            .foregroundStyle(HeatTint.text)
            .submitLabel(.done)
            .autocorrectionDisabled()
            .focused($isFocused)
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .background {
                ChamferedRect(chamfer: 8)
                    .fill(Color.black.opacity(0.28))
                    .overlay(ChamferedRect(chamfer: 8).stroke(HeatTint.sectionHeader.opacity(0.35), lineWidth: 1))
            }
            .onSubmit(save)
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    save()
                }
            }
            .onChange(of: draft) { _, text in
                if text.count > AppModel.customDeviceNameLimit {
                    draft = String(text.prefix(AppModel.customDeviceNameLimit))
                }
            }
            .accessibilityIdentifier("deviceName")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear {
            draft = model.settings.customDeviceName
        }
        .onDisappear(perform: save)
    }

    private func save() {
        let name = draft
        Task { await model.setCustomDeviceName(name) }
    }
}

/// 設定の項目名と補足
struct SettingLabel: View {
    var title: LocalizedStringResource
    var detail: LocalizedStringResource?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.callout)
                .foregroundStyle(HeatTint.text)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(HeatTint.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// 設定のグループの中の区切り
struct SettingsDivider: View {
    var body: some View {
        Groove(highlight: 0.18)
            .padding(.horizontal, 16)
    }
}

/// iPad の設定（シート）。iPhone の設定画面と同じ項目を、閉じるボタン付きで出す
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 34, weight: .heavy))
                        .tracking(1.36)
                        .headingMetal()
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        ToolButtonLabel(systemImage: "xmark")
                    }
                    .buttonStyle(.plain)
                    .toolBackground()
                    .accessibilityLabel(Text("Close"))
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
                SettingsForm()
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(HeatTintBackground())
        .presentationBackground {
            HeatTintBackground()
        }
        .preferredColorScheme(.dark)
    }
}
