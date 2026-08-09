import AppKit
import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 336)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(
            "Couldn’t Save Mode",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.dismissError() } }
            )
        ) {
            Button("OK", role: .cancel) { model.dismissError() }
        } message: {
            Text(model.errorMessage ?? "Please try again.")
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 26, height: 26)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text("ScrollFlip")
                    .font(.system(size: 14, weight: .semibold))
                Text(model.headline)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.28), radius: 3)
                .accessibilityLabel(model.headline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Scroll direction")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    ForEach(ScrollFlipMode.allCases) { mode in
                        ModeButton(
                            mode: mode,
                            isSelected: model.mode == mode,
                            action: { model.setMode(mode) }
                        )
                    }
                }
                .padding(4)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
            }

            HStack(alignment: .top, spacing: 11) {
                Image(systemName: statusSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.headline)
                        .font(.system(size: 13, weight: .semibold))
                    Text(model.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if model.mode == .auto && model.accessibilityGranted {
                HStack {
                    Label("Mac lid", systemImage: "laptopcomputer")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(model.lidIsClosed ? "Closed" : "Open")
                        .foregroundStyle(.primary)
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.top, -3)
            }

            if !model.accessibilityGranted {
                permissionCallout
            }
        }
        .padding(16)
    }

    private var permissionCallout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Only wheel events are changed. Clicks and keystrokes are never read.")
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("Open Settings") { model.openAccessibilitySettings() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Try Again") { model.retryAccessibility() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                model.openShortcuts()
            } label: {
                Label("Shortcuts", systemImage: "command")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Menu {
                Button("About ScrollFlip") { NSApp.orderFrontStandardAboutPanel(nil) }
                Divider()
                Button("Quit ScrollFlip") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusColor: Color {
        if !model.accessibilityGranted || !model.engineIsActive { return .orange }
        if model.isFlipping { return .green }
        return .secondary
    }

    private var statusSymbol: String {
        if !model.accessibilityGranted { return "exclamationmark.triangle.fill" }
        if !model.engineIsActive { return "bolt.slash.fill" }
        if model.isFlipping { return "arrow.up.arrow.down.circle.fill" }
        return "pause.circle.fill"
    }
}

private struct ModeButton: View {
    let mode: ScrollFlipMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: mode.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                Text(mode.title)
                    .font(.system(size: 11, weight: .semibold))
                Text(mode.detail)
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
        .background(
            isSelected ? Color.accentColor.opacity(0.13) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .accessibilityLabel(mode.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(mode.detail)
    }
}
