import Foundation

public enum CodexPathResolver {
    public static func candidateURLs(
        persistedPath: String?,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        var candidates: [URL] = []
        if let persistedPath, !persistedPath.isEmpty {
            candidates.append(URL(fileURLWithPath: persistedPath))
        }
        candidates.append(homeDirectory.appendingPathComponent(".local/bin/codex"))
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/codex"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/codex"))
        candidates.append(URL(fileURLWithPath: "/usr/bin/codex"))

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    public static func resolve(
        persistedPath: String?,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)
    ) -> URL? {
        candidateURLs(persistedPath: persistedPath, homeDirectory: homeDirectory)
            .first { isExecutable($0.path) }
    }
}
