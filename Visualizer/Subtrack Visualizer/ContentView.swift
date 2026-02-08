//
//  ContentView.swift
//  Subtrack Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import Subtrack
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ContentViewModel()
    @State private var showInspector = false

    var body: some View {
        HStack(spacing: 0) {
            VisualizerCanvas(
                touchData: viewModel.touchData,
                enablePalmRejection: viewModel.enablePalmRejection,
                showVelocity: viewModel.showVelocity,
                showContactInfo: viewModel.showContactInfo
            )
            .aspectRatio(viewModel.aspectRatio, contentMode: .fit)
            .frame(height: 300)
            .fixedSize()
            .padding()

            if showInspector {
                Divider()
                    .ignoresSafeArea()

                ControlsView(viewModel: viewModel)
                    .frame(width: 350)
                    .padding(-10)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.right")
                }
            }
        }
    }
}
