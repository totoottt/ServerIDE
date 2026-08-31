import Foundation
import Combine

/// Persists remote file downloads so leaving an SSH screen does not cancel a
/// transfer. If iOS terminates the app, the next launch resumes from the saved
/// partial file rather than downloading the file again from byte zero.
@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    enum State: String, Codable { case queued, downloading, paused, completed, failed }

    struct Job: Identifiable, Codable, Equatable {
        let id: UUID
        let server: ServerProfile
        let remotePath: String
        let remoteName: String
        let expectedBytes: UInt64
        var receivedBytes: UInt64
        var state: State
        var error: String?
        var localFileName: String

        var progress: Double {
            guard expectedBytes > 0 else { return 0 }
            return min(1, Double(receivedBytes) / Double(expectedBytes))
        }
    }

    @Published private(set) var jobs: [Job] = []
    private var active: Set<UUID> = []
    private let storageKey = "serveride.download-jobs.v1"
    private let chunkBytes = 384 * 1024

    private init() {
        load()
        for index in jobs.indices where jobs[index].state == .downloading || jobs[index].state == .queued {
            jobs[index].state = .queued
        }
        save()
    }

    func job(for remotePath: String, server: ServerProfile) -> Job? {
        jobs.first { $0.server.id == server.id && $0.remotePath == remotePath && $0.state != .completed }
    }

    func enqueue(_ file: RemoteFile, server: ServerProfile) {
        guard !file.isDirectory else { return }
        if let existing = job(for: file.path, server: server) {
            resume(existing.id)
            return
        }
        guard let size = file.size, size > 0 else {
            // A zero-byte file is still downloaded once and then finalized.
            let job = makeJob(file, server: server, size: 0)
            jobs.insert(job, at: 0)
            save()
            resume(job.id)
            return
        }
        let job = makeJob(file, server: server, size: size)
        jobs.insert(job, at: 0)
        save()
        resume(job.id)
    }

    func resumePending() {
        for job in jobs where job.state == .queued || job.state == .paused || job.state == .failed {
            resume(job.id)
        }
    }

    func resume(_ id: UUID) {
        guard !active.contains(id), let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        active.insert(id)
        jobs[index].state = .downloading
        jobs[index].error = nil
        save()
        Task { [weak self] in await self?.download(id) }
    }

    func pause(_ id: UUID) {
        active.remove(id)
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].state = .paused
        save()
    }

    func remove(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        active.remove(id)
        try? FileManager.default.removeItem(at: partialURL(for: jobs[index]))
        jobs.remove(at: index)
        save()
    }

    func completedURL(for job: Job) -> URL {
        downloadsFolder().appendingPathComponent(job.localFileName)
    }

    private func download(_ id: UUID) async {
        defer { active.remove(id) }
        do {
            while active.contains(id), let index = jobs.firstIndex(where: { $0.id == id }) {
                var job = jobs[index]
                let partial = partialURL(for: job)
                try FileManager.default.createDirectory(at: downloadsFolder(), withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: partial.path) {
                    FileManager.default.createFile(atPath: partial.path, contents: nil)
                }
                let diskBytes = UInt64((try? partial.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                if diskBytes != job.receivedBytes {
                    job.receivedBytes = diskBytes
                    jobs[index] = job
                    save()
                }
                if job.receivedBytes >= job.expectedBytes {
                    try finalize(index: index)
                    return
                }
                let count = Int(min(UInt64(chunkBytes), job.expectedBytes - job.receivedBytes))
                let reply = try await RemoteFileBridge.readChunk(
                    path: job.remotePath, offset: job.receivedBytes, count: count, server: job.server
                )
                guard let encoded = reply.data, let data = Data(base64Encoded: encoded), !data.isEmpty else {
                    throw RemoteFileFailure(message: "The server returned an empty download chunk.")
                }
                let handle: FileHandle
                if FileManager.default.fileExists(atPath: partial.path) {
                    handle = try FileHandle(forWritingTo: partial)
                    try handle.seekToEnd()
                } else { handle = try FileHandle(forWritingTo: partial) }
                try handle.write(contentsOf: data)
                try handle.close()
                job.receivedBytes += UInt64(data.count)
                if job.receivedBytes > job.expectedBytes {
                    throw RemoteFileFailure(message: "The remote file changed while downloading. Restart the download.")
                }
                jobs[index] = job
                save()
            }
        } catch {
            guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
            jobs[index].state = .failed
            jobs[index].error = error.localizedDescription
            save()
        }
    }

    private func finalize(index: Int) throws {
        let job = jobs[index]
        let final = completedURL(for: job)
        let partial = partialURL(for: job)
        if FileManager.default.fileExists(atPath: final.path) {
            try FileManager.default.removeItem(at: final)
        }
        try FileManager.default.moveItem(at: partial, to: final)
        jobs[index].state = .completed
        jobs[index].receivedBytes = jobs[index].expectedBytes
        jobs[index].error = nil
        save()
    }

    private func makeJob(_ file: RemoteFile, server: ServerProfile, size: UInt64) -> Job {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return Job(id: UUID(), server: server, remotePath: file.path, remoteName: file.name,
                   expectedBytes: size, receivedBytes: 0, state: .queued, error: nil,
                   localFileName: "\(stamp)-\(file.name)")
    }

    private func downloadsFolder() -> URL {
        (try? LocalFilesStore.downloads()) ?? FileManager.default.temporaryDirectory
    }

    private func partialURL(for job: Job) -> URL {
        downloadsFolder().appendingPathComponent(".\(job.id.uuidString).part")
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([Job].self, from: data) else { return }
        jobs = saved
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(jobs) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
