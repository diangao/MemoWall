//
//  ContentView.swift
//  MemoWall
//
//  Created by Diyan Gao on 11/23/24.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @State private var text: String = ""
    
    var body: some View {
        MarkdownTextView(text: $text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}