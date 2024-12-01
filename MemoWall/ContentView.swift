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
    
    var body: some View {
        MarkdownTextView(text: $text)
            .frame(minWidth: 400, minHeight: 300)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: text) { _, newValue in
                // 避免重复保存相同的文本
                guard newValue != lastSavedText else { return }
                
                // 使用 Task 包装异步调用
                Task {
                    await SharedDataManager.shared.setText(newValue)
                    lastSavedText = newValue
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            .task {
                // 初始加载文本
                text = await SharedDataManager.shared.getText()
                lastSavedText = text
            }
    }
}
