//
//  MetricsView.swift
//  OLMoE.swift
//
//  Created by Jon Ryser on 3/5/25.
//

import SwiftUI

/// A button that toggles the metrics view visibility
public struct MetricsButton: View {
    /// The action to perform when the button is tapped
    let action: () -> Void

    /// Whether metrics are currently being shown
    let isShowing: Bool

    public var body: some View {
        ToolbarButton(action: action, assetName: isShowing ? "MetricsIconFilled" : "MetricsIcon", foregroundColor: Color("AccentColor"), width: 14, height: 14)
    }
}

/// Displays inference metrics in a compact format
public struct MetricsView: View {
    /// The metrics to display
    var metrics: InferenceMetrics

    /// Creates a new metrics view
    /// - Parameter metrics: The inference metrics to display
    public init(metrics: InferenceMetrics) {
        self.metrics = metrics
    }

    public var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tokens:")
                        .font(.caption.bold())
                    Spacer()
                    Text("\(metrics.totalTokens) total")
                        .font(.caption)
                }

                HStack {
                    Image(systemName: "keyboard")
                        .font(.caption)
                    Text("\(metrics.inputTokenCount) input")
                        .font(.caption)
                    Spacer()
                    Image(systemName: "text.bubble")
                        .font(.caption)
                    Text("\(metrics.inferenceTokenCount) output")
                        .font(.caption)
                }

                if metrics.endTime > metrics.startTime {
                    HStack {
                        Image(systemName: "speedometer")
                            .font(.caption)
                        Text(String(format: "%.2f tokens/sec", metrics.inferenceTokensPerSecond))
                            .font(.caption)
                        Spacer()
                        Image(systemName: "clock")
                            .font(.caption)
                        let duration = metrics.endTime - metrics.startTime
                        Text(String(format: "%.1fs", duration))
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 12)
        }
        .background(Color("MetricsBgColor"))
        .padding(.horizontal, -12)
        .padding(.top, -11)
        .padding(.bottom, 8)
    }
}

struct MetricsTogglePreview: View {
    @State private var showMetrics = true

    let sampleMetrics: InferenceMetrics = {
        var metrics = InferenceMetrics()
        metrics.inputTokenCount = 24
        metrics.inferenceTokenCount = 128
        metrics.start()
        // Simulate some time passing
        metrics.stop()
        return metrics
    }()

    var body: some View {
        VStack {
            // Navigation bar simulation
            HStack {
                Spacer()

                MetricsButton(
                    action: { showMetrics.toggle() },
                    isShowing: showMetrics
                )
                .padding(.trailing, 20)
            }
            .padding(.top, 10)
            .background(Color("Surface").opacity(0.3))

            // Content area with conditional metrics view
            VStack(spacing: 0) {
                if showMetrics {
                    MetricsView(metrics: sampleMetrics)
                        .transition(.opacity)
                }

                // Sample chat content
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Sample conversation area")
                            .font(.headline)

                        Text("Tap the metrics button in the toolbar to toggle metrics visibility.")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showMetrics)
            .padding(12)
            Spacer()
        }
        .frame(height: 400)
        .background(Color("BackgroundColor"))
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MetricsTogglePreview()
}
