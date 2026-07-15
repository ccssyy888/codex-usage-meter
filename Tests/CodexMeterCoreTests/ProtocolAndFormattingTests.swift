import CodexMeterCore
import Foundation

func runProtocolAndFormattingTests() {
    check("握手和额度请求是 JSONL") {
        let initialize = try require(
            try JSONSerialization.jsonObject(
                with: AppServerProtocol.initializeRequest(clientVersion: "0.1.1")
            ) as? [String: Any],
            "初始化请求不是 JSON 对象"
        )
        expect(initialize["method"] as? String == "initialize", "初始化方法名错误")
        expect(initialize["id"] as? Int == 0, "初始化请求 ID 错误")
        let clientInfo = (initialize["params"] as? [String: Any])?["clientInfo"] as? [String: Any]
        expect(clientInfo?["name"] as? String == "codex_usage_meter", "客户端名称错误")
        expect(clientInfo?["title"] as? String == "Codex Usage Meter", "客户端标题错误")
        expect(clientInfo?["version"] as? String == "0.1.1", "客户端版本错误")

        let initialized = try require(
            try JSONSerialization.jsonObject(with: AppServerProtocol.initializedNotification()) as? [String: Any],
            "initialized 通知不是 JSON 对象"
        )
        expect(initialized["method"] as? String == "initialized", "initialized 方法名错误")

        let requestData = try AppServerProtocol.rateLimitsRequest(id: 7)
        let request = try require(
            try JSONSerialization.jsonObject(with: requestData) as? [String: Any],
            "额度请求不是 JSON 对象"
        )
        expect(request["method"] as? String == "account/rateLimits/read", "额度方法名错误")
        expect(request["id"] as? Int == 7, "额度请求 ID 错误")
        expect(requestData.last == 0x0A, "请求必须以换行结束")
    }

    check("JSONL 缓冲区支持分片和 CRLF") {
        var buffer = JSONLineBuffer()
        expect(buffer.append(Data("{\"id\":".utf8)).isEmpty, "半行不应提前输出")
        let lines = buffer.append(Data("1}\r\n\n{\"id\":2}\npartial".utf8))
        expect(lines.map { String(decoding: $0, as: UTF8.self) } == ["{\"id\":1}", "{\"id\":2}"], "完整行切分错误")
        expect(buffer.append(Data("-line\n".utf8)).map { String(decoding: $0, as: UTF8.self) } == ["partial-line"], "跨分片行拼接错误")
    }

    check("重连退避最大为 30 秒") {
        expect(ReconnectPolicy.delay(forAttempt: -1) == 1, "负数尝试应回退到首档")
        expect(ReconnectPolicy.delay(forAttempt: 2) == 5, "第三次退避应为 5 秒")
        expect(ReconnectPolicy.delay(forAttempt: 99) == 30, "退避上限应为 30 秒")
    }

    check("Codex 路径按优先级解析") {
        let home = URL(fileURLWithPath: "/tmp/fake-home")
        let persisted = "/custom/codex"
        let resolved = CodexPathResolver.resolve(
            persistedPath: persisted,
            homeDirectory: home,
            isExecutable: { $0 == home.appendingPathComponent(".local/bin/codex").path }
        )
        expect(resolved?.path == "/tmp/fake-home/.local/bin/codex", "应跳过不可执行的持久路径")
        expect(CodexPathResolver.candidateURLs(persistedPath: persisted, homeDirectory: home).first?.path == persisted, "用户路径应排第一")
    }

    check("倒计时处理小时、天数、过期与缺失值") {
        let now = Date(timeIntervalSince1970: 1000)
        expect(QuotaFormatting.countdown(until: now.addingTimeInterval(3661), now: now) == "1:01:01 后刷新", "小时倒计时错误")
        expect(QuotaFormatting.countdown(until: now.addingTimeInterval(90_000), now: now) == "1天 1小时后刷新", "天数倒计时错误")
        expect(QuotaFormatting.countdown(until: now.addingTimeInterval(-1), now: now) == "等待刷新", "过期时间处理错误")
        expect(QuotaFormatting.countdown(until: nil, now: now) == "刷新时间未知", "缺失时间处理错误")
    }

    check("诊断摘要会隐藏凭证和用户目录") {
        let summary = DiagnosticSummary.redacted(
            #"token=very-secret-value Bearer abc.def sk-example123 {"access_token":"json-secret","password":"two words"} /Users/tester/.codex/auth.json"#,
            homeDirectory: URL(fileURLWithPath: "/Users/tester")
        )
        expect(!summary.contains("very-secret-value"), "token 未脱敏")
        expect(!summary.contains("abc.def"), "Bearer token 未脱敏")
        expect(!summary.contains("sk-example123"), "API key 未脱敏")
        expect(!summary.contains("json-secret"), "JSON token 未脱敏")
        expect(!summary.contains("two words"), "带空格的 JSON 密码未脱敏")
        expect(!summary.contains("/Users/tester"), "用户目录未脱敏")
        expect(summary.contains("~/.codex/auth.json"), "用户目录应替换为波浪号")
    }

    check("只有连接级错误要求重启") {
        expect(CodexAppServerError.initializationTimedOut(nil).requiresConnectionRestart, "初始化超时应重启")
        expect(CodexAppServerError.rateLimitRequestTimedOut(nil).requiresConnectionRestart, "刷新超时应重启")
        expect(!CodexAppServerError.protocolError("请求失败").requiresConnectionRestart, "普通协议错误不应重启")
    }
}
