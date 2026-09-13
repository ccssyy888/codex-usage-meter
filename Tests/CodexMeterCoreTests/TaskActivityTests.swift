import CodexMeterCore
import Darwin
import Foundation

func runTaskActivityTests() {
    func event(_ type: String, turn: String? = "turn-1") -> Data {
        var payload: [String: Any] = ["type": type]
        payload["turn_id"] = turn
        var data = try! JSONSerialization.data(withJSONObject: ["type": "event_msg", "payload": payload])
        data.append(0x0A)
        return data
    }

    check("任务开始后持续运行，完成或中断后立即结束") {
        var state = TaskActivityState()
        expect(state.activeTurnID == nil, "初始状态应为空闲")
        state.append(event("task_started"))
        expect(state.activeTurnID == "turn-1", "任务开始应被识别")
        state.append(event("token_count"))
        expect(state.activeTurnID == "turn-1", "运行不依赖新的 Token 统计或时间猜测")
        state.append(event("task_complete"))
        expect(state.activeTurnID == nil, "任务完成后应停止")
        state.append(event("task_started", turn: "turn-2"))
        state.append(event("turn_aborted", turn: "turn-2"))
        expect(state.activeTurnID == nil, "中断后应停止")
    }

    check("分片、乱序结束事件与消息正文不会误报") {
        var state = TaskActivityState()
        let start = event("task_started")
        for byte in start.dropLast() { state.append(Data([byte])) }
        expect(state.activeTurnID == nil, "未写完的事件不能触发")
        state.append(Data([0x0A]))
        expect(state.activeTurnID == "turn-1", "完整事件应触发")
        state.append(event("task_started", turn: "turn-2"))
        state.append(event("task_complete", turn: "turn-1"))
        expect(state.activeTurnID == "turn-2", "上一轮迟到的结束事件不能停止当前轮")
        state.append(Data(#"{"type":"response_item","payload":{"type":"task_complete","turn_id":"turn-2"}}"#.utf8) + Data([0x0A]))
        state.append(Data(#"{"type":"event_msg","payload":{"type":"agent_message","message":"task_complete"}}"#.utf8) + Data([0x0A]))
        state.append(Data("invalid task_complete\n".utf8))
        expect(state.activeTurnID == "turn-2", "正文与损坏行不能改变状态")
        state.append(event("turn_aborted", turn: nil))
        expect(state.activeTurnID == nil, "兼容没有 turn_id 的中断事件")
    }

    check("超大正文会被跳过，后续生命周期事件仍可识别") {
        var state = TaskActivityState()
        state.append(Data(repeating: 65, count: 4 * 1_024 * 1_024 + 1))
        state.append(Data([0x0A]) + event("task_started"))
        expect(state.activeTurnID == "turn-1", "跳过超大行后应恢复")
    }

    check("启动时恢复运行状态，并正确处理多任务、进程退出与文件替换") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("first.jsonl")
        let second = directory.appendingPathComponent("second.jsonl")
        try (event("task_started") + event("task_complete") + event("task_started", turn: "turn-2")).write(to: first)
        try event("task_started", turn: "other").write(to: second)
        var tracker = TaskActivityTracker()
        expect(tracker.poll(openFiles: [first, second]), "启动时已在运行的任务应被恢复")
        expect(tracker.poll(openFiles: [first, second]), "没有新写入时运行状态仍持续")
        let handle = try FileHandle(forWritingTo: first)
        try handle.seekToEnd()
        try handle.write(contentsOf: event("task_complete", turn: "turn-2"))
        try handle.close()
        expect(tracker.poll(openFiles: [first, second]), "另一任务运行时应继续动画")
        expect(!tracker.poll(openFiles: [first]), "进程不再持有文件时应移除该任务")
        try event("task_started", turn: "replaced").write(to: first, options: .atomic)
        expect(tracker.poll(openFiles: [first]), "文件替换后应重新识别")
        try event("task_complete", turn: "replaced").write(to: first)
        expect(!tracker.poll(openFiles: [first]), "文件截断后不能沿用旧状态")
        expect(!tracker.poll(openFiles: []), "所有进程退出后应空闲")
        expect(!tracker.poll(openFiles: [directory.appendingPathComponent("missing")]), "文件读取失败应空闲")
    }

    check("活动读取不跟随符号链接、不读取目录或管道，也不改写会话") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("rollout-safe.jsonl")
        let link = directory.appendingPathComponent("rollout-link.jsonl")
        let fifo = directory.appendingPathComponent("rollout-pipe.jsonl")
        let original = event("task_started")
        try original.write(to: file)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        guard mkfifo(fifo.path, 0o600) == 0 else {
            throw ValidationFailure(description: "无法建立测试管道")
        }
        var tracker = TaskActivityTracker()
        expect(!tracker.poll(openFiles: [link, directory, fifo]), "非普通文件不能触发或阻塞监听")
        expect(tracker.poll(openFiles: [file]), "当前用户的普通文件仍应正常读取")
        expect(tracker.poll(openFiles: [file]), "没有变化的文件仍保留任务状态")
        let after = try Data(contentsOf: file)
        expect(after == original, "监听不能改写会话文件")
    }
}
