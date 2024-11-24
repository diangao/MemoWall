//
//  ContentView.swift
//  MemoWall
//
//  Created by Diyan Gao on 11/14/24.
//

import SwiftUI

struct ContentView: View {
    @State private var text: String = ""
    
    var body: some View {
        MarkdownTextView(text: $text)
            .frame(minWidth: 300, minHeight: 400)
    }
}

// Preview
#Preview {
    ContentView()
}
