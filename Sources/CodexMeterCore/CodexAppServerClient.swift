import Foundation

public enum CodexAppServerError: LocalizedError {
    case notRunning
    case notInitialized
    case protocolError(String)
    case invalidMessage
    case initializationTimedOut(String?)
    case rateLimitRequestTimedOut(String?)
    case initializationFailed(String)
    case transportError(String)
    case processTerminated(String?)

    public var errorDescription: String? {
        switch self {
        case .notRunning:
            return MeterLocalization.text("error.not_running", fallback: "Codex app-server 未运行。")
        case .notInitialized:
            return MeterLocalization.text("error.not_initialized", fallback: "Codex app-server 尚未初始化。")
        case let .protocolError(message):
            return message
        case .invalidMessage:
            return MeterLocalization.text(
                "error.invalid_message",
                fallback: "Codex app-server 返回了无法识别的数据。"
            )
        case let .initializationTimedOut(detail):
            return Self.message(
                MeterLocalization.text("error.initialization_timeout", fallback: "连接 Codex 超时。"),
                detail: detail
            )
        case let .rateLimitRequestTimedOut(detail):
            return Self.message(
                MeterLocalization.text("error.refresh_timeout", fallback: "刷新额度超时。"),
                detail: detail
            )
        case let .initializationFailed(message):
            return MeterLocalization.format(
                "error.initialization_failed",
                fallback: "Codex app-server 初始化失败：%@",
                message
            )
        case let .transportError(message):
            return MeterLocalization.format(
                "error.transport",
                fallback: "Codex app-server 通信失败：%@",
                message
            )
        case let .processTerminated(detail):
            return Self.message(
                MeterLocalization.text("error.process_terminated", fallback: "Codex app-server 已退出。"),
                detail: detail
            )
        }
    }

    public var requiresConnectionRestart: Bool {
        switch self {
        case .notRunning, .initializationTimedOut, .rateLimitRequestTimedOut,
             .initializationFailed, .transportError:
            return true
        case .notInitialized, .protocolError, .invalidMessage, .processTerminated:
            return false
        }
    }

    private static func message(_ message: String, detail: String?) -> String {
        guard let detail, !detail.isEmpty else { return message }
        return "\(message) \(detail)"
    }
}

public enum DiagnosticSummary {
    public static func redacted(
        _ text: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        maxLength: Int = 240
    ) -> String {
        var result = text
        let homePath = homeDirectory.path
        if !homePath.isEmpty {
            result = result.replacingOccurrences(of: homePath, with: "~")
        }

        let replacements: [(String, String)] = [
            (#"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+"#, "Bearer <redacted>"),
            (#"(?i)\bsk-[A-Za-z0-9_-]{8,}\b"#, "<redacted>"),
            (#"(?i)\b(authorization|api[_-]?key|access[_-]?token|refresh[_-]?token|token|password)\s*[:=]\s*[^\s,;]+"#, "$1=<redacted>"),
            (#"(?i)([?&](?:token|key|secret|password)=)[^&\s]+"#, "$1<redacted>"),
        ]
        for (pattern, replacement) in replacements {
            result = replacingMatches(in: result, pattern: pattern, template: replacement)
        }

        result = result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard maxLength > 0, result.count > maxLength else { return result }
        return String(result.prefix(maxLength)) + "…"
    }

    private static func replacingMatches(in text: String, pattern: String, template: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}

public final class CodexAppServerClient {
    public var onReady: (() -> Void)?
    public var onSnapshot: ((RateLimitSnapshot, ResetCreditsSnapshot?) -> Void)?
    public var onSparseUpdate: ((RateLimitSnapshot) -> Void)?
    public var onFailure: ((Error) -> Void)?
    public var onTermination: (() -> Void)?

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var outputBuffer = JSONLineBuffer()
    private var pendingRateLimitRequests = Set<Int>()
    private var rateLimitTimeoutWorkItems: [Int: DispatchWorkItem] = [:]
    private var initializationTimeoutWorkItem: DispatchWorkItem?
    private var nextRequestID = 1
    private var initialized = false
    private var stopping = false
    private var stderrBuffer = Data()

    private static let initializationTimeout: TimeInterval = 15
    private static let rateLimitRequestTimeout: TimeInterval = 15
    private static let maximumStderrBytes = 8_192

    public init() {}

    public var isRunning: Bool {
        process?.isRunning == true
    }

    public var isReady: Bool {
        isRunning && initialized
    }

    public func start(executableURL: URL, clientVersion: String) throws {
        stop()
        stopping = false
        initialized = false
        nextRequestID = 1
        pendingRateLimitRequests.removeAll()
        outputBuffer.reset()
        stderrBuffer.removeAll(keepingCapacity: true)

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async {
                self?.consumeOutput(data)
            }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async {
                self?.consumeErrorOutput(data)
            }
        }
        process.terminationHandler = { [weak self, weak process] _ in
            DispatchQueue.main.async {
                guard let self, let process, self.process === process else { return }
                let errorSummary = self.stderrSummary
                self.cleanupProcessHandles()
                if !self.stopping {
                    self.onFailure?(CodexAppServerError.processTerminated(errorSummary))
                    self.onTermination?()
                }
            }
        }

        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe

        do {
            try process.run()
            try write(AppServerProtocol.initializeRequest(clientVersion: clientVersion))
            scheduleInitializationTimeout()
        } catch {
            cleanupProcessHandles()
            throw CodexAppServerError.transportError(
                DiagnosticSummary.redacted(error.localizedDescription)
            )
        }
    }

    public func stop() {
        stopping = true
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true {
            process?.terminate()
        }
        cleanupProcessHandles()
    }

    public func requestRateLimits() {
        guard initialized else {
            onFailure?(CodexAppServerError.notInitialized)
            return
        }
        let id = nextRequestID
        nextRequestID += 1
        pendingRateLimitRequests.insert(id)
        do {
            try write(AppServerProtocol.rateLimitsRequest(id: id))
            scheduleRateLimitRequestTimeout(id: id)
        } catch {
            pendingRateLimitRequests.remove(id)
            onFailure?(
                CodexAppServerError.transportError(
                    DiagnosticSummary.redacted(error.localizedDescription)
                )
            )
        }
    }

    private func write(_ data: Data) throws {
        guard process?.isRunning == true, let inputPipe else {
            throw CodexAppServerError.notRunning
        }
        try inputPipe.fileHandleForWriting.write(contentsOf: data)
    }

    private func consumeOutput(_ data: Data) {
        for line in outputBuffer.append(data) {
            handleLine(line)
        }
    }

    private func consumeErrorOutput(_ data: Data) {
        stderrBuffer.append(data)
        if stderrBuffer.count > Self.maximumStderrBytes {
            stderrBuffer.removeFirst(stderrBuffer.count - Self.maximumStderrBytes)
        }
    }

    private var stderrSummary: String? {
        let summary = DiagnosticSummary.redacted(String(decoding: stderrBuffer, as: UTF8.self))
        return summary.isEmpty ? nil : summary
    }

    private func handleLine(_ data: Data) {
        do {
            guard let message = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CodexAppServerError.invalidMessage
            }

            if let id = message["id"] as? Int {
                try handleResponse(message, id: id)
                return
            }
            if let method = message["method"] as? String,
               method == "account/rateLimits/updated",
               let params = message["params"] {
                let paramsData = try JSONSerialization.data(withJSONObject: params)
                let update = try RateLimitsResponseParser.parseUpdateParams(paramsData)
                if update.isMainCodexLimit {
                    onSparseUpdate?(update)
                }
            }
        } catch {
            onFailure?(error)
        }
    }

    private func handleResponse(_ message: [String: Any], id: Int) throws {
        if let error = message["error"] as? [String: Any] {
            let text = error["message"] as? String ?? MeterLocalization.text(
                "error.request_failed",
                fallback: "Codex app-server 请求失败。"
            )
            pendingRateLimitRequests.remove(id)
            cancelRateLimitRequestTimeout(id: id)
            if id == 0 {
                initializationTimeoutWorkItem?.cancel()
                initializationTimeoutWorkItem = nil
                throw CodexAppServerError.initializationFailed(
                    DiagnosticSummary.redacted(text)
                )
            }
            throw CodexAppServerError.protocolError(DiagnosticSummary.redacted(text))
        }

        if id == 0 {
            initializationTimeoutWorkItem?.cancel()
            initializationTimeoutWorkItem = nil
            initialized = true
            try write(AppServerProtocol.initializedNotification())
            onReady?()
            requestRateLimits()
            return
        }

        guard pendingRateLimitRequests.remove(id) != nil else { return }
        cancelRateLimitRequestTimeout(id: id)
        guard let result = message["result"] else {
            throw CodexAppServerError.invalidMessage
        }
        let resultData = try JSONSerialization.data(withJSONObject: result)
        let parsed = try RateLimitsResponseParser.parseReadResult(resultData)
        onSnapshot?(parsed.snapshot, parsed.resetCredits)
    }

    private func cleanupProcessHandles() {
        initializationTimeoutWorkItem?.cancel()
        initializationTimeoutWorkItem = nil
        for workItem in rateLimitTimeoutWorkItems.values {
            workItem.cancel()
        }
        rateLimitTimeoutWorkItems.removeAll()
        pendingRateLimitRequests.removeAll()
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
        initialized = false
        stderrBuffer.removeAll(keepingCapacity: true)
    }

    private func scheduleInitializationTimeout() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.process?.isRunning == true, !self.initialized else { return }
            self.initializationTimeoutWorkItem = nil
            self.onFailure?(
                CodexAppServerError.initializationTimedOut(self.stderrSummary)
            )
        }
        initializationTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.initializationTimeout,
            execute: workItem
        )
    }

    private func scheduleRateLimitRequestTimeout(id: Int) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.pendingRateLimitRequests.remove(id) != nil else { return }
            self.rateLimitTimeoutWorkItems.removeValue(forKey: id)
            self.onFailure?(
                CodexAppServerError.rateLimitRequestTimedOut(self.stderrSummary)
            )
        }
        rateLimitTimeoutWorkItems[id] = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.rateLimitRequestTimeout,
            execute: workItem
        )
    }

    private func cancelRateLimitRequestTimeout(id: Int) {
        rateLimitTimeoutWorkItems.removeValue(forKey: id)?.cancel()
    }
}

public struct JSONLineBuffer: Sendable {
    private var buffer = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [Data] {
        buffer.append(data)
        let newline = Data([0x0A])
        var lines: [Data] = []

        while let range = buffer.range(of: newline) {
            var line = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            if line.last == 0x0D {
                line.removeLast()
            }
            if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }

    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }
}
