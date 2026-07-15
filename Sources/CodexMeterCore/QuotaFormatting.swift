import Foundation

public enum QuotaFormatting {
    public static func countdown(until date: Date?, now: Date) -> String {
        guard let date else {
            return MeterLocalization.text("quota.reset_unknown", fallback: "刷新时间未知")
        }
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        if seconds == 0 {
            return MeterLocalization.text("quota.waiting_for_reset", fallback: "等待刷新")
        }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60

        if days > 0 {
            return MeterLocalization.format(
                "quota.countdown_days",
                fallback: "%d天 %d小时后刷新",
                days,
                hours
            )
        }
        return MeterLocalization.format(
            "quota.countdown_time",
            fallback: "%d:%02d:%02d 后刷新",
            hours,
            minutes,
            remainingSeconds
        )
    }

    public static func localTime(_ date: Date?, timeZone: TimeZone = .current) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.dateFormat = MeterLocalization.text(
            "quota.date_format",
            fallback: "M月d日 HH:mm"
        )
        return formatter.string(from: date)
    }

    public static func relativeUpdateTime(from date: Date?, now: Date) -> String {
        guard let date else {
            return MeterLocalization.text("update.never", fallback: "尚未更新")
        }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 5 {
            return MeterLocalization.text("update.just_now", fallback: "刚刚更新")
        }
        if seconds < 60 {
            return MeterLocalization.format(
                "update.seconds_ago",
                fallback: "%d 秒前更新",
                seconds
            )
        }
        return MeterLocalization.format(
            "update.minutes_ago",
            fallback: "%d 分钟前更新",
            seconds / 60
        )
    }
}
