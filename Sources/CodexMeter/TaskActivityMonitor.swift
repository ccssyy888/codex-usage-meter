import CodexMeterCore
import Foundation

/// All file and process inspection happens off the UI thread, once per second.
final class TaskActivityMonitor {
    private let queue = DispatchQueue(label: "io.github.ccssyy888.CodexUsageMeter.activity", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var tracker = TaskActivityTracker()
    private var lastRunning: Bool?

    func start(executableURL: URL?, onChange: @escaping (Bool) -> Void) {
        queue.async { [self] in
            timer?.cancel()
            tracker = TaskActivityTracker()
            lastRunning = nil
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: 1, leeway: .milliseconds(100))
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                let running = self.tracker.poll(openFiles: CodexSessionFiles.openFiles(executableURL: executableURL))
                guard running != self.lastRunning else { return }
                self.lastRunning = running
                DispatchQueue.main.async { onChange(running) }
            }
            self.timer = timer
            timer.resume()
        }
    }

    func stop() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
            tracker = TaskActivityTracker()
            lastRunning = nil
        }
    }

    deinit { timer?.cancel() }
}
