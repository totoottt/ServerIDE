import Foundation

struct ServerMetricsService {
    func fetch(for server: ServerProfile) async throws -> ServerMetrics {
        let command = #"""
printf 'HOST\t'; hostname 2>/dev/null || printf '-'; printf '\n'
printf 'OS\t'; (. /etc/os-release 2>/dev/null && printf '%s' "$PRETTY_NAME") || uname -s; printf '\n'
printf 'KERNEL\t'; uname -r 2>/dev/null || printf '-'; printf '\n'
printf 'UPTIME\t'; uptime -p 2>/dev/null || printf '-'; printf '\n'
printf 'CORES\t'; getconf _NPROCESSORS_ONLN 2>/dev/null || printf '0'; printf '\n'
printf 'LOAD\t'; cat /proc/loadavg 2>/dev/null | awk '{print $1" "$2" "$3}'; printf '\n'
printf 'CPU\t'; awk '/^cpu / {total=0; for(i=2;i<=9;i++) total+=$i; printf "%.0f %.0f",total-$5-$6,total}' /proc/stat; printf '\n'
printf 'MEM\t'; awk '/MemTotal:/{t=$2*1024}/MemAvailable:/{a=$2*1024}END{printf "%.0f %.0f",t-a,t}' /proc/meminfo 2>/dev/null; printf '\n'
printf 'SWAP\t'; awk '/SwapTotal:/{t=$2*1024}/SwapFree:/{f=$2*1024}END{printf "%.0f %.0f",t-f,t}' /proc/meminfo 2>/dev/null; printf '\n'
printf 'DISK\t'; df -B1 / 2>/dev/null | awk 'NR==2{print $3" "$2}'; printf '\n'
printf 'NET\t'; awk -F'[: ]+' 'NR>2 && $2!="lo" {rx+=$3; tx+=$11} END{printf "%.0f %.0f",rx,tx}' /proc/net/dev 2>/dev/null; printf '\n'
"""#
        let output = try await SSHConnectionManager.shared.execute(command, on: server)
        return parse(output)
    }

    func parse(_ output: String) -> ServerMetrics {
        var metrics = ServerMetrics()
        for line in output.split(whereSeparator: { $0.isNewline }) {
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = String(parts[0])
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            let numbers = value.split(separator: " ")
            switch key {
            case "HOST": metrics.hostname = value
            case "OS": metrics.operatingSystem = value
            case "KERNEL": metrics.kernel = value
            case "UPTIME": metrics.uptime = value.replacingOccurrences(of: "up ", with: "")
            case "CORES": metrics.cpuCores = Int(value) ?? 0
            case "LOAD":
                if numbers.count >= 3 {
                    metrics.load1 = Double(numbers[0]) ?? 0
                    metrics.load5 = Double(numbers[1]) ?? 0
                    metrics.load15 = Double(numbers[2]) ?? 0
                }
            case "CPU":
                if numbers.count >= 2 {
                    metrics.cpuBusyTicks = UInt64(numbers[0]) ?? 0
                    metrics.cpuTotalTicks = UInt64(numbers[1]) ?? 0
                }
            case "MEM": assignBytes(numbers, used: &metrics.memoryUsedBytes, total: &metrics.memoryTotalBytes)
            case "SWAP": assignBytes(numbers, used: &metrics.swapUsedBytes, total: &metrics.swapTotalBytes)
            case "DISK": assignBytes(numbers, used: &metrics.diskUsedBytes, total: &metrics.diskTotalBytes)
            case "NET":
                if numbers.count >= 2 {
                    metrics.networkRXBytes = UInt64(numbers[0]) ?? 0
                    metrics.networkTXBytes = UInt64(numbers[1]) ?? 0
                }
            default: break
            }
        }
        return metrics
    }

    private func assignBytes(_ values: [Substring], used: inout UInt64, total: inout UInt64) {
        guard values.count >= 2 else { return }
        used = UInt64(values[0]) ?? 0
        total = UInt64(values[1]) ?? 0
    }
}
