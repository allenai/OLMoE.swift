//
//  ContentView.swift
//  OLMoE.swift
//
//  Created by Luca Soldaini on 2024-09-16.
//

import SwiftUI

class Bot: LLM {
    static let modelFileName = "olmoe-1b-7b-0924-instruct-q4_k_m.gguf"
    static let modelFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(modelFileName)

    convenience init() {
        let deviceName = UIDevice.current.model
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d, yyyy"
        let currentDate = dateFormatter.string(from: Date())
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let currentTime = timeFormatter.string(from: Date())
        
        let systemPrompt = "You are OLMoE (Open Language Mixture of Expert), a small language model running on \(deviceName). You have been developed at the Allen Institute for AI (Ai2) in Seattle, WA, USA. Today is \(currentDate). The time is \(currentTime)."
    
        guard FileManager.default.fileExists(atPath: Bot.modelFileURL.path) else {
            fatalError("Model file not found. Please download it first.")
        }
        
//        self.init(from: Bot.modelFileURL, template: .OLMoE(systemPrompt))
        self.init(from: Bot.modelFileURL, template: .OLMoE())
    }
}

struct BotView: View {
    @StateObject var bot: Bot
    @State var input = ""
    @State private var textEditorHeight: CGFloat = 40
    @State private var isGenerating = false
    @State private var scrollToBottom = false
    @State private var isSharing = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    
    init(_ bot: Bot) {
        _bot = StateObject(wrappedValue: bot)
    }
    
    func respond() {
        isGenerating = true
        Task {
            await bot.respond(to: input)
            input = "" // Clear the input after sending
            scrollToBottom = true
        }
        isGenerating = false
    }
    
    func stop() {
        bot.stop()
        input = "" // Clear the input
        isGenerating = false
        Task { @MainActor in
            await bot.clearHistory()
            bot.setOutput(to: "")
        }
    }
    
    func shareConversation() {
        isSharing = true
        Task {
            do {
                let apiKey = Configuration.apiKey
                let apiUrl = "https://ziv3vcg14i.execute-api.us-east-1.amazonaws.com/prod"
                
                let modelName = "olmoe-1b-7b-0924-instruct-q4_k_m"
                let systemFingerprint = "\(modelName)-\(AppInfo.shared.appId)"
                
                let messages = bot.history.map { chat in
                    ["role": chat.role == .user ? "user" : "assistant", "content": chat.content]
                }
                
                let payload: [String: Any] = [
                    "model": modelName,
                    "system_fingerprint": systemFingerprint,
                    "created": Int(Date().timeIntervalSince1970),
                    "messages": messages
                ]
                
                let jsonData = try JSONSerialization.data(withJSONObject: payload)
                
                var request = URLRequest(url: URL(string: apiUrl)!)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                request.httpBody = jsonData
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let responseString = String(data: data, encoding: .utf8)!
                    if let jsonData = responseString.data(using: .utf8),
                       let jsonResult = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                       let body = jsonResult["body"] as? String,
                       let bodyData = body.data(using: .utf8),
                       let bodyJson = try JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any],
                       let urlString = bodyJson["url"] as? String,
                       let url = URL(string: urlString) {
                        await MainActor.run {
                            self.shareURL = url
                            self.showShareSheet = true
                        }
                        print("Conversation shared successfully")
                    } else {
                        print("Failed to parse response")
                    }
                } else {
                    print("Failed to share conversation")
                }
            } catch {
                print("Error sharing conversation: \(error)")
            }
            
            await MainActor.run {
                isSharing = false
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            contentView(in: geometry)
        }
        .sheet(isPresented: $showShareSheet, content: {
            if let url = shareURL {
                ActivityViewController(activityItems: [url])
            }
        })
    }
    
    private func contentView(in geometry: GeometryProxy) -> some View {
        ZStack {
            Color("BackgroundColor")
                .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading) {
                if !bot.output.isEmpty || isGenerating || !bot.history.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                // Display history
                                ForEach(bot.history, id: \.content) { chat in
                                    if chat.content != bot.output {
                                        Text(chat.role == .user ? "User: " : "Bot: ")
                                            .fontWeight(.bold)
                                            .foregroundColor(Color("TextColor"))
                                        + Text(chat.content)
                                            .foregroundColor(Color("TextColor"))
                                    }
                                }
                                .opacity(0.5)
                                .font(.manrope().monospaced())
                                
                                // Display current output
                                Text(bot.output)
                                    .monospaced()
                                    .foregroundColor(Color("TextColor"))
                                    .id("bottomID") // Unique ID for scrolling
                                Color.clear.frame(height: 1).id("bottomID2")
                                
                            }
                        }
                        .onChange(of: bot.output) { _ in
                            if isGenerating {
                                withAnimation {
                                    proxy.scrollTo("bottomID", anchor: .bottom)
                                }
                            } else {
                                withAnimation {
                                    proxy.scrollTo("bottomID2", anchor: .bottom)
                                }
                            }
                            
                        }
                        .onChange(of: scrollToBottom) { newValue in
                            if newValue {
                                withAnimation {
                                    proxy.scrollTo("bottomID", anchor: .bottom)
                                }
                                scrollToBottom = false
                            }
                        }
                    }
                } else {
                    ZStack {
                        VStack{
                            Spacer()
                                .frame(height: geometry.size.height * 0.1)
                            Image("Splash")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: min(geometry.size.width - 160, 290))
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Spacer()
                
                HStack(alignment: .bottom, spacing: 8) {
                    ZStack(alignment: .leading) {
                        TextEditor(text: $input)
                            .frame(height: max(40, textEditorHeight))
                            .scrollContentBackground(.hidden)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .foregroundStyle(.thinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color("TextColor").opacity(0.2), lineWidth: 1)
                            )
                            .padding(8)
                            .foregroundColor(Color("TextColor"))
                            .font(.manrope())
                    }
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(key: ViewHeightKey.self, value: geometry.size.height)
                        }
                    )
                    .onPreferenceChange(ViewHeightKey.self) { height in
                        self.textEditorHeight = min(max(40, height), 120)
                    }
                    VStack(spacing: 8) {
                        Button(action: shareConversation) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(Color("TextColor"))
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                        }
                        .disabled(isSharing || bot.history.isEmpty)
                        Button(action: respond) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(Color("AccentColor"))
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                        }
                        .disabled(isGenerating)
                        Button(action: stop) {
                            Image(systemName: "trash.fill")
                                .foregroundColor(Color("TextColor"))
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                        }
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .sheet(isPresented: $showShareSheet, content: {
            if let url = shareURL {
                ActivityViewController(activityItems: [url])
            }
        })
    }
}

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}


// Add this struct to handle the UIActivityViewController
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

struct ContentView: View {
    @StateObject private var downloadManager = BackgroundDownloadManager.shared
    @State private var bot: Bot?
    @State private var showInfoPage : Bool = true
    @State private var infoPageIndex: Int = 0

    var body: some View {
        VStack {
            if let bot = bot {
                BotView(bot)
            } else {
                ModelDownloadView()
            }
        }
        .onChange(of: downloadManager.isModelReady) { newValue in
            if newValue && bot == nil {
                initializeBot()
            }
        }
        .popover(isPresented: $showInfoPage) {
            let page = infoPages[infoPageIndex]
            InfoPage(
                title: page.title,
                message: page.text,
                confirm: InfoPage.PageButton(
                    text: page.buttonText,
                    onDismiss: {
                        nextInfoPage()
                    })
            )
            .presentationBackground(Color("BackgroundColor"))
        }
        .onAppear(perform: checkModelAndInitializeBot)
    }

    private func nextInfoPage() {
        infoPageIndex = min(infoPages.count, infoPageIndex + 1)
        if infoPageIndex >= infoPages.count {
            infoPageIndex = 0
            showInfoPage = false
        }
    }
        
    private func checkModelAndInitializeBot() {
        if FileManager.default.fileExists(atPath: Bot.modelFileURL.path) {
            downloadManager.isModelReady = true
            initializeBot()
        }
    }

    private func initializeBot() {
        bot = Bot()
    }
}
