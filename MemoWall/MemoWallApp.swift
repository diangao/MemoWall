//
//  MemoWallApp.swift
//  MemoWall
//
//  Created by Diyan Gao on 11/14/24.
//

import SwiftUI
import SwiftData
import AppKit
import Combine

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
                        .environmentObject(appDelegate)
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

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    static private(set) var shared: AppDelegate!
    private var mainWindow: NSWindow?
    @Published var isPinned: Bool = false {
        didSet {
            if let window = NSApp.windows.first {
                configureWindow(window)
            }
        }
    }
    
    override init() {
        super.init()
        Self.shared = self
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApp.windows.first {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            
            // 创建固定按钮
            let pinButton = NSButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
            pinButton.bezelStyle = .regularSquare
            pinButton.isBordered = false
            pinButton.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin window")
            pinButton.imagePosition = .imageOnly
            pinButton.action = #selector(togglePinWindow)
            pinButton.target = self
            
            // 设置按钮颜色
            if let cell = pinButton.cell as? NSButtonCell {
                cell.imageScaling = .scaleProportionallyDown
            }
            
            // 将按钮添加到窗口右上角
            if let titlebarView = window.standardWindowButton(.closeButton)?.superview {
                titlebarView.addSubview(pinButton)
                
                // 设置按钮位置在右上角
                pinButton.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    pinButton.centerYAnchor.constraint(equalTo: titlebarView.centerYAnchor),
                    pinButton.trailingAnchor.constraint(equalTo: titlebarView.trailingAnchor, constant: -8)
                ])
            }
            
            configureWindow(window)
        }
    }
    
    @objc private func togglePinWindow() {
        isPinned.toggle()
        
        // 更新按钮图标
        if let window = NSApp.windows.first,
           let titlebarView = window.standardWindowButton(.closeButton)?.superview,
           let pinButton = titlebarView.subviews.first(where: { ($0 as? NSButton)?.action == #selector(togglePinWindow) }) as? NSButton {
            pinButton.image = NSImage(systemSymbolName: isPinned ? "pin.fill" : "pin", accessibilityDescription: isPinned ? "Unpin window" : "Pin window")
            
            // 设置图标颜色
            if isPinned {
                pinButton.contentTintColor = NSColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0)
            } else {
                pinButton.contentTintColor = .secondaryLabelColor
            }
        }
    }
    
    private func configureWindow(_ window: NSWindow) {
        if isPinned {
            // 保持当前位置和大小，只禁用调整
            window.styleMask.remove(.resizable)
            window.styleMask.remove(.miniaturizable)
            window.isMovable = false
            window.isMovableByWindowBackground = false
        } else {
            window.styleMask.insert(.resizable)
            window.styleMask.insert(.miniaturizable)
            window.isMovable = true
            window.isMovableByWindowBackground = true
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
