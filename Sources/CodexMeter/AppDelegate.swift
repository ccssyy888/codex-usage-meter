import AppKit
import CodexMeterCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: MeterViewModel?
    private var menuBarController: MenuBarController?
    private var demoWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments
        let demoMode = arguments.contains("--demo")
        let viewModel = MeterViewModel(demoMode: demoMode)
        self.viewModel = viewModel

        if demoMode, arguments.contains("--demo-window") {
            showDemoWindow(viewModel: viewModel)
        } else {
            let menuBarController = MenuBarController(viewModel: viewModel)
            self.menuBarController = menuBarController
        }

        viewModel.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        demoWindow != nil
    }

    private func showDemoWindow(viewModel: MeterViewModel) {
        let height = MeterDetailView.preferredContentHeight(
            for: ResetCreditsSnapshot(availableCount: 3, credits: nil)
        )
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: MeterDetailView.contentWidth,
                height: height
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Usage Meter"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: MeterDetailView(
                model: viewModel,
                onRefresh: {
                    Task { @MainActor in viewModel.refresh() }
                },
                onChooseCodex: {},
                onQuit: { NSApp.terminate(nil) }
            )
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        demoWindow = window
    }
}
