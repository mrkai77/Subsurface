//
//  ControlsView.swift
//  Subtrack Visualizer
//
//  Created by Kai Azim on 2026-02-07.
//

import Subtrack
import SwiftUI

struct ControlsView: View {
    let viewModel: ContentViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section("Subtrack Visualizer") {
                HStack {
                    Text("Visualization")

                    Spacer()

                    VStack {
                        if viewModel.isListening {
                            Button("Stop", action: viewModel.stop)
                        } else {
                            Button("Start", action: viewModel.start)
                        }
                    }
                }
                .disabled(viewModel.trackingMode == .individual && viewModel.selectedDevice == nil)

                Picker("Tracking Mode", selection: $viewModel.trackingMode) {
                    Text("Individual").tag(TrackingMode.individual)
                    Text("Global").tag(TrackingMode.global)
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isListening)

                if viewModel.trackingMode == .global, let currentDevice = viewModel.currentDevice {
                    HStack {
                        Text("Last device")
                        Spacer()
                        Text(currentDevice.name)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Show velocity vector", isOn: $viewModel.showVelocity)

                Toggle("Show contact info", isOn: $viewModel.showContactInfo)

                Toggle("Palm rejection", isOn: $viewModel.enablePalmRejection)
            }

            if viewModel.trackingMode == .individual {
                Section {
                    ForEach(Array(viewModel.availableDevicesByID.keys), id: \.self) { deviceKey in
                        if let device = viewModel.availableDevicesByID[deviceKey] {
                            HStack {
                                let isSelected = viewModel.selectedDevice?.deviceID == deviceKey
                                if isSelected {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(.green)
                                }

                                Text("\(device.name)")
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button("Select") {
                                    viewModel.selectDevice(device)
                                }
                                .disabled(isSelected)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Device")

                        Spacer()

                        Button("Reload", action: viewModel.reloadDevices)
                            .buttonStyle(.accessoryBar)
                    }
                    .onAppear(perform: viewModel.reloadDevices)
                }
                .disabled(viewModel.isListening)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
