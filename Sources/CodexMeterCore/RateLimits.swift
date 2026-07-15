import Foundation

public struct RateLimitWindow: Codable, Equatable, Sendable {
    public let usedPercent: Double
    public let windowDurationMins: Int?
    public let resetsAt: Date?

    public init(usedPercent: Double, windowDurationMins: Int?, resetsAt: Date?) {
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }

    public var remainingPercent: Int {
        min(100, max(0, Int((100 - usedPercent).rounded())))
    }
}

public struct CreditsBalance: Codable, Equatable, Sendable {
    public let hasCredits: Bool
    public let unlimited: Bool
    public let balance: String?

    public init(hasCredits: Bool, unlimited: Bool, balance: String?) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }
}

public struct RateLimitSnapshot: Codable, Equatable, Sendable {
    public let limitID: String?
    public let primary: RateLimitWindow?
    public let secondary: RateLimitWindow?
    public let credits: CreditsBalance?
    public let planType: String?
    public let reachedType: String?
    public let fetchedAt: Date

    public init(
        limitID: String?,
        primary: RateLimitWindow?,
        secondary: RateLimitWindow?,
        credits: CreditsBalance?,
        planType: String?,
        reachedType: String?,
        fetchedAt: Date
    ) {
        self.limitID = limitID
        self.primary = primary
        self.secondary = secondary
        self.credits = credits
        self.planType = planType
        self.reachedType = reachedType
        self.fetchedAt = fetchedAt
    }

    public func merging(_ update: RateLimitSnapshot) -> RateLimitSnapshot {
        RateLimitSnapshot(
            limitID: update.limitID ?? limitID,
            primary: update.primary ?? primary,
            secondary: update.secondary ?? secondary,
            credits: update.credits ?? credits,
            planType: update.planType ?? planType,
            reachedType: update.reachedType ?? reachedType,
            fetchedAt: update.hasQuotaWindowUpdate ? update.fetchedAt : fetchedAt
        )
    }

    public var hasQuotaWindowUpdate: Bool {
        primary != nil || secondary != nil
    }

    public var isMainCodexLimit: Bool {
        limitID == "codex"
    }
}

public struct ResetCredit: Codable, Equatable, Sendable {
    public let id: String
    public let title: String?
    public let description: String?
    public let expiresAt: Date?

    public init(id: String, title: String?, description: String?, expiresAt: Date?) {
        self.id = id
        self.title = title
        self.description = description
        self.expiresAt = expiresAt
    }
}

public struct ResetCreditsSnapshot: Codable, Equatable, Sendable {
    public let availableCount: Int
    public let credits: [ResetCredit]?

    public init(availableCount: Int, credits: [ResetCredit]?) {
        self.availableCount = availableCount
        self.credits = credits
    }

    public var creditsForDisplay: [ResetCredit?] {
        guard availableCount > 0 else { return [] }
        let knownCredits = Array(
            (credits ?? [])
                .sorted(by: Self.expiresSooner)
                .prefix(availableCount)
        )
        let missingCount = availableCount - knownCredits.count
        return knownCredits.map(Optional.some) + Array(repeating: nil, count: missingCount)
    }

    private static func expiresSooner(_ lhs: ResetCredit, _ rhs: ResetCredit) -> Bool {
        switch (lhs.expiresAt, rhs.expiresAt) {
        case let (left?, right?):
            if left == right { return lhs.id < rhs.id }
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.id < rhs.id
        }
    }
}

private struct RateLimitWindowPayload: Decodable {
    let usedPercent: Double?
    let windowDurationMins: Int?
    let resetsAt: TimeInterval?

    var value: RateLimitWindow? {
        guard let usedPercent else { return nil }
        return RateLimitWindow(
            usedPercent: usedPercent,
            windowDurationMins: windowDurationMins,
            resetsAt: resetsAt.map(Date.init(timeIntervalSince1970:))
        )
    }
}

private struct CreditsPayload: Decodable {
    let hasCredits: Bool?
    let unlimited: Bool?
    let balance: String?

    var value: CreditsBalance? {
        guard hasCredits != nil || unlimited != nil || balance != nil else { return nil }
        return CreditsBalance(
            hasCredits: hasCredits ?? false,
            unlimited: unlimited ?? false,
            balance: balance
        )
    }
}

private struct RateLimitPayload: Decodable {
    let limitId: String?
    let primary: RateLimitWindowPayload?
    let secondary: RateLimitWindowPayload?
    let credits: CreditsPayload?
    let planType: String?
    let rateLimitReachedType: String?

    func value(now: Date) -> RateLimitSnapshot {
        RateLimitSnapshot(
            limitID: limitId,
            primary: primary?.value,
            secondary: secondary?.value,
            credits: credits?.value,
            planType: planType,
            reachedType: rateLimitReachedType,
            fetchedAt: now
        )
    }
}

private struct ResetCreditPayload: Decodable {
    let id: String
    let title: String?
    let description: String?
    let expiresAt: TimeInterval?

    var value: ResetCredit {
        ResetCredit(
            id: id,
            title: title,
            description: description,
            expiresAt: expiresAt.map(Date.init(timeIntervalSince1970:))
        )
    }
}

private struct ResetCreditsPayload: Decodable {
    let availableCount: Int
    let credits: [ResetCreditPayload]?

    var value: ResetCreditsSnapshot {
        ResetCreditsSnapshot(
            availableCount: availableCount,
            credits: credits?.map(\.value)
        )
    }
}

private struct ReadResultPayload: Decodable {
    let rateLimits: RateLimitPayload?
    let rateLimitsByLimitId: [String: RateLimitPayload]?
    let rateLimitResetCredits: ResetCreditsPayload?
}

private struct UpdateParamsPayload: Decodable {
    let rateLimits: RateLimitPayload
}

public enum RateLimitsParsingError: LocalizedError {
    case missingMainLimit

    public var errorDescription: String? {
        switch self {
        case .missingMainLimit:
            return MeterLocalization.text(
                "error.missing_main_limit",
                fallback: "Codex 返回的数据中没有主额度信息。"
            )
        }
    }
}

public enum RateLimitsResponseParser {
    public static func parseReadResult(
        _ data: Data,
        now: Date = Date()
    ) throws -> (snapshot: RateLimitSnapshot, resetCredits: ResetCreditsSnapshot?) {
        let result = try JSONDecoder().decode(ReadResultPayload.self, from: data)
        let main = preferredMainLimit(result)
        guard let main else { throw RateLimitsParsingError.missingMainLimit }
        return (main.value(now: now), result.rateLimitResetCredits?.value)
    }

    public static func parseUpdateParams(
        _ data: Data,
        now: Date = Date()
    ) throws -> RateLimitSnapshot {
        let update = try JSONDecoder().decode(UpdateParamsPayload.self, from: data)
        return update.rateLimits.value(now: now)
    }

    private static func preferredMainLimit(_ result: ReadResultPayload) -> RateLimitPayload? {
        if let direct = result.rateLimits,
           direct.limitId == nil || direct.limitId == "codex" {
            return direct
        }
        return result.rateLimitsByLimitId?["codex"]
    }
}
