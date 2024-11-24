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
        private static let CHECKBOX_UNCHECKED = "☐"
        private static let CHECKBOX_CHECKED = "☑"
        
        init(_ parent: MarkdownTextView) {
            self.parent = parent
            super.init()
        }
        
        func refreshMarkdownStyling(_ textView: NSTextView) {
            applyMarkdownStyling(textView)
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            
            let currentLineRange = getCurrentLineRange(textView)
            let currentLine = (textView.string as NSString).substring(with: currentLineRange)
            
            if currentLine.trimmingCharacters(in: .whitespaces).hasPrefix("[] ") {
                handleTodoInput(textView, lineRange: currentLineRange)
            }
            
            applyMarkdownStyling(textView)
        }
        
        private func handleTodoInput(_ textView: NSTextView, lineRange: NSRange) {
            let storage = textView.textStorage!
            let currentLine = (textView.string as NSString).substring(with: lineRange)
            
            // 检查是否是待办事项
            if let range = currentLine.range(of: "[] ") {
                // 计算 [] 在原始行中的位置
                let startIndex = currentLine.distance(from: currentLine.startIndex, to: range.lowerBound)
                let checkboxRange = NSRange(location: lineRange.location + startIndex, length: 2)
                
                // 保存原始属性
                let attributes = storage.attributes(at: lineRange.location, effectiveRange: nil)
                
                // 替换 [] 为复选框
                storage.replaceCharacters(in: checkboxRange, with: Coordinator.CHECKBOX_UNCHECKED)
                
                // 恢复原始属性
                let newRange = NSRange(location: lineRange.location, length: currentLine.count)
                storage.setAttributes(attributes, range: newRange)
                
                // 单独设置复选框的字体
                let checkboxCharRange = NSRange(location: lineRange.location + startIndex, length: 1)
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: checkboxCharRange)
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
                
                // 设置默认字体
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: lineRange)
                
                // 如果是待办事项行，跳过标题样式处理
                if trimmedLine.hasPrefix(Coordinator.CHECKBOX_UNCHECKED) || 
                   trimmedLine.hasPrefix(Coordinator.CHECKBOX_CHECKED) {
                    currentLocation = NSMaxRange(lineRange)
                    continue
                }
                
                // 应用标题样式
                if trimmedLine.hasPrefix("# ") && !trimmedLine.hasPrefix("## ") {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 28, weight: .bold), range: lineRange)
                } else if trimmedLine.hasPrefix("## ") && !trimmedLine.hasPrefix("### ") {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 22, weight: .bold), range: lineRange)
                } else if trimmedLine.hasPrefix("### ") {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 18, weight: .semibold), range: lineRange)
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
        
        // 添加复选框点击处理
        func textView(_ textView: NSTextView, clickedOnCell cell: NSTextAttachmentCellProtocol, in cellFrame: NSRect, at charIndex: Int) -> Bool {
            let nsString = textView.string as NSString
            let lineRange = nsString.lineRange(for: NSRange(location: charIndex, length: 0))
            let line = nsString.substring(with: lineRange)
            
            if line.contains(Coordinator.CHECKBOX_UNCHECKED) {
                let newLine = line.replacingOccurrences(of: Coordinator.CHECKBOX_UNCHECKED, 
                                                      with: Coordinator.CHECKBOX_CHECKED)
                textView.textStorage?.replaceCharacters(in: lineRange, with: newLine)
            } else if line.contains(Coordinator.CHECKBOX_CHECKED) {
                let newLine = line.replacingOccurrences(of: Coordinator.CHECKBOX_CHECKED, 
                                                      with: Coordinator.CHECKBOX_UNCHECKED)
                textView.textStorage?.replaceCharacters(in: lineRange, with: newLine)
            }
            
            return true
        }
    }
}
