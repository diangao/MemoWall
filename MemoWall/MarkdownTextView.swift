//
//  MarkdownTextView.swift
//  MemoWall
//
//  Created by Diyan Gao on 11/14/24.
//

import Foundation
import SwiftUI
import AppKit
import Down

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        // 配置滚动视图
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        
        // 配置文本视图
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.font = .systemFont(ofSize: 14)
        textView.isEditable = true
        textView.allowsUndo = true
        
        // 允许自动换行
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        
        // 启用自动布局
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        // 设置文本容器的内边距
        textView.textContainerInset = NSSize(width: 5, height: 5)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            context.coordinator.refreshMarkdownStyling(textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        static let CHECKBOX_UNCHECKED = "☐"
        static let CHECKBOX_CHECKED = "☑"
        
        init(_ parent: MarkdownTextView) {
            self.parent = parent
            super.init()
        }
        
        func refreshMarkdownStyling(_ textView: NSTextView) {
            applyMarkdownStyling(textView)
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // 保存光标位置
            let selectedRange = textView.selectedRange()
            
            // 获取当前行
            let currentLineRange = getCurrentLineRange(textView)
            let currentLine = (textView.string as NSString).substring(with: currentLineRange)
            
            // 只在新行开始且输入了 "[] " 时处理 todo
            if currentLine == "[] " {
                handleTodoInput(textView, lineRange: currentLineRange)
                
                // 设置光标位置到复选框后面
                let newPosition = currentLineRange.location + 2
                textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            }
            
            parent.text = textView.string
            applyMarkdownStyling(textView)
            
            // 如果不是处理 todo，恢复原始光标位置
            if currentLine != "[] " {
                textView.setSelectedRange(selectedRange)
            }
        }
        
        private func applyMarkdownStyling(_ textView: NSTextView) {
            let storage = textView.textStorage!
            let nsString = textView.string as NSString
            
            // 保存光标位置
            let selectedRanges = textView.selectedRanges
            
            var currentLocation = 0
            while currentLocation < nsString.length {
                let lineRange = nsString.lineRange(for: NSRange(location: currentLocation, length: 0))
                let line = nsString.substring(with: lineRange)
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                
                // 重置该行的字体
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: lineRange)
                
                // 检查是否包含 todo 标记（包括已转换和未转换的）
                let hasTodo = line.contains(Coordinator.CHECKBOX_UNCHECKED) || 
                             line.contains(Coordinator.CHECKBOX_CHECKED)
                
                // 移除 todo 标记后检查标题样式
                var lineForHeadingCheck = line
                if hasTodo {
                    lineForHeadingCheck = line.replacingOccurrences(of: Coordinator.CHECKBOX_UNCHECKED, with: "")
                                             .replacingOccurrences(of: Coordinator.CHECKBOX_CHECKED, with: "")
                }
                let trimmedLineForHeading = lineForHeadingCheck.trimmingCharacters(in: .whitespaces)
                
                // 应用标题样式
                if trimmedLineForHeading.hasPrefix("# ") && !trimmedLineForHeading.hasPrefix("## ") {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 28, weight: .bold), 
                                       range: lineRange)
                } else if trimmedLineForHeading.hasPrefix("## ") && !trimmedLineForHeading.hasPrefix("### ") {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 22, weight: .bold), 
                                       range: lineRange)
                } else if trimmedLineForHeading.hasPrefix("### ") {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 18, weight: .semibold), 
                                       range: lineRange)
                }
                
                currentLocation = NSMaxRange(lineRange)
            }
            
            // 恢复光标位置
            textView.selectedRanges = selectedRanges
        }
        
        private func getCurrentLineRange(_ textView: NSTextView) -> NSRange {
            let nsString = textView.string as NSString
            let selectedRange = textView.selectedRange()
            return nsString.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        }
        
        private func handleTodoInput(_ textView: NSTextView, lineRange: NSRange) {
            let storage = textView.textStorage!
            
            storage.beginEditing()
            
            // 替换 "[]" 为复选框
            let checkboxRange = NSRange(location: lineRange.location, length: 2)
            storage.replaceCharacters(in: checkboxRange, with: Coordinator.CHECKBOX_UNCHECKED)
            
            // 添加点击属性
            let clickableRange = NSRange(location: lineRange.location, length: 1)
            storage.addAttribute(.cursor, value: NSCursor.pointingHand, range: clickableRange)
            
            storage.endEditing()
        }
    }
}
