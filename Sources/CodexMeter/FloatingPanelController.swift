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
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = MeterIcon.menuBarImage(remainingPercent: nil)
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
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
            .sink { [weak self] _, _ in
                self?.updateStatusItem()
            }
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
        button.image = MeterIcon.menuBarImage(remainingPercent: remaining)
        button.title = remaining.map { "\($0)%" } ?? "--"

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
