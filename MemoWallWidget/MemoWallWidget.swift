//
//  MemoWallWidget.swift
//  MemoWallWidget
//
//  Created by Diyan Gao on 11/30/24.
//

import WidgetKit
import SwiftUI
import SwiftData

@MainActor
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), text: "Loading...")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        if context.isPreview {
            completion(SimpleEntry(date: Date(), text: "Preview text"))
            return
        }
        
        Task { @MainActor in
            do {
                let text = await SharedDataManager.shared.getText()
                let entry = SimpleEntry(date: Date(), text: text)
                completion(entry)
            } catch {
                let entry = SimpleEntry(date: Date(), text: "Error loading text")
                completion(entry)
            }
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        Task { @MainActor in
            do {
                let text = await SharedDataManager.shared.getText()
                let entry = SimpleEntry(date: Date(), text: text)
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            } catch {
                let entry = SimpleEntry(date: Date(), text: "Error loading text")
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            }
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let text: String
}

struct MemoWallWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkdownRenderedView(text: entry.text, isWidget: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(URL(string: "memowall://edit"))
    }
}

struct MemoWallWidget: Widget {
    let kind: String = "MemoWallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MemoWallWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MemoWall")
        .description("Quick access to your notes")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    MemoWallWidget()
} timeline: {
    SimpleEntry(date: .now, text: "Hello, World!")
}

#Preview(as: .systemMedium) {
    MemoWallWidget()
} timeline: {
    SimpleEntry(date: .now, text: "# Hello, World!\nThis is a preview of the widget.")
}

#Preview(as: .systemLarge) {
    MemoWallWidget()
} timeline: {
    SimpleEntry(date: .now, text: """
    # Hello, World!
    ## This is a preview
    This is a preview of the widget in large size.
    - Item 1
    - Item 2
    """)
}
