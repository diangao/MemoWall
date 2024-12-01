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
    
    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                if let container = modelContainer {
                    ContentView()
                        .modelContainer(container)
                        .frame(minWidth: 400, minHeight: 300)
                } else {
                    ProgressView("Loading...")
                        .task {
                            await SharedDataManager.shared.initializeModelContainer()
                            modelContainer = SharedDataManager.shared.sharedModelContainer
                        }
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
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!
    private var mainWindowController: NSWindowController?
    private var hasInitializedWindow = false
    
    override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        // 延迟初始化主窗口，避免多窗口问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.initializeMainWindowIfNeeded()
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        // 确保只处理我们的 URL scheme
        guard let url = urls.first,
              url.scheme == "memowall",
              url.host == "widget" else {
            return
        }
        
        NSApp.activate(ignoringOtherApps: true)
        
        // 如果已经有窗口，激活它
        if let windowController = mainWindowController {
            windowController.showWindow(nil)
            windowController.window?.makeKeyAndOrderFront(nil)
        } else {
            // 如果找到窗口但没有保存引用
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                setupMainWindow(window)
                hasInitializedWindow = true
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            initializeMainWindowIfNeeded()
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func initializeMainWindowIfNeeded() {
        guard !hasInitializedWindow else {
            if let windowController = mainWindowController {
                windowController.showWindow(nil)
                windowController.window?.makeKeyAndOrderFront(nil)
            }
            return
        }
        
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            setupMainWindow(window)
            hasInitializedWindow = true
        }
    }
    
    private func setupMainWindow(_ window: NSWindow) {
        // 设置窗口样式
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        
        // 设置窗口大小
        let screenSize = NSScreen.main?.visibleFrame ?? .zero
        let windowSize = NSSize(width: 800, height: 600)
        let windowOrigin = NSPoint(
            x: (screenSize.width - windowSize.width) / 2,
            y: (screenSize.height - windowSize.height) / 2
        )
        window.setFrame(NSRect(origin: windowOrigin, size: windowSize), display: true)
        
        // 设置最小大小
        window.minSize = NSSize(width: 400, height: 300)
        window.setFrameAutosaveName("Main Window")
        
        // 创建和显示窗口
        mainWindowController = NSWindowController(window: window)
        mainWindowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
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
