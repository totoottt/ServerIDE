import Foundation

struct ServerMetrics: Equatable {
    var hostname = "—"
    var operatingSystem = "—"
    var kernel = "—"
    var uptime = "—"
    var cpuCores = 0
    var load1 = 0.0
    var load5 = 0.0
    var load15 = 0.0
    var memoryUsedBytes: UInt64 = 0
    var memoryTotalBytes: UInt64 = 0
    var swapUsedBytes: UInt64 = 0
    var swapTotalBytes: UInt64 = 0
    var diskUsedBytes: UInt64 = 0
    var diskTotalBytes: UInt64 = 0
    var networkRXBytes: UInt64 = 0
    var networkTXBytes: UInt64 = 0
    var cpuBusyTicks: UInt64 = 0
    var cpuTotalTicks: UInt64 = 0

    var memoryFraction: Double { fraction(memoryUsedBytes, memoryTotalBytes) }
    var swapFraction: Double { fraction(swapUsedBytes, swapTotalBytes) }
    var diskFraction: Double { fraction(diskUsedBytes, diskTotalBytes) }
    var loadFraction: Double { cpuCores > 0 ? min(max(load1 / Double(cpuCores), 0), 1) : 0 }

    private func fraction(_ used: UInt64, _ total: UInt64) -> Double {
        guard total > 0 else { return 0 }
        return min(max(Double(used) / Double(total), 0), 1)
    }
}
