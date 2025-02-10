//
//  ModelDownloadView.swift
//  OLMoE.swift
//
//  Created by Luca Soldaini on 2024-09-19.
//


import SwiftUI
import Combine
import Network

func formatSize(_ size: Int64) -> String {
    let sizeInGB = Double(size) / 1_000_000_000.0
    return String(format: "%.2f GB", sizeInGB)
}

class BackgroundDownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = BackgroundDownloadManager()

    @Published var downloadProgress: Float = 0
    @Published var isDownloading = false
    @Published var downloadError: String?
    @Published var isModelReady = false
    @Published var downloadedSize: Int64 = 0
    @Published var totalSize: Int64 = 0

    private var networkMonitor: NWPathMonitor?
    private var backgroundSession: URLSession!
    private var downloadTask: URLSessionDownloadTask?
    private var lastUpdateTime: Date = Date()
    private var hasCheckedDiskSpace = false
    private let updateInterval: TimeInterval = 0.5 // Update UI every 0.5 seconds
    private var lastDispatchedBytesWritten: Int64 = 0

    private override init() {
        super.init()
        #if targetEnvironment(macCatalyst)
        // Use regular session for Mac Catalyst
        backgroundSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        #else
        // Use background session for iOS
        let config = URLSessionConfiguration.background(withIdentifier: "ai.olmo.OLMoE.backgroundDownload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        #endif

        startNetworkMonitoring()
    }

    private func startNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .unsatisfied {
                    self.downloadError = "Connection lost. Please check your internet connection."
                    self.isDownloading = false
                    self.hasCheckedDiskSpace = false
                    self.isModelReady = false
                    self.lastDispatchedBytesWritten = 0
                    self.downloadTask?.cancel()
                }
            }
        }

        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor?.start(queue: queue)
    }

    /// Starts the download process.
    func startDownload() {
        if networkMonitor?.currentPath.status == .unsatisfied {
            return
        }

        guard let url = URL(string: AppConstants.Model.downloadURL) else { return }

        isDownloading = true
        downloadError = nil
        downloadedSize = 0
        totalSize = 0
        self.lastDispatchedBytesWritten = 0

        downloadTask = backgroundSession.downloadTask(with: url)
        downloadTask?.resume()
    }

    /// Handles the completion of the download task.
    /// - Parameters:
    ///   - session: The URL session that completed the task.
    ///   - downloadTask: The download task that completed.
    ///   - location: The temporary location of the downloaded file.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let destination = Bot.modelFileURL

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            DispatchQueue.main.async {
                self.isModelReady = true
                self.isDownloading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.downloadError = "Failed to save file: \(error.localizedDescription)"
                self.isDownloading = false
            }
        }
    }

    /// Handles errors that occur during the download task.
    /// - Parameters:
    ///   - session: The URL session that completed the task.
    ///   - task: The task that completed.
    ///   - error: The error that occurred, if any.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                if self.downloadError == nil {
                    self.downloadError = "Download failed: \(error.localizedDescription)"
                }
                self.isDownloading = false
                self.hasCheckedDiskSpace = false
            }
        }
    }

    /// Updates the download progress and checks for disk space during the download.
    /// - Parameters:
    ///   - session: The URL session managing the download.
    ///   - downloadTask: The download task that is writing data.
    ///   - bytesWritten: The number of bytes written in this update.
    ///   - totalBytesWritten: The total number of bytes written so far.
    ///   - totalBytesExpectedToWrite: The total number of bytes expected to be written.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if !hasCheckedDiskSpace {
            hasCheckedDiskSpace = true
            if !hasEnoughDiskSpace(requiredSpace: totalBytesExpectedToWrite) {
                DispatchQueue.main.async {
                    self.downloadError = "Not enough disk space available.\nNeed \(formatSize(totalBytesExpectedToWrite)) free."
                }
                downloadTask.cancel()
                return
            }
        }

        let currentTime = Date()
        if currentTime.timeIntervalSince(lastUpdateTime) >= updateInterval {
            DispatchQueue.main.async {
                // Due to async nature, older updates might run later; update progress only if data is more recent.
                guard totalBytesWritten > self.lastDispatchedBytesWritten else { return }
                self.lastDispatchedBytesWritten = totalBytesWritten

                self.downloadProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
                self.downloadedSize = totalBytesWritten
                self.totalSize = totalBytesExpectedToWrite
                self.lastUpdateTime = currentTime
            }
        }
    }

    /// Deletes the downloaded model file, marking it as not ready.
    func flushModel() {
        do {
            try FileManager.default.removeItem(at: Bot.modelFileURL)
            isModelReady = false
        } catch {
            downloadError = "Failed to flush model: \(error.localizedDescription)"
        }
    }

    /// Checks if there is enough disk space available for the required space.
    /// - Parameter requiredSpace: The amount of space required in bytes.
    /// - Returns: A boolean indicating whether there is enough disk space.
    private func hasEnoughDiskSpace(requiredSpace: Int64) -> Bool {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let availableCapacity = values.volumeAvailableCapacityForImportantUsage {
                return availableCapacity > requiredSpace
            }
        } catch {
            print("Error retrieving available disk space: \(error.localizedDescription)")
        }
        return false
    }
}


struct Ai2Logo: View {
    var body: some View {
        HStack {
            Image("Ai2 Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 18)

            Text("allenai.org")
                .font(.manrope(size: 14))
                .foregroundColor(Color("TextColor"))
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
        #if targetEnvironment(macCatalyst)
        .padding(.bottom, 20)
        #endif
    }
}

/// A view that displays the model download progress and status.
struct ModelDownloadView: View {
    @StateObject private var downloadManager = BackgroundDownloadManager.shared
    @State private var showDownloadConfirmation = false

    public var body: some View {
        ZStack {
            Color("BackgroundColor")
                .edgesIgnoringSafeArea(.all)

            VStack {
                if downloadManager.isModelReady {
                    Text("Model is ready to use!")
                        .foregroundColor(Color("TextColor"))
                        .font(.title())
                    Button("Flush Model", action: downloadManager.flushModel)
                        .buttonStyle(.PrimaryButton)
                } else if downloadManager.isDownloading {
                    ProgressView("Downloading...", value: downloadManager.downloadProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .padding()
                        .foregroundColor(Color("TextColor"))
                        .font(.body())
                    HStack {
                        Text("\(Int(downloadManager.downloadProgress * 100))%")
                            .foregroundColor(Color("TextColor"))
                            .font(.body())

                        Divider()
                            .frame(height: 20)
                            .background(Color("DividerTeal"))

                        Text("\(formatSize(downloadManager.downloadedSize)) / \(formatSize(downloadManager.totalSize))")
                            .foregroundColor(Color("TextColor"))
                            .font(.body())
                    }
                } else {
                    Text("Welcome")
                        .font(.telegraf(size: 48))

                    Text("Download Model Message")
                        .multilineTextAlignment(.center)
                        .font(.body())
                        .padding([.bottom], 4)

                    Spacer()
                        .frame(height: 16)

                    Button("Download Model") {
                        showDownloadConfirmation = true
                    }
                    .buttonStyle(.PrimaryButton)
                    .sheet(isPresented: $showDownloadConfirmation) {
                        SheetWrapper {
                            HStack {
                                Spacer()
                                CloseButton(action: { showDownloadConfirmation = false })
                            }
                            Spacer()
                            VStack(spacing: 20) {
                                Text("Download Model")
                                    .font(.title())

                                Text("The model requires 4.21GB of storage space. Would you like to proceed with the download?")
                                    .multilineTextAlignment(.center)
                                    .font(.body())

                                VStack(spacing: 12) {
                                    Button {
                                        showDownloadConfirmation = false
                                        downloadManager.startDownload()
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.down.circle.fill")
                                            Text("Start Download")
                                        }
                                    }
                                    .buttonStyle(.PrimaryButton)
                                }
                            }
                                .padding()
                            Spacer()
                        }
                    }
                }

                if let error = downloadManager.downloadError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()

            Ai2Logo()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .onAppear {
            if FileManager.default.fileExists(atPath: Bot.modelFileURL.path) {
                downloadManager.isModelReady = true
            }
        }
    }
}

#Preview("Ai2Logo") {
    VStack {
        Ai2Logo()
    }
    .preferredColorScheme(.dark)
    .padding()
    .background(Color("BackgroundColor"))
}

#Preview("ModelDownloadView") {
    ModelDownloadView()
        .preferredColorScheme(.dark)
        .padding()
        .background(Color("BackgroundColor"))
}
