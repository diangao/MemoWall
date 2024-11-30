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
    
    var body: some View {
        MarkdownTextView(text: $text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: text) { _, newValue in
                SharedDataManager.shared.saveText(newValue)
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onAppear {
                text = SharedDataManager.shared.getText()
            }
    }
}
