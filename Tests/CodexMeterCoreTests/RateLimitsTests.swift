import CodexMeterCore
import Foundation

func runRateLimitTests() {
    check("解析当前额度响应并选择 codex 主桶") {
        let data = Data(
            """
            {
              "rateLimits": {
                "limitId": "codex",
                "primary": {"usedPercent": 6, "windowDurationMins": 300, "resetsAt": 2000},
                "secondary": {"usedPercent": 1, "windowDurationMins": 10080, "resetsAt": 9000},
                "credits": {"hasCredits": false, "unlimited": false, "balance": "0"},
                "planType": "prolite",
                "rateLimitReachedType": null
              },
              "rateLimitsByLimitId": {
                "codex_bengalfox": {
                  "limitId": "codex_bengalfox",
                  "primary": {"usedPercent": 99, "windowDurationMins": 300, "resetsAt": 2000}
                },
                "codex": {
                  "limitId": "codex",
                  "primary": {"usedPercent": 6, "windowDurationMins": 300, "resetsAt": 2000}
                }
              },
              "rateLimitResetCredits": {
                "availableCount": 3,
                "credits": [
                  {"id": "credit-1", "title": "Full reset", "description": null, "expiresAt": 5000},
                  {"id": "credit-2", "title": "Full reset", "description": null, "expiresAt": 6000},
                  {"id": "credit-3", "title": "Full reset", "description": null, "expiresAt": 7000}
                ]
              }
            }
            """.utf8
        )
        let parsed = try RateLimitsResponseParser.parseReadResult(
            data,
            now: Date(timeIntervalSince1970: 1000)
        )
        expect(parsed.snapshot.limitID == "codex", "应选择 codex 主桶")
        expect(parsed.snapshot.primary?.remainingPercent == 94, "5 小时额度计算错误")
        expect(parsed.snapshot.secondary?.remainingPercent == 99, "周额度计算错误")
        expect(parsed.snapshot.planType == "prolite", "计划类型解析错误")
        expect(parsed.snapshot.credits?.balance == "0", "积分余额解析错误")
        expect(parsed.resetCredits?.availableCount == 3, "availableCount 应为权威总数")
        expect(parsed.resetCredits?.creditsForDisplay.count == 3, "每张重置券都应保留用于显示")
        expect(
            parsed.resetCredits?.creditsForDisplay.compactMap { $0?.expiresAt } == [5000, 6000, 7000].map(Date.init(timeIntervalSince1970:)),
            "每张重置券的到期时间解析错误"
        )
    }

    check("支持缺失周额度和只有数量的重置券") {
        let data = Data(
            """
            {
              "rateLimitsByLimitId": {
                "codex": {
                  "limitId": "codex",
                  "primary": {"usedPercent": 25, "windowDurationMins": 300, "resetsAt": null},
                  "secondary": null,
                  "credits": {"hasCredits": true, "unlimited": true, "balance": null}
                }
              },
              "rateLimitResetCredits": {"availableCount": 2, "credits": null}
            }
            """.utf8
        )
        let parsed = try RateLimitsResponseParser.parseReadResult(data)
        expect(parsed.snapshot.primary?.remainingPercent == 75, "剩余比例错误")
        expect(parsed.snapshot.secondary == nil, "缺失的周额度应保持 nil")
        expect(parsed.snapshot.credits?.unlimited == true, "无限积分标记错误")
        expect(parsed.resetCredits?.availableCount == 2, "重置券总数错误")
        expect(parsed.resetCredits?.credits == nil, "只有总数时明细应为 nil")
        expect(parsed.resetCredits?.creditsForDisplay.count == 2, "缺失明细时仍应按总数显示重置券")
        expect(parsed.resetCredits?.creditsForDisplay.allSatisfy { $0 == nil } == true, "缺失明细的到期时间应保持未知")
    }

    check("剩余百分比会钳制在 0 到 100") {
        expect(RateLimitWindow(usedPercent: -20, windowDurationMins: nil, resetsAt: nil).remainingPercent == 100, "上限钳制失败")
        expect(RateLimitWindow(usedPercent: 140, windowDurationMins: nil, resetsAt: nil).remainingPercent == 0, "下限钳制失败")
    }

    check("稀疏通知会保留未更新字段") {
        let base = RateLimitSnapshot(
            limitID: "codex",
            primary: RateLimitWindow(usedPercent: 10, windowDurationMins: 300, resetsAt: nil),
            secondary: RateLimitWindow(usedPercent: 20, windowDurationMins: 10080, resetsAt: nil),
            credits: nil,
            planType: "pro",
            reachedType: nil,
            fetchedAt: Date(timeIntervalSince1970: 1)
        )
        let updateData = Data(
            #"{"rateLimits":{"limitId":"codex","primary":{"usedPercent":30,"windowDurationMins":300,"resetsAt":3000}}}"#.utf8
        )
        let update = try RateLimitsResponseParser.parseUpdateParams(updateData, now: Date(timeIntervalSince1970: 2))
        let merged = base.merging(update)
        expect(merged.primary?.remainingPercent == 70, "主窗口未更新")
        expect(merged.secondary?.remainingPercent == 80, "次窗口不应被清空")
        expect(merged.planType == "pro", "计划类型不应被清空")
        expect(merged.fetchedAt == Date(timeIntervalSince1970: 2), "更新时间错误")

        let metadataOnly = RateLimitSnapshot(
            limitID: "codex",
            primary: nil,
            secondary: nil,
            credits: nil,
            planType: "business",
            reachedType: nil,
            fetchedAt: Date(timeIntervalSince1970: 3)
        )
        let metadataMerged = base.merging(metadataOnly)
        expect(metadataMerged.planType == "business", "元数据应被合并")
        expect(metadataMerged.fetchedAt == base.fetchedAt, "元数据更新不应刷新额度时间")
    }

    check("重置券按到期时间排序并把未知项放最后") {
        let credits = ResetCreditsSnapshot(
            availableCount: 4,
            credits: [
                ResetCredit(id: "late", title: nil, description: nil, expiresAt: Date(timeIntervalSince1970: 6000)),
                ResetCredit(id: "unknown", title: nil, description: nil, expiresAt: nil),
                ResetCredit(id: "early", title: nil, description: nil, expiresAt: Date(timeIntervalSince1970: 5000)),
            ]
        )
        expect(
            credits.creditsForDisplay.map { $0?.id } == ["early", "late", "unknown", nil],
            "重置券排序错误"
        )
    }

    check("只把 codex 桶识别为主额度") {
        let codex = RateLimitSnapshot(
            limitID: "codex",
            primary: nil,
            secondary: nil,
            credits: nil,
            planType: nil,
            reachedType: nil,
            fetchedAt: Date()
        )
        let legacy = RateLimitSnapshot(
            limitID: nil,
            primary: nil,
            secondary: nil,
            credits: nil,
            planType: nil,
            reachedType: nil,
            fetchedAt: Date()
        )
        let otherModel = RateLimitSnapshot(
            limitID: "codex_bengalfox",
            primary: nil,
            secondary: nil,
            credits: nil,
            planType: nil,
            reachedType: nil,
            fetchedAt: Date()
        )
        expect(codex.isMainCodexLimit, "codex 应被识别为主额度")
        expect(!legacy.isMainCodexLimit, "稀疏通知缺失 limitId 时应忽略，避免误合并其他桶")
        expect(!otherModel.isMainCodexLimit, "其他模型额度不应覆盖主额度")

        let otherOnly = Data(
            #"{"rateLimits":{"limitId":"codex_other","primary":{"usedPercent":99}}}"#.utf8
        )
        do {
            _ = try RateLimitsResponseParser.parseReadResult(otherOnly)
            expect(false, "没有 codex 桶时不应退回其他模型额度")
        } catch is RateLimitsParsingError {
            // Expected.
        }
    }
}
