import AppKit
import CodexMeterCore
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let viewModel: MeterViewModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables = Set<AnyCancellable>()
    private var activityTimer: Timer?
    private var activityStartedAt: TimeInterval = 0
    private var isTaskRunning = false

    init(viewModel: MeterViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()

        configureStatusItem()
        configurePopover()
        observeViewModel()
        updateStatusItem()
    }

    deinit {
        activityTimer?.invalidate()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = MeterIcon.menuBarImage(remainingPercent: nil)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.target = self
        button.action = #selector(togglePopover)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(
            width: MeterDetailView.contentWidth,
            height: MeterDetailView.baseContentHeight
        )
        popover.contentViewController = NSHostingController(
            rootView: MeterDetailView(
                model: viewModel,
                onRefresh: { [weak viewModel] in
                    Task { @MainActor in viewModel?.refresh() }
                },
                onChooseCodex: { [weak viewModel] in
                    Task { @MainActor in viewModel?.chooseCodexExecutable() }
                },
                onQuit: { NSApp.terminate(nil) }
            )
        )
    }

    private func observeViewModel() {
        viewModel.$snapshot
            .combineLatest(viewModel.$status)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)

        viewModel.$isTaskRunning
            .removeDuplicates()
            .sink { [weak self] running in
                self?.isTaskRunning = running
                self?.updateActivityAnimation()
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateActivityAnimation() }
            .store(in: &cancellables)

        viewModel.$resetCredits
            .sink { [weak self] resetCredits in
                self?.popover.contentSize = NSSize(
                    width: MeterDetailView.contentWidth,
                    height: MeterDetailView.preferredContentHeight(for: resetCredits)
                )
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        let remaining = viewModel.remainingPercent
        updateIcon()

        let quotaDescription = remaining.map {
            MeterLocalization.format("quota.remaining_percent", fallback: "剩余 %d%%", $0)
        } ?? MeterLocalization.text("quota.data_unknown", fallback: "数据未知")
        button.toolTip = MeterLocalization.format(
            "menubar.tooltip",
            fallback: "Codex Usage Meter：五小时额度%@ · %@",
            quotaDescription,
            viewModel.status.title
        )
        button.setAccessibilityLabel("Codex Usage Meter")
        button.setAccessibilityValue(quotaDescription)
    }

    private func updateActivityAnimation() {
        guard isTaskRunning, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            updateIcon()
            return
        }
        let uptime = ProcessInfo.processInfo.systemUptime
        guard activityTimer == nil else { return }
        activityStartedAt = uptime
        let timer = Timer(timeInterval: 1.0 / 24, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateIcon() }
        }
        timer.tolerance = 0.008
        activityTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        updateIcon()
    }

    private func updateIcon() {
        let uptime = ProcessInfo.processInfo.systemUptime
        if activityTimer != nil,
           !isTaskRunning || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            activityTimer?.invalidate()
            activityTimer = nil
        }
        let elapsed = max(0, uptime - activityStartedAt)
        let opacity = activityTimer == nil ? 0 : min(1, elapsed / 0.25)
        statusItem.button?.image = MeterIcon.menuBarImage(
            remainingPercent: viewModel.remainingPercent,
            activityPhase: elapsed / 2.2,
            activityOpacity: opacity
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        viewModel.refreshIfStale(maxAge: 30)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}
