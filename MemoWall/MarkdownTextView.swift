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
            
            // 保存当前光标位置
            let selectedRange = textView.selectedRange()
            
            let currentLineRange = getCurrentLineRange(textView)
            let currentLine = (textView.string as NSString).substring(with: currentLineRange)
            
            // 只在完整输入 "[] " 后处理一次
            if currentLine == "[] " {
                handleTodoInput(textView, lineRange: currentLineRange)
                
                // 恢复光标位置到正确的位置（checkbox后面）
                let newPosition = currentLineRange.location + 3  // checkbox(1) + space(1) + 光标位置(1)
                textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            } else {
                parent.text = textView.string
                applyMarkdownStyling(textView)
                
                // 恢复原始光标位置
                textView.setSelectedRange(selectedRange)
            }
        }
        
        private func handleTodoInput(_ textView: NSTextView, lineRange: NSRange) {
            let storage = textView.textStorage!
            
            storage.beginEditing()
            
            // 替换 "[]" 为 checkbox
            let checkboxRange = NSRange(location: lineRange.location, length: 2)
            storage.replaceCharacters(in: checkboxRange, with: Coordinator.CHECKBOX_UNCHECKED)
            
            // 添加点击属性
            let clickableRange = NSRange(location: lineRange.location, length: 1)
            storage.addAttribute(.cursor, value: NSCursor.pointingHand, range: clickableRange)
            
            storage.endEditing()
            
            // 更新父视图的文本
            parent.text = textView.string
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
                
                // 设置默认字体
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: lineRange)
                
                // 首先检查是否是待办事项
                if trimmedLine.hasPrefix(Coordinator.CHECKBOX_UNCHECKED) || 
                   trimmedLine.hasPrefix(Coordinator.CHECKBOX_CHECKED) {
                    // 为复选框添加点击手势
                    if let checkboxRange = line.range(of: Coordinator.CHECKBOX_UNCHECKED) ?? 
                                         line.range(of: Coordinator.CHECKBOX_CHECKED) {
                        let startIndex = line.distance(from: line.startIndex, to: checkboxRange.lowerBound)
                        let clickableRange = NSRange(location: lineRange.location + startIndex, length: 1)
                        storage.addAttribute(.cursor, value: NSCursor.pointingHand, range: clickableRange)
                    }
                    
                    // 如果是已完成的待办事项，添加删除线
                    if trimmedLine.hasPrefix(Coordinator.CHECKBOX_CHECKED) {
                        storage.addAttribute(.strikethroughStyle, 
                                           value: NSUnderlineStyle.single.rawValue, 
                                           range: lineRange)
                    }
                    
                    currentLocation = NSMaxRange(lineRange)
                    continue  // 跳过标题样式处理
                }
                
                // 处理标题样式
                if trimmedLine.hasPrefix("# ") && !trimmedLine.hasPrefix("## ") {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 28, weight: .bold), 
                                       range: lineRange)
                } else if trimmedLine.hasPrefix("## ") && !trimmedLine.hasPrefix("### ") {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 22, weight: .bold), 
                                       range: lineRange)
                } else if trimmedLine.hasPrefix("### ") {
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
        
        // 修改点击处理方法
        func textView(_ textView: NSTextView, mouseDown event: NSEvent, at charIndex: Int, offset: CGFloat) -> Bool {
            let currentLineRange = getCurrentLineRange(textView)
            let currentLine = (textView.string as NSString).substring(with: currentLineRange)
            
            if currentLine.hasPrefix(Coordinator.CHECKBOX_UNCHECKED) {
                toggleTodoItem(textView, lineRange: currentLineRange, isChecked: true)
                return true
            } else if currentLine.hasPrefix(Coordinator.CHECKBOX_CHECKED) {
                toggleTodoItem(textView, lineRange: currentLineRange, isChecked: false)
                return true
            }
            
            return false
        }
        
        private func toggleTodoItem(_ textView: NSTextView, lineRange: NSRange, isChecked: Bool) {
            let storage = textView.textStorage!
            
            storage.beginEditing()
            
            // 替换 checkbox
            let checkboxRange = NSRange(location: lineRange.location, length: 1)
            storage.replaceCharacters(in: checkboxRange, 
                                    with: isChecked ? Coordinator.CHECKBOX_CHECKED : Coordinator.CHECKBOX_UNCHECKED)
            
            // 更新删除线样式
            storage.addAttribute(.strikethroughStyle, 
                                value: isChecked ? NSUnderlineStyle.single.rawValue : 0, 
                                range: lineRange)
            
            storage.endEditing()
            
            // 更新父视图的文本
            parent.text = textView.string
        }
    }
}
