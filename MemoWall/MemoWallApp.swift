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
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)
        .handlesExternalEvents(matching: ["widget"])
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
    private var mainWindowController: NSWindowController?
    
    override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first,
              url.scheme == "memowall",
              url.host == "widget" else {
            return
        }
        
        NSApp.activate(ignoringOtherApps: true)
        activateOrCreateMainWindow()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            activateOrCreateMainWindow()
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func activateOrCreateMainWindow() {
        // 1. 如果已有窗口控制器，激活它的窗口
        if let windowController = mainWindowController, let window = windowController.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // 2. 如果没有窗口控制器但有主窗口，使用现有窗口
        if let existingWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            mainWindowController = NSWindowController(window: existingWindow)
            setupMainWindow(existingWindow)
            return
        }
        
        // 3. 如果既没有窗口控制器也没有主窗口，等待 SwiftUI 创建窗口
        // SwiftUI 会创建窗口并触发 windowDidBecomeKey 通知
        NSApp.windows.forEach { window in
            print("Window: \(window.title), identifier: \(window.identifier?.rawValue ?? "nil")")
        }
    }
    
    private func setupMainWindow(_ window: NSWindow) {
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        
        let screenSize = NSScreen.main?.visibleFrame ?? .zero
        let windowSize = NSSize(width: 800, height: 600)
        let windowOrigin = NSPoint(
            x: (screenSize.width - windowSize.width) / 2,
            y: (screenSize.height - windowSize.height) / 2
        )
        window.setFrame(NSRect(origin: windowOrigin, size: windowSize), display: true)
        
        window.minSize = NSSize(width: 400, height: 300)
        window.setFrameAutosaveName("Main Window")
        
        // 添加窗口通知观察
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
    }
    
    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.identifier?.rawValue == "main",
              mainWindowController == nil else {
            return
        }
        
        mainWindowController = NSWindowController(window: window)
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
