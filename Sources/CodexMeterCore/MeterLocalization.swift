import Foundation

public enum MeterLocalization {
    public static func text(_ key: String, fallback: String) -> String {
        Bundle.main.localizedString(forKey: key, value: fallback, table: nil)
    }

    public static func format(_ key: String, fallback: String, _ arguments: CVarArg...) -> String {
        String(
            format: text(key, fallback: fallback),
            locale: Locale.current,
            arguments: arguments
        )
    }
}
