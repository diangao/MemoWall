//
//  MemoWallApp.swift
//  MemoWall
//
//  Created by Diyan Gao on 11/14/24.
//

import SwiftUI
import SwiftData

@main
struct MemoWallApp: App {
    var body: some Scene {
        WindowGroup {
            if let container = SharedDataManager.shared.sharedModelContainer {
                ContentView()
                    .modelContainer(container)
            } else {
                Text("Error: Could not initialize data container")
                    .foregroundColor(.red)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
    }
}
