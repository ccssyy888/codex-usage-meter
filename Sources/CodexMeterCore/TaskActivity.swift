import Darwin
import Foundation

/// Looks only at rollout files held open by live Codex processes. No directory
/// crawl, credential access, app-server attachment, or changes to running tasks.
public enum CodexSessionFiles {
    public static func openFiles(executableURL: URL? = nil) -> Set<URL> {
        let capacity = max(256, Int(proc_listallpids(nil, 0)) + 128)
        var pids = [pid_t](repeating: 0, count: capacity)
        let count = pids.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        var result = Set<URL>()
        for pid in pids.prefix(max(0, min(Int(count), capacity))) where pid > 0 {
            var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            let length = path.withUnsafeMutableBytes {
                proc_pidpath(pid, $0.baseAddress, UInt32($0.count))
            }
            guard length > 0 else { continue }
            let executable = URL(fileURLWithPath: String(cString: path))
            guard executable.lastPathComponent == "codex"
                || executable == executableURL?.resolvingSymlinksInPath() else { continue }

            let size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
            guard size > 0 else { continue }
            var descriptors = [proc_fdinfo](
                repeating: proc_fdinfo(),
                count: Int(size) / MemoryLayout<proc_fdinfo>.stride + 64
            )
            let bytes = descriptors.withUnsafeMutableBytes {
                proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count))
            }
            for descriptor in descriptors.prefix(max(0, Int(bytes) / MemoryLayout<proc_fdinfo>.stride))
                where descriptor.proc_fdtype == PROX_FDTYPE_VNODE {
                var info = vnode_fdinfowithpath()
                let read = proc_pidfdinfo(
                    pid, descriptor.proc_fd, PROC_PIDFDVNODEPATHINFO,
                    &info, Int32(MemoryLayout.size(ofValue: info))
                )
                guard read == MemoryLayout.size(ofValue: info),
                      info.pfi.fi_openflags & UInt32(FWRITE) != 0 else { continue }
                let filename = withUnsafePointer(to: &info.pvip.vip_path) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                        String(cString: $0)
                    }
                }
                let url = URL(fileURLWithPath: filename)
                if url.pathComponents.contains("sessions"),
                   url.lastPathComponent.hasPrefix("rollout-"), url.pathExtension == "jsonl" {
                    result.insert(url)
                }
            }
        }
        return result
    }
}

public struct TaskActivityState {
    public private(set) var activeTurnID: String?
    private var pending = Data()
    private var discardingOversizedLine = false
    private static let maximumLineBytes = 4 * 1_024 * 1_024

    public init() {}

    public mutating func append(_ data: Data) {
        for part in data.split(separator: 0x0A, omittingEmptySubsequences: false).enumerated() {
            if part.offset > 0 {
                if !discardingOversizedLine { consumeLine(pending) }
                pending.removeAll(keepingCapacity: true)
                discardingOversizedLine = false
            }
            guard !discardingOversizedLine else { continue }
            if pending.count + part.element.count > Self.maximumLineBytes {
                pending.removeAll(keepingCapacity: true)
                discardingOversizedLine = true
            } else {
                pending.append(contentsOf: part.element)
            }
        }
    }

    private mutating func consumeLine(_ data: Data) {
        // Decode only lifecycle candidates, ignoring message text and tool data.
        guard ["task_started", "task_complete", "turn_aborted"].contains(where: {
            data.range(of: Data($0.utf8)) != nil
        }), let event = try? JSONDecoder().decode(LifecycleRecord.self, from: data),
              event.type == "event_msg" else { return }
        switch event.payload.type {
        case "task_started":
            if let turnID = event.payload.turn_id, !turnID.isEmpty { activeTurnID = turnID }
        case "task_complete", "turn_aborted":
            if event.payload.turn_id == nil || event.payload.turn_id == activeTurnID {
                activeTurnID = nil
            }
        default:
            break
        }
    }
}

private struct LifecycleRecord: Decodable {
    let type: String
    let payload: Payload
    struct Payload: Decodable {
        let type: String
        let turn_id: String?
    }
}

/// Keeps only offsets and lifecycle state in memory. On first encounter it reads
/// the open file to establish the current turn; later polls read appended bytes.
public struct TaskActivityTracker {
    private struct FileState {
        var inode: UInt64
        var offset: UInt64 = 0
        var checkpoint: UInt64?
        var modifiedSeconds: Int?
        var modifiedNanoseconds: Int?
        var activity = TaskActivityState()
    }
    private var files: [URL: FileState] = [:]

    public init() {}

    public mutating func poll(openFiles: Set<URL>) -> Bool {
        files = files.filter { openFiles.contains($0.key) }
        for url in openFiles {
            do {
                // Never follow a replaced leaf symlink or block on a special file.
                let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
                guard descriptor >= 0 else {
                    files.removeValue(forKey: url)
                    continue
                }
                let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
                defer { try? handle.close() }
                var info = stat()
                guard fstat(descriptor, &info) == 0, info.st_size >= 0,
                      info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
                      info.st_uid == geteuid() else {
                    files.removeValue(forKey: url)
                    continue
                }
                let end = UInt64(info.st_size)
                let inode = UInt64(info.st_ino)
                var state = files[url] ?? FileState(inode: inode)
                if state.inode != inode || end < state.offset { state = FileState(inode: inode) }
                if state.offset == end,
                   state.modifiedSeconds == info.st_mtimespec.tv_sec,
                   state.modifiedNanoseconds == info.st_mtimespec.tv_nsec {
                    continue // Unchanged files require no content reads.
                }
                if let previous = state.checkpoint,
                   try checkpoint(handle, offset: state.offset) != previous {
                    state = FileState(inode: inode)
                }
                try handle.seek(toOffset: state.offset)
                while state.offset < end {
                    let bytes = try handle.read(upToCount: Int(min(65_536, end - state.offset))) ?? Data()
                    guard !bytes.isEmpty else { break }
                    state.activity.append(bytes)
                    state.offset += UInt64(bytes.count)
                }
                state.checkpoint = try checkpoint(handle, offset: state.offset)
                state.modifiedSeconds = info.st_mtimespec.tv_sec
                state.modifiedNanoseconds = info.st_mtimespec.tv_nsec
                files[url] = state
            } catch {
                files.removeValue(forKey: url)
            }
        }
        return files.values.contains { $0.activity.activeTurnID != nil }
    }

    /// Detect truncation followed by regrowth between polls without retaining text.
    private func checkpoint(_ handle: FileHandle, offset: UInt64) throws -> UInt64 {
        let length = min(64, offset)
        try handle.seek(toOffset: offset - length)
        let data = try handle.read(upToCount: Int(length)) ?? Data()
        return data.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
}
