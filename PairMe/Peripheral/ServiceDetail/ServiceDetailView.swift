//
//  ServiceDetailView.swift
//  PairMe
//
//  Created by Oleksii Kolomiiets on 1/13/26.
//

import CoreBluetooth
import SwiftUI

struct ServiceDetailView: View {
    @Environment(\.peripheralManager) var peripheralManager
    var service: CBService

    @State private var selectedCharacteristic: CBCharacteristic? = nil
    @State private var showWriteSheet: Bool = false

    var body: some View {
        VStack {
            if let error = peripheralManager.error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 32)
            }

            List {
                Section {
                    if service.characteristics == nil || service.characteristics!.isEmpty {
                        Text("No characteristics added.")
                    }
                    ForEach(service.characteristics ?? [], id: \.uuid) { characteristic in
                        CharacteristicCellView(
                            updateValueAction: {
                                showWriteSheet = true
                                selectedCharacteristic = characteristic
                            },
                            characteristic: characteristic
                        )
                    }
                } header: {
                    Text("Characteristics")
                }
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showWriteSheet) {
                let subscribedCentrals: [CBCentral] =
                    selectedCharacteristic == nil ? [] : peripheralManager.subscribedCentrals[selectedCharacteristic!] ?? []

                WriteSheet(selectedCharacteristic: $selectedCharacteristic, subscribedCentrals: subscribedCentrals)
                    .onChange(of: showWriteSheet, initial: true) {
                        if !showWriteSheet {
                            selectedCharacteristic = nil
                        }
                    }
            }
        }
        .navigationTitle("Service: \(self.service.uuid)")
        .navigationBarTitleDisplayMode(.inline)
        .multilineTextAlignment(.leading)

    }
}
