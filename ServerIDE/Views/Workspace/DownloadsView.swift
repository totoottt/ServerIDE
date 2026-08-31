import SwiftUI

struct DownloadsView: View {
    @ObservedObject private var manager = DownloadManager.shared

    var body: some View {
        List {
            Section {
                Text("Downloads continue when you leave the SSH screen. If iOS closes the app, open ServerIDE again and the unfinished item resumes from its saved progress.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(manager.jobs) { job in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: job.state == .completed ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .foregroundStyle(job.state == .failed ? Color.red : Color.accentColor)
                        Text(job.remoteName).lineLimit(1)
                        Spacer()
                        Text(job.state.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                    }
                    if job.state != .completed {
                        ProgressView(value: job.progress)
                        Text("\(ByteCountFormatter.string(fromByteCount: Int64(job.receivedBytes), countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: Int64(job.expectedBytes), countStyle: .file)) · \(Int(job.progress * 100))%")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    } else {
                        Text("Saved in Files → On My iPhone → ServerIDE → Downloads")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = job.error { Text(error).font(.caption).foregroundStyle(.red) }
                    HStack {
                        if job.state != .completed {
                            Button(job.state == .downloading ? "Pause" : "Resume") {
                                if job.state == .downloading { manager.pause(job.id) } else { manager.resume(job.id) }
                            }
                        }
                        Button("Remove", role: .destructive) { manager.remove(job.id) }
                    }.font(.caption)
                }.padding(.vertical, 4)
            }
            if manager.jobs.isEmpty { Text("No downloads yet.").foregroundStyle(.secondary) }
        }
        .navigationTitle("Downloads")
        .onAppear { manager.resumePending() }
    }
}
