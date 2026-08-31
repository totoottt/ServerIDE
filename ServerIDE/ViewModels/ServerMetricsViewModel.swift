import Foundation

@MainActor
final class ServerMetricsViewModel: ObservableObject {
    struct Sample: Identifiable {
        let id = UUID()
        let time: Date
        let memoryPercent: Double
        let cpuPercent: Double?
        let downloadBytesPerSecond: Double?
        let uploadBytesPerSecond: Double?
    }
    @Published var samples: [Sample] = []
    @Published var metrics = ServerMetrics()
    @Published var isLoading = false
    @Published var errorMessage: String?
    let server: ServerProfile

    init(server: ServerProfile) { self.server = server }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let next = try await ServerMetricsService().fetch(for: server)
                let now = Date()
                let elapsed = samples.last.map { now.timeIntervalSince($0.time) } ?? 0
                let cpu: Double? = elapsed > 0 && next.cpuTotalTicks > metrics.cpuTotalTicks && next.cpuBusyTicks >= metrics.cpuBusyTicks
                    ? min(100, Double(next.cpuBusyTicks - metrics.cpuBusyTicks) / Double(next.cpuTotalTicks - metrics.cpuTotalTicks) * 100) : nil
                let rx: Double? = elapsed > 0 && next.networkRXBytes >= metrics.networkRXBytes ? Double(next.networkRXBytes - metrics.networkRXBytes) / elapsed : nil
                let tx: Double? = elapsed > 0 && next.networkTXBytes >= metrics.networkTXBytes ? Double(next.networkTXBytes - metrics.networkTXBytes) / elapsed : nil
                metrics = next
                samples.append(Sample(time: now, memoryPercent: next.memoryFraction * 100, cpuPercent: cpu,
                                      downloadBytesPerSecond: rx, uploadBytesPerSecond: tx))
                if samples.count > 60 { samples.removeFirst(samples.count - 60) }
            }
            catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }
}
