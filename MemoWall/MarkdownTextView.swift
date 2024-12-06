import SwiftUI
import AppKit

struct MarkdownTextView: View {
    @Binding var text: String
    var isWidget: Bool
    @EnvironmentObject private var appDelegate: AppDelegate
    
    init(text: Binding<String>, isWidget: Bool = false) {
        self._text = text
        self.isWidget = isWidget
    }
    
    var body: some View {
        if isWidget {
            MarkdownRenderedView(text: text, isWidget: true)
        } else {
            MacMarkdownTextView(text: $text)
                .environmentObject(appDelegate)
        }
    }
}

// 添加一个自定义的 NSTextStorage 子类
class MarkdownTextStorage: NSTextStorage {
    private var storage = NSMutableAttributedString()
    var fontSize: CGFloat {
        didSet {
            if oldValue != fontSize {
                applyStyles()
            }
        }
    }
    
    init(fontSize: CGFloat) {
        self.fontSize = fontSize
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var string: String {
        return storage.string
    }
    
    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return storage.attributes(at: location, effectiveRange: range)
    }
    
    override func replaceCharacters(in range: NSRange, with str: String) {
        print("Replacing characters in range: \(range) with string of length: \(str.count)")
        beginEditing()
        storage.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
        applyStyles()
    }
    
    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        beginEditing()
        storage.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }
    
    private func applyStyles() {
        print("Applying styles with font size: \(fontSize)")
        let text = storage.string
        let fullRange = NSRange(location: 0, length: length)
        
        // 重置所有样式
        beginEditing()
        
        // 设置基础字体和颜色
        let baseFont = NSFont.systemFont(ofSize: fontSize)
        setAttributes([
            .font: baseFont,
            .foregroundColor: NSColor.textColor
        ], range: fullRange)
        
        // 处理每一行
        text.enumerateLines { line, _ in
            let lineRange = (text as NSString).range(of: line)
            
            // 处理标题
            if let headerLevel = self.getHeaderLevel(from: line) {
                let headerSize = self.fontSize * (headerLevel == 1 ? 2.0 :
                                               headerLevel == 2 ? 1.5 :
                                               headerLevel == 3 ? 1.2 : 1.0)
                let headerFont = NSFont.boldSystemFont(ofSize: headerSize)
                self.addAttribute(.font, value: headerFont, range: lineRange)
            }
            
            // 处理待办事项
            if line.hasPrefix("□ ") || line.hasPrefix("☑ ") {
                let checkboxRange = NSRange(location: lineRange.location, length: 2)
                self.addAttribute(.foregroundColor, value: NSColor.systemGray, range: checkboxRange)
            }
        }
        
        endEditing()
        
        // 通知布局管理器重新布局
        layoutManagers.forEach { manager in
            manager.ensureLayout(for: manager.textContainers.first!)
        }
    }
    
    private func getHeaderLevel(from line: String) -> Int? {
        let pattern = "^\\s*(#{1,6})\\s+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        if let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) {
            let hashRange = match.range(at: 1)
            let hashCount = (line as NSString).substring(with: hashRange).count
            return hashCount
        }
        return nil
    }
    
    func updateFontSize(_ newSize: CGFloat) {
        print("Updating font size from \(fontSize) to \(newSize)")
        fontSize = newSize
    }
}

struct MacMarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    @EnvironmentObject private var appDelegate: AppDelegate
    private var textStorage: MarkdownTextStorage?
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacMarkdownTextView
        weak var textView: NSTextView?
        
        init(_ parent: MacMarkdownTextView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            // 保持选择状态不变
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        
        // 创建文本存储和布局系统
        let storage = MarkdownTextStorage(fontSize: appDelegate.fontSize)
        textStorage = storage
        
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer()
        layoutManager.addTextContainer(textContainer)
        
        // 配置文本容器
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        
        // 创建和配置文本视图
        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        context.coordinator.textView = textView
        textView.delegate = context.coordinator
        
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        scrollView.documentView = textView
        
        // 设置初始文本
        if !text.isEmpty {
            storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView,
              let storage = textStorage else { return }
        
        // 更新字体大小
        if storage.fontSize != appDelegate.fontSize {
            print("Updating font size to: \(appDelegate.fontSize)")
            storage.updateFontSize(appDelegate.fontSize)
        }
        
        // 更新文本内容（如果需要）
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
            textView.selectedRanges = selectedRanges
        }
    }
}
