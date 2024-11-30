import SwiftUI
import AppKit

struct MarkdownTextView: View {
    @Binding var text: String
    var isWidget: Bool
    
    init(text: Binding<String>, isWidget: Bool = false) {
        self._text = text
        self.isWidget = isWidget
    }
    
    var body: some View {
        if isWidget {
            MarkdownRenderedView(text: text)
        } else {
            MacMarkdownTextView(text: $text)
        }
    }
}

struct MacMarkdownTextView: NSViewRepresentable {
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
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.backgroundColor = .white
        textView.drawsBackground = true
        
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        textView.textContainerInset = NSSize(width: 10, height: 10)
        
        textView.string = text
        context.coordinator.applyMarkdownStyling(textView)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.applyMarkdownStyling(textView)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacMarkdownTextView
        private var isProcessingMarkdown = false
        
        init(_ parent: MacMarkdownTextView) {
            self.parent = parent
            super.init()
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isProcessingMarkdown else { return }
            
            isProcessingMarkdown = true
            defer { isProcessingMarkdown = false }
            
            let currentLineRange = getCurrentLineRange(textView)
            let currentLine = (textView.string as NSString).substring(with: currentLineRange)
            
            var newLine = currentLine
            
            if currentLine.contains("[] ") {
                newLine = newLine.replacingOccurrences(of: "[] ", with: "□ ")
            } else if currentLine.contains("[x] ") || currentLine.contains("[X] ") {
                newLine = newLine.replacingOccurrences(of: "[x] ", with: "☑ ", options: .caseInsensitive)
            }
            
            if newLine != currentLine {
                replaceText(textView, range: currentLineRange, with: newLine)
            }
            
            parent.text = textView.string
            applyMarkdownStyling(textView)
        }
        
        private func getCurrentLineRange(_ textView: NSTextView) -> NSRange {
            let selectedRange = textView.selectedRange()
            return (textView.string as NSString).lineRange(for: NSRange(location: selectedRange.location, length: 0))
        }
        
        private func replaceText(_ textView: NSTextView, range: NSRange, with newText: String) {
            let cursorPosition = textView.selectedRange().location
            textView.replaceCharacters(in: range, with: newText)
            
            let lengthDifference = range.length - newText.count
            let newPosition = max(range.location, cursorPosition - lengthDifference)
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        }
        
        func applyMarkdownStyling(_ textView: NSTextView) {
            let storage = textView.textStorage!
            let fullRange = NSRange(location: 0, length: storage.length)
            
            storage.removeAttribute(.font, range: fullRange)
            storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: fullRange)
            
            let text = storage.string
            let lines = text.components(separatedBy: .newlines)
            var currentLocation = 0
            
            for line in lines {
                guard line.count > 0 else {
                    currentLocation += 1
                    continue
                }
                
                let lineRange = NSRange(location: currentLocation, length: line.count)
                
                var headingFont: NSFont? = nil
                if line.contains("### ") {
                    headingFont = NSFont.systemFont(ofSize: 16.8, weight: .semibold)
                } else if line.contains("## ") {
                    headingFont = NSFont.systemFont(ofSize: 21, weight: .bold)
                } else if line.contains("# ") {
                    headingFont = NSFont.systemFont(ofSize: 28, weight: .bold)
                }
                
                if let font = headingFont {
                    storage.addAttribute(.font, value: font, range: lineRange)
                } else {
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 14), range: lineRange)
                }
                
                currentLocation += line.count + (currentLocation < storage.length ? 1 : 0)
            }
        }
    }
}
