//
//  MemoWallApp.swift
//  MemoWall
//
//  Created by Diyan Gao on 11/14/24.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct MemoWallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var modelContainer: ModelContainer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                if let error = errorMessage {
                    VStack(spacing: 20) {
                        Text("Failed to Initialize")
                            .font(.headline)
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            errorMessage = nil
                            isLoading = true
                            Task {
                                do {
                                    try await initializeData()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: 400)
                } else if isLoading {
                    ProgressView("Initializing...")
                        .task {
                            do {
                                try await initializeData()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                } else if let container = modelContainer {
                    ContentView()
                        .modelContainer(container)
                        .frame(minWidth: 400, minHeight: 300)
                }
            }
            .onAppear {
                // 在视图出现时通知 AppDelegate
                NotificationCenter.default.post(name: NSNotification.Name("WindowDidAppear"), object: nil)
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
    
    private func initializeData() async throws {
        do {
            try await SharedDataManager.shared.initializeModelContainer()
            if let container = SharedDataManager.shared.sharedModelContainer {
                modelContainer = container
                isLoading = false
            } else {
                throw NSError(
                    domain: "MemoWallApp",
                    code: -1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to initialize data container. Please check app permissions and try again."
                    ]
                )
            }
        } catch {
            throw error
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!
    private var mainWindow: NSWindow?
    
    override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        // 监听窗口创建
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidAppear),
            name: NSNotification.Name("WindowDidAppear"),
            object: nil
        )
    }
    
    @objc private func handleWindowDidAppear() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 如果已经有主窗口，直接返回
            if self.mainWindow?.isVisible == true {
                return
            }
            
            // 找到第一个主窗口
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                self.mainWindow = window
                
                // 设置窗口样式
                window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                
                // 设置窗口大小和位置
                let screenSize = NSScreen.main?.visibleFrame ?? .zero
                let windowSize = NSSize(width: 800, height: 600)
                let windowOrigin = NSPoint(
                    x: (screenSize.width - windowSize.width) / 2,
                    y: (screenSize.height - windowSize.height) / 2
                )
                window.setFrame(NSRect(origin: windowOrigin, size: windowSize), display: true)
                
                // 关闭其他所有主窗口
                NSApp.windows.forEach { otherWindow in
                    if otherWindow !== window && otherWindow.identifier?.rawValue == "main" {
                        otherWindow.close()
                    }
                }
                
                // 显示并激活窗口
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first,
              url.scheme == "memowall",
              url.host == "widget" else {
            return
        }
        
        // 如果已经有窗口，激活它
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // 否则发送通知创建新窗口
        NotificationCenter.default.post(name: NSNotification.Name("WindowDidAppear"), object: nil)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // 如果没有可见窗口，让 SwiftUI 创建一个
            return true
        }
        
        // 如果有可见窗口，激活它
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        return false
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 当最后一个窗口关闭时，重置主窗口引用
        mainWindow = nil
        return true
    }
}

@MainActor
class DataManager: ObservableObject {
    @Published var modelContainer: ModelContainer?
    
    init() {
        Task {
            do {
                let schema = Schema([Item.self])
                let modelConfiguration = ModelConfiguration(schema: schema)
                modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                print("Failed to create ModelContainer: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupModelContainer() async {
        modelContainer = await SharedDataManager.shared.sharedModelContainer
        if modelContainer == nil {
            print("Failed to initialize ModelContainer")
        }
    }
}
