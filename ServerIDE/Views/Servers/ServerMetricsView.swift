import SwiftUI
import Charts

struct ServerMetricsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var automatic = true
    @StateObject private var model: ServerMetricsViewModel

    init(server: ServerProfile) {
        _model = StateObject(wrappedValue: ServerMetricsViewModel(server: server))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricGauge(title: "Load", value: model.metrics.loadFraction, detail: String(format: "%.2f", model.metrics.load1), icon: "cpu")
                    MetricGauge(title: "Memory", value: model.metrics.memoryFraction, detail: percent(model.metrics.memoryFraction), icon: "memorychip")
                    MetricGauge(title: "Disk", value: model.metrics.diskFraction, detail: percent(model.metrics.diskFraction), icon: "internaldrive")
                    MetricGauge(title: "Swap", value: model.metrics.swapFraction, detail: percent(model.metrics.swapFraction), icon: "arrow.triangle.2.circlepath")
                }
                networkCard
                historyCard
                systemCard
            }
            .padding()
        }
        .navigationTitle("Metrics")
        .background(StudioBackground())
        .toolbar { Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") } }
        .overlay { if model.isLoading && model.metrics.hostname == "—" { ProgressView("Reading server…") } }
        .task(id: automatic && scenePhase == .active) {
            guard scenePhase == .active else { return }
            model.refresh()
            while automatic && !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
                model.refresh()
            }
        }
        .alert("Metrics Error", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(model.errorMessage ?? "Unknown error") }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Refresh every 10 seconds while visible", isOn: $automatic)
            Text("Live CPU & memory samples").font(.headline)
            Chart(model.samples) { sample in
                LineMark(x: .value("Time", sample.time), y: .value("Percent", sample.memoryPercent))
                    .foregroundStyle(by: .value("Metric", "Memory"))
                if let cpu = sample.cpuPercent {
                    LineMark(x: .value("Time", sample.time), y: .value("Percent", cpu))
                        .foregroundStyle(by: .value("Metric", "CPU"))
                }
            }.chartYScale(domain: 0...100).frame(height: 150)
            Text("Network rate · aggregate interfaces").font(.headline)
            Chart(model.samples) { sample in
                if let rx = sample.downloadBytesPerSecond {
                    LineMark(x: .value("Time", sample.time), y: .value("Bytes/s", rx))
                        .foregroundStyle(by: .value("Direction", "Download"))
                }
                if let tx = sample.uploadBytesPerSecond {
                    LineMark(x: .value("Time", sample.time), y: .value("Bytes/s", tx))
                        .foregroundStyle(by: .value("Direction", "Upload"))
                }
            }.frame(height: 130)
            Text("CPU and transfer rates require two samples. Data is read from your server; virtual interfaces may double-count traffic. Charts pause when this view closes or the app leaves the foreground. No background push monitoring.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "server.rack").font(.system(size: 30)).frame(width: 58, height: 58).background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(model.server.name).font(.title2.bold())
                Text("\(model.server.username)@\(model.server.host)").font(.caption.monospaced()).foregroundStyle(.secondary)
                Label(model.metrics.uptime, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Network totals", systemImage: "network").font(.headline)
            HStack {
                Label(ByteCountFormatter.string(fromByteCount: Int64(model.metrics.networkRXBytes), countStyle: .file), systemImage: "arrow.down")
                Spacer()
                Label(ByteCountFormatter.string(fromByteCount: Int64(model.metrics.networkTXBytes), countStyle: .file), systemImage: "arrow.up")
            }.font(.subheadline.monospacedDigit())
        }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var systemCard: some View {
        VStack(spacing: 10) {
            LabeledContent("Hostname", value: model.metrics.hostname)
            LabeledContent("System", value: model.metrics.operatingSystem)
            LabeledContent("Kernel", value: model.metrics.kernel)
            LabeledContent("CPU cores", value: "\(model.metrics.cpuCores)")
            LabeledContent("Load 1 / 5 / 15", value: String(format: "%.2f  %.2f  %.2f", model.metrics.load1, model.metrics.load5, model.metrics.load15))
        }.font(.subheadline).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
}

private struct MetricGauge: View {
    let title: String
    let value: Double
    let detail: String
    let icon: String
    var body: some View {
        VStack(spacing: 10) {
            HStack { Label(title, systemImage: icon).font(.headline); Spacer() }
            Gauge(value: value) { EmptyView() } currentValueLabel: { Text(detail).font(.title3.bold().monospacedDigit()) }
                .gaugeStyle(.accessoryCircularCapacity).scaleEffect(1.25).padding(.vertical, 8)
        }.padding().frame(maxWidth: .infinity).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
