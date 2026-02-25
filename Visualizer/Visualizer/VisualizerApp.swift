//
//  VisualizerApp.swift
//  Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import SwiftUI

@main
struct VisualizerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .windowLevel(.floating)
    }
}
