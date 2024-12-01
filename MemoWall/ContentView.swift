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
    
    var body: some View {
        ZStack {
            MarkdownTextView(text: $text)
                .frame(minWidth: 400, minHeight: 300)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: text) { _, newValue in
                    // 避免重复保存相同的文本
                    guard newValue != lastSavedText else { return }
                    
                    // 使用 Task 包装异步调用
                    Task {
                        do {
                            try await SharedDataManager.shared.setText(newValue)
                            lastSavedText = newValue
                            errorMessage = nil
                            WidgetCenter.shared.reloadAllTimelines()
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
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                            .padding()
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }
}
