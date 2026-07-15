import Foundation

public enum AppServerProtocol {
    public static func initializeRequest(id: Int = 0, clientVersion: String) throws -> Data {
        try encode([
            "method": "initialize",
            "id": id,
            "params": [
                "clientInfo": [
                    "name": "codex_usage_meter",
                    "title": "Codex Usage Meter",
                    "version": clientVersion,
                ],
            ],
        ])
    }

    public static func initializedNotification() throws -> Data {
        try encode(["method": "initialized"])
    }

    public static func rateLimitsRequest(id: Int) throws -> Data {
        try encode([
            "method": "account/rateLimits/read",
            "id": id,
        ])
    }

    private static func encode(_ object: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        data.append(0x0A)
        return data
    }
}

public enum ReconnectPolicy {
    private static let delays: [TimeInterval] = [1, 2, 5, 15, 30]

    public static func delay(forAttempt attempt: Int) -> TimeInterval {
        delays[min(max(0, attempt), delays.count - 1)]
    }
}
