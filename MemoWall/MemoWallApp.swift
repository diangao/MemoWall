//
//  MemoWallApp.swift
//  MemoWall
//
//  Created by Diyan Gao on 11/14/24.
//

import SwiftUI
import SwiftData
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            // 确保 SharedDataManager 在应用启动时初始化
            _ = await SharedDataManager.shared.sharedModelContainer
        }
        
        // 设置应用程序行为
        NSApp.setActivationPolicy(.regular)
        
        // 禁用新建窗口菜单项
        if let newWindowItem = NSApp.mainMenu?.item(withTitle: "File")?.submenu?.item(withTitle: "New Window") {
            newWindowItem.isEnabled = false
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            createAndShowMainWindow()
        }
        return true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        showMainWindow()
    }
    
    private func createAndShowMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.setFrameAutosaveName("Main Window")
            window.title = "MemoWall"
            window.isReleasedWhenClosed = false
            mainWindow = window
        }
        showMainWindow()
    }
    
    private func showMainWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@main
struct MemoWallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dataManager = DataManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 关闭自动创建的窗口
                    if let firstWindow = NSApp.windows.first {
                        firstWindow.close()
                    }
                    if let window = NSApp.windows.first {
                        appDelegate.mainWindow = window
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        .commands {
            CommandGroup(replacing: .newItem) { }  // 禁用新建窗口命令
        }
    }
}

@MainActor
class DataManager: ObservableObject {
    @Published var modelContainer: ModelContainer?
    
    init() {
        Task {
            await setupModelContainer()
        }
    }
    
    private func setupModelContainer() async {
        modelContainer = await SharedDataManager.shared.sharedModelContainer
        if modelContainer == nil {
            print("Failed to initialize ModelContainer")
        }
    }
}
