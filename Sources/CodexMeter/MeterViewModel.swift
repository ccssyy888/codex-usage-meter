import AppKit
import CodexMeterCore
import Combine
import Network

enum MeterConnectionStatus: Equatable {
    case loading
    case connected
    case stale(String?)
    case codexNotFound
    case notLoggedIn
    case incompatible(String)
    case error(String)

    var title: String {
        switch self {
        case .loading:
            return MeterLocalization.text("status.connecting", fallback: "正在连接")
        case .connected:
            return MeterLocalization.text("status.connected", fallback: "已连接")
        case .stale:
            return MeterLocalization.text("status.stale", fallback: "数据可能已过期")
        case .codexNotFound:
            return MeterLocalization.text("status.codex_not_found", fallback: "未找到 Codex")
        case .notLoggedIn:
            return MeterLocalization.text("status.not_logged_in", fallback: "Codex 尚未登录")
        case .incompatible:
            return MeterLocalization.text("status.incompatible", fallback: "CLI 版本不兼容")
        case .error:
            return MeterLocalization.text("status.error", fallback: "连接失败")
        }
    }
}

@MainActor
final class MeterViewModel: ObservableObject {
    @Published private(set) var snapshot: RateLimitSnapshot?
    @Published private(set) var resetCredits: ResetCreditsSnapshot?
    @Published private(set) var status: MeterConnectionStatus = .loading
    @Published private(set) var now = Date()

    private let client = CodexAppServerClient()
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "io.github.ccssyy888.CodexUsageMeter.network")
    private var tickTimer: Timer?
    private var refreshTimer: Timer?
    private var reconnectWorkItem: DispatchWorkItem?
    private var wakeObserver: NSObjectProtocol?
    private var reconnectAttempt = 0
    private var stopped = true
    private let demoMode: Bool

    init(demoMode: Bool = false) {
        self.demoMode = demoMode
        bindClient()
    }

    var remainingPercent: Int? {
        snapshot?.primary?.remainingPercent
    }

    func start() {
        guard stopped else { return }
        stopped = false
        installTimers()
        if demoMode {
            loadDemoData()
            return
        }
        installWakeObserver()
        startNetworkMonitor()
        connect(resetBackoff: true)
    }

    func stop() {
        stopped = true
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        tickTimer?.invalidate()
        refreshTimer?.invalidate()
        tickTimer = nil
        refreshTimer = nil
        pathMonitor.cancel()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = nil
        client.stop()
    }

    func refresh() {
        guard !stopped else { return }
        if demoMode {
            loadDemoData()
            return
        }
        if client.isReady {
            client.requestRateLimits()
        } else if client.isRunning {
            return
        } else {
            connect(resetBackoff: true)
        }
    }

    func refreshIfStale(maxAge: TimeInterval = 30) {
        guard let fetchedAt = snapshot?.fetchedAt else {
            refresh()
            return
        }
        if Date().timeIntervalSince(fetchedAt) >= maxAge {
            refresh()
        }
    }

    func chooseCodexExecutable() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = MeterLocalization.text("picker.title", fallback: "选择 Codex 可执行文件")
        panel.message = MeterLocalization.text(
            "picker.message",
            fallback: "请选择 codex 命令文件。常见位置是 ~/.local/bin/codex。"
        )
        panel.prompt = MeterLocalization.text("picker.choose", fallback: "选择")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            status = .error(
                MeterLocalization.text(
                    "picker.not_executable",
                    fallback: "所选文件不可执行。"
                )
            )
            return
        }
        UserDefaults.standard.set(url.path, forKey: DefaultsKey.codexPath)
        reconnectWorkItem?.cancel()
        client.stop()
        connect(resetBackoff: true)
    }

    private func bindClient() {
        client.onSnapshot = { [weak self] snapshot, resetCredits in
            guard let self else { return }
            self.snapshot = snapshot
            self.resetCredits = resetCredits
            self.status = .connected
            self.reconnectAttempt = 0
        }
        client.onSparseUpdate = { [weak self] update in
            guard let self else { return }
            if let snapshot = self.snapshot {
                self.snapshot = snapshot.merging(update)
            } else if update.hasQuotaWindowUpdate {
                self.snapshot = update
            }
            if update.hasQuotaWindowUpdate {
                self.status = .connected
            }
        }
        client.onFailure = { [weak self] error in
            guard let self else { return }
            self.handle(error: error)
            if (error as? CodexAppServerError)?.requiresConnectionRestart == true {
                self.client.stop()
                self.scheduleReconnect()
            }
        }
    }

    private func connect(resetBackoff: Bool) {
        guard !stopped else { return }
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        if resetBackoff {
            reconnectAttempt = 0
        }

        let persistedPath = UserDefaults.standard.string(forKey: DefaultsKey.codexPath)
        guard let executableURL = CodexPathResolver.resolve(persistedPath: persistedPath) else {
            status = .codexNotFound
            return
        }

        if snapshot == nil {
            status = .loading
        }
        do {
            try client.start(
                executableURL: executableURL,
                clientVersion: Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "development"
            )
        } catch {
            handle(error: error)
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        guard !stopped else { return }
        let delay = ReconnectPolicy.delay(forAttempt: reconnectAttempt)
        reconnectAttempt += 1
        let workItem = DispatchWorkItem { [weak self] in
            self?.connect(resetBackoff: false)
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func handle(error: Error) {
        let message = DiagnosticSummary.redacted(error.localizedDescription)
        let normalized = message.lowercased()
        if error is RateLimitsParsingError {
            status = .incompatible(message)
        } else if normalized.contains("login") || normalized.contains("authentication") || normalized.contains("unauthorized") {
            status = .notLoggedIn
        } else if normalized.contains("method not found") {
            status = .incompatible(message)
        } else if snapshot != nil {
            status = .stale(message)
        } else {
            status = .error(message)
        }
    }

    private func installTimers() {
        let tickTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.now = Date()
                if self.status == .connected,
                   let fetchedAt = self.snapshot?.fetchedAt,
                   self.now.timeIntervalSince(fetchedAt) > 90 {
                    self.status = .stale(nil)
                }
            }
        }
        RunLoop.main.add(tickTimer, forMode: .common)
        self.tickTimer = tickTimer

        let refreshTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(refreshTimer, forMode: .common)
        self.refreshTimer = refreshTimer
    }

    private func installWakeObserver() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func startNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                self?.refreshIfStale(maxAge: 30)
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    private func loadDemoData() {
        let reference = Date()
        now = reference
        snapshot = RateLimitSnapshot(
            limitID: "codex",
            primary: RateLimitWindow(
                usedPercent: 28,
                windowDurationMins: 300,
                resetsAt: reference.addingTimeInterval(2 * 3_600 + 14 * 60)
            ),
            secondary: RateLimitWindow(
                usedPercent: 58,
                windowDurationMins: 10_080,
                resetsAt: reference.addingTimeInterval(3 * 86_400 + 8 * 3_600)
            ),
            credits: nil,
            planType: "demo",
            reachedType: nil,
            fetchedAt: reference.addingTimeInterval(-4)
        )
        resetCredits = ResetCreditsSnapshot(
            availableCount: 3,
            credits: [
                ResetCredit(
                    id: "demo-1",
                    title: "Full reset",
                    description: nil,
                    expiresAt: reference.addingTimeInterval(5 * 86_400)
                ),
                ResetCredit(
                    id: "demo-2",
                    title: "Full reset",
                    description: nil,
                    expiresAt: reference.addingTimeInterval(12 * 86_400)
                ),
                ResetCredit(
                    id: "demo-3",
                    title: "Full reset",
                    description: nil,
                    expiresAt: reference.addingTimeInterval(28 * 86_400)
                ),
            ]
        )
        status = .connected
    }
}

enum DefaultsKey {
    static let codexPath = "codexExecutablePath"
}
