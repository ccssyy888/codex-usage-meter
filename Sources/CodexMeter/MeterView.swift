import AppKit
import CodexMeterCore
import SwiftUI

struct MeterDetailView: View {
    static let contentWidth: CGFloat = 320
    static let baseContentHeight: CGFloat = 246
    static let maximumVisibleResetCredits = 6

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: MeterViewModel
    let onRefresh: () -> Void
    let onChooseCodex: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Color.primary.opacity(0.10))
            quotaRow(
                title: MeterLocalization.text("quota.five_hour", fallback: "5 小时"),
                window: model.snapshot?.primary
            )
            Divider().overlay(Color.primary.opacity(0.08))
            quotaRow(
                title: MeterLocalization.text("quota.weekly", fallback: "本周"),
                window: model.snapshot?.secondary
            )
            Divider().overlay(Color.primary.opacity(0.08))
            resetCreditsRow
            Divider().overlay(Color.primary.opacity(0.08))
            footer
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(width: Self.contentWidth, height: preferredContentHeight)
        .background {
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.08)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(model.status.title)
                .font(.system(size: 11.5, weight: .medium))
                .tracking(0.1)
                .foregroundStyle(Color.primary.opacity(0.60))
                .lineLimit(1)
            Spacer(minLength: 12)
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.70))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(MeterLocalization.text("action.refresh", fallback: "立即刷新"))

            Menu {
                Button(
                    MeterLocalization.text("action.choose_codex", fallback: "选择 Codex…"),
                    action: onChooseCodex
                )
                Divider()
                Button(
                    MeterLocalization.text("action.quit", fallback: "退出 Codex Usage Meter"),
                    action: onQuit
                )
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.70))
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .frame(height: 30)
    }

    private func quotaRow(title: String, window: RateLimitWindow?) -> some View {
        let remaining = window?.remainingPercent
        let color = quotaColor(remaining)
        return VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .tracking(0.15)
                    .foregroundStyle(Color.primary.opacity(0.84))
                Spacer(minLength: 10)
                if let remaining {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(MeterLocalization.text("quota.remaining", fallback: "剩余"))
                            .font(.system(size: 12.5, weight: .regular))
                            .tracking(0.1)
                        Text("\(remaining)%")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.primary.opacity(0.62))
                } else {
                    Text("--")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.38))
                }
            }

            QuotaProgressBar(
                progress: Double(remaining ?? 0) / 100,
                tint: color
            )

            HStack(spacing: 8) {
                Text(QuotaFormatting.countdown(until: window?.resetsAt, now: model.now))
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .tracking(0.05)
                    .foregroundStyle(Color.primary.opacity(0.56))
                    .lineLimit(1)
                Spacer()
                Text(QuotaFormatting.localTime(window?.resetsAt) ?? " ")
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .tracking(0.05)
                    .foregroundStyle(Color.primary.opacity(0.44))
                    .lineLimit(1)
            }
        }
        .frame(height: 64)
    }

    private var resetCreditsRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(MeterLocalization.text("credits.title", fallback: "额度重置"))
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.15)
                    .foregroundStyle(Color.primary.opacity(0.82))
                Spacer()
                if let resetCredits = model.resetCredits {
                    Text(
                        MeterLocalization.format(
                            "credits.count",
                            fallback: "%d 次",
                            resetCredits.availableCount
                        )
                    )
                        .font(.system(size: 11.5, weight: .regular))
                        .tracking(0.1)
                        .foregroundStyle(Color.primary.opacity(0.58))
                } else {
                    Text("--")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 34)

            if let resetCredits = model.resetCredits {
                let credits = resetCredits.creditsForDisplay
                if !credits.isEmpty {
                    ScrollView(.vertical, showsIndicators: credits.count > Self.maximumVisibleResetCredits) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(credits.enumerated()), id: \.offset) { index, credit in
                                HStack(spacing: 8) {
                                    Text(
                                        MeterLocalization.format(
                                            "credits.item",
                                            fallback: "第 %d 次",
                                            index + 1
                                        )
                                    )
                                        .foregroundStyle(Color.primary.opacity(0.48))
                                    Spacer()
                                    Text(resetCreditExpiration(credit?.expiresAt))
                                        .monospacedDigit()
                                        .foregroundStyle(Color.primary.opacity(credit?.expiresAt == nil ? 0.38 : 0.58))
                                }
                                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                                .tracking(0.05)
                                .frame(height: 22)
                            }
                        }
                    }
                    .frame(height: CGFloat(min(credits.count, Self.maximumVisibleResetCredits)) * 22)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text(QuotaFormatting.relativeUpdateTime(from: model.snapshot?.fetchedAt, now: model.now))
            Spacer()
            if let message = detailMessage {
                Text(message)
                    .lineLimit(1)
                    .help(message)
            }
        }
        .font(.system(size: 10.5, weight: .regular))
        .tracking(0.1)
        .foregroundStyle(Color.primary.opacity(0.46))
        .frame(height: 20)
    }

    private var statusColor: Color {
        switch model.status {
        case .connected: return .green
        case .loading, .stale: return .orange
        case .codexNotFound: return .gray
        case .notLoggedIn, .incompatible, .error: return .red
        }
    }

    private var detailMessage: String? {
        switch model.status {
        case let .stale(message): return message
        case let .incompatible(message), let .error(message): return message
        case .codexNotFound:
            return MeterLocalization.text("status.choose_codex_hint", fallback: "请从菜单选择 codex")
        case .notLoggedIn:
            return MeterLocalization.text("status.login_hint", fallback: "请先运行 codex login")
        default: return nil
        }
    }

    private func quotaColor(_ remaining: Int?) -> Color {
        guard let remaining, model.snapshot != nil else { return .gray }
        switch min(100, max(0, remaining)) {
        case 80...100:
            return Color(red: 0.20, green: 0.78, blue: 0.35)
        case 50..<80:
            return Color(red: 0.00, green: 0.48, blue: 1.00)
        case 20..<50:
            return Color(red: 1.00, green: 0.58, blue: 0.00)
        default:
            return Color(red: 1.00, green: 0.23, blue: 0.19)
        }
    }

    private var preferredContentHeight: CGFloat {
        Self.preferredContentHeight(for: model.resetCredits)
    }

    static func preferredContentHeight(for resetCredits: ResetCreditsSnapshot?) -> CGFloat {
        let visibleCredits = min(
            resetCredits?.creditsForDisplay.count ?? 0,
            maximumVisibleResetCredits
        )
        return baseContentHeight + CGFloat(visibleCredits) * 22
    }

    private func resetCreditExpiration(_ date: Date?) -> String {
        guard let localTime = QuotaFormatting.localTime(date) else {
            return MeterLocalization.text("credits.expiry_unknown", fallback: "到期时间未知")
        }
        return MeterLocalization.format("credits.expires", fallback: "%@ 到期", localTime)
    }
}

private struct QuotaProgressBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let fraction = min(1, max(0, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.10))
                if fraction > 0 {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(7, proxy.size.width * fraction))
                }
            }
        }
        .frame(height: 7)
        .animation(.easeInOut(duration: 0.25), value: progress)
        .accessibilityValue("\(Int((progress * 100).rounded()))%")
    }
}

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}
