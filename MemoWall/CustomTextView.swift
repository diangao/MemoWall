//
//  CustomTextView.swift
//  MemoWall
//
//  Created by Diyan Gao on 11/14/24.
//

import Foundation
import SwiftUI
import AppKit

struct CustomTextView: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.font = .systemFont(ofSize: 14)
        textView.isEditable = true
        textView.allowsUndo = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextView
        private static let CHECKBOX_UNCHECKED = "☐"
        private static let CHECKBOX_CHECKED = "☑"
        
        init(_ parent: CustomTextView) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            
            let currentLineRange = getCurrentLineRange(textView)
            let currentLine = (textView.string as NSString).substring(with: currentLineRange)
            
            // 处理待办事项
            if currentLine.trimmingCharacters(in: .whitespaces).hasPrefix("[] ") {
                handleTodoInput(textView, lineRange: currentLineRange)
            }
            
            // 应用标题样式
            applyHeaderStyles(textView)
        }
        
        private func handleTodoInput(_ textView: NSTextView, lineRange: NSRange) {
            let storage = textView.textStorage!
            let currentLine = (textView.string as NSString).substring(with: lineRange)
            
            // 检查是否真的是行首的 []
            let trimmedLine = currentLine.trimmingCharacters(in: .whitespaces)
            guard trimmedLine.hasPrefix("[]") else { return }
            
            // 计算 [] 在原始行中的位置
            if let range = currentLine.range(of: "[]") {
                let startIndex = currentLine.distance(from: currentLine.startIndex, to: range.lowerBound)
                let todoRange = NSRange(location: lineRange.location + startIndex, length: 2)
                
                // 替换 [] 为复选框
                storage.replaceCharacters(in: todoRange, with: Coordinator.CHECKBOX_UNCHECKED)
                
                // 为复选框设置样式
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: todoRange)
                storage.addAttribute(.cursor, value: NSCursor.pointingHand, range: todoRange)
            }
        }
        
        private func applyHeaderStyles(_ textView: NSTextView) {
            let storage = textView.textStorage!
            let nsString = textView.string as NSString
            
            var currentLocation = 0
            while currentLocation < nsString.length {
                let lineRange = nsString.lineRange(for: NSRange(location: currentLocation, length: 0))
                let line = nsString.substring(with: lineRange)
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                
                // 如果行以复选框开始，保持现有样式
                if trimmedLine.hasPrefix(Coordinator.CHECKBOX_UNCHECKED) || 
                   trimmedLine.hasPrefix(Coordinator.CHECKBOX_CHECKED) {
                    currentLocation = NSMaxRange(lineRange)
                    continue
                }
                
                // 重置当前行的字体
                let currentFont = storage.attribute(.font, at: lineRange.location, effectiveRange: nil) as? NSFont
                if currentFont == nil {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: lineRange)
                }
                
                // 应用标题样式
                if trimmedLine.hasPrefix("# ") && !trimmedLine.hasPrefix("## ") {
                    let content = trimmedLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
                    if !content.isEmpty {
                        storage.addAttribute(.font, 
                            value: NSFont.systemFont(ofSize: 32, weight: .bold), 
                            range: lineRange)
                    }
                } else if trimmedLine.hasPrefix("## ") && !trimmedLine.hasPrefix("### ") {
                    let content = trimmedLine.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    if !content.isEmpty {
                        storage.addAttribute(.font, 
                            value: NSFont.systemFont(ofSize: 24, weight: .bold), 
                            range: lineRange)
                    }
                } else if trimmedLine.hasPrefix("### ") {
                    let content = trimmedLine.dropFirst(4).trimmingCharacters(in: .whitespaces)
                    if !content.isEmpty {
                        storage.addAttribute(.font, 
                            value: NSFont.systemFont(ofSize: 18, weight: .semibold), 
                            range: lineRange)
                    }
                } else {
                    // 非标题行使用默认字体
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: lineRange)
                }
                
                currentLocation = NSMaxRange(lineRange)
            }
        }
        
        private func getCurrentLineRange(_ textView: NSTextView) -> NSRange {
            let nsString = textView.string as NSString
            let selectedRange = textView.selectedRange()
            return nsString.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        }
    }
}
