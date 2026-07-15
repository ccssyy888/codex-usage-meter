import Foundation

private var failureCount = 0

struct ValidationFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #fileID,
    line: UInt = #line
) {
    guard !condition() else { return }
    failureCount += 1
    print("  ✗ \(message) [\(file):\(line)]")
}

func require<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw ValidationFailure(description: message) }
    return value
}

func check(_ name: String, _ body: () throws -> Void) {
    let failuresBefore = failureCount
    do {
        try body()
    } catch {
        failureCount += 1
        print("  ✗ \(name)：\(error)")
        return
    }
    if failureCount == failuresBefore {
        print("  ✓ \(name)")
    }
}

runRateLimitTests()
runProtocolAndFormattingTests()

if failureCount > 0 {
    print("\n验证失败：\(failureCount) 项")
    exit(1)
}

print("\n全部核心验证通过。")
