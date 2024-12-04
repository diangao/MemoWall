import WidgetKit
import SwiftUI

struct SimpleEntry: TimelineEntry {
    let date: Date
    let text: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), text: "Your memo will appear here...")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), text: "Preview Text")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleEntry(date: Date(), text: "Timeline Text")
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct MemoWallWidgetEntryView: View {
    var entry: SimpleEntry

    var body: some View {
        Text(entry.text)
            .font(.system(size: 12))
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MemoWallWidget: Widget {
    let kind: String = "MemoWallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MemoWallWidgetEntryView(entry: entry)
                .background(Color(nsColor: .textBackgroundColor))
        }
        .configurationDisplayName("Memo Wall")
        .description("Display your latest memo.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    MemoWallWidget()
} timeline: {
    SimpleEntry(date: .now, text: "Preview Content")
}
