//
//  ContentView.swift
//  MemoWall
//
//  Created by Diyan Gao on 11/23/24.
//

import Foundation
import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var text: String = ""
    @State private var lastSavedText: String = ""
    @State private var errorMessage: String?
    @State private var saveTask: Task<Void, Never>?
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        NavigationSplitView {
            EmptyView()
        } detail: {
            ZStack {
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
                
                MarkdownTextView(text: $text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.textBackgroundColor))
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
                    .padding(8)
                    .onChange(of: text) { _, newValue in
                        // 避免重复保存相同的文本
                        guard newValue != lastSavedText else { return }
                        
                        // 取消之前的保存任务
                        saveTask?.cancel()
                        
                        // 创建新的保存任务，延迟500ms
                        saveTask = Task {
                            do {
                                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                                guard !Task.isCancelled else { return }
                                
                                try await SharedDataManager.shared.setText(newValue)
                                if !Task.isCancelled {
                                    lastSavedText = newValue
                                    errorMessage = nil
                                    WidgetCenter.shared.reloadAllTimelines()
                                }
                            } catch is CancellationError {
                                // 忽略取消错误
                            } catch {
                                errorMessage = "Failed to save: \(error.localizedDescription)"
                            }
                        }
                    }
                    .task {
                        // 初始加载文本
                        do {
                            text = try await SharedDataManager.shared.getText()
                            lastSavedText = text
                            errorMessage = nil
                        } catch {
                            errorMessage = "Failed to load: \(error.localizedDescription)"
                        }
                    }
                
                if let error = errorMessage {
                    VStack {
                        HStack {
                            Spacer()
                            Text(error)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.9))
                                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                )
                                .padding()
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .onAppear {
                setupWindow()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 300, minHeight: 200) // 调整最小尺寸以匹配主窗口
    }
    
    private func setupWindow() {
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) else { return }
        
        // 如果是固定状态，应用固定样式
        if appDelegate.isPinned {
            window.styleMask = [.titled, .closable]
        }
    }
}
