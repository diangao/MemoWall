//
//  MemoWallWidget.swift
//  MemoWallWidget
//
//  Created by Diyan Gao on 11/30/24.
//

import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), text: "Loading...")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), text: SharedDataManager.shared.getText())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = SimpleEntry(date: Date(), text: SharedDataManager.shared.getText())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
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
        VStack(alignment: .leading) {
            Text(entry.text)
                .font(.system(.body, design: .monospaced))
                .lineLimit(nil)
                .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.textBackgroundColor))
        .widgetURL(URL(string: "memowall://edit"))
    }
}

struct MemoWallWidget: Widget {
    let kind: String = "MemoWallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MemoWallWidgetEntryView(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background()
        }
        .configurationDisplayName("MemoWall")
        .description("Quick access to your notes")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
