//
//  WriteSheet.swift
//  PairMe
//
//  Created by Oleksii Kolomiiets on 1/13/26.
//


import CoreBluetooth
import SwiftUI

struct WriteSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.peripheralManager) var peripheralManager
    let subscribedCentrals: [CBCentral]
    @Binding private var selectedCharacteristic: CBCharacteristic?

    @State private var text: String = ""
    @State private var entryError: String? = nil

    private static let allCentrals = "(all)"
    @State private var selectedCentrals: [CBCentral] = []
    @State private var showPicker: Bool = false

    init(
        selectedCharacteristic: Binding<CBCharacteristic?>,
        subscribedCentrals: [CBCentral]
    ) {
        self._selectedCharacteristic = selectedCharacteristic
        self.subscribedCentrals = subscribedCentrals
    }

    var body: some View {
        List {
            VStack(spacing: 24) {
                HStack {
                    Text("Data to update")
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 16) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            if text.isEmpty {
                                entryError = "Please enter something."
                                return
                            }
                            guard let data = text.data else {
                                self.entryError = "Failed to convert string to data."
                                return
                            }

                            guard let characteristic = selectedCharacteristic else {
                                self.entryError = "No characteristic selected."
                                return
                            }

                            try? peripheralManager.updateValueHelper(
                                data,
                                for: characteristic,
                                onSubscribedCentrals: selectedCentrals
                            )
                            dismiss()
                        } label: {
                            Text("Send")
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                }

                if !subscribedCentrals.isEmpty {
                    VStack(spacing: 12) {
                        Button {
                            showPicker.toggle()
                        } label: {
                            HStack {
                                Text(
                                    "Notifying: \(selectedCentrals.count == subscribedCentrals.count ? Self.allCentrals : "\(selectedCentrals.count) centrals")"
                                )
                                .lineLimit(1)
                                Spacer()

                                Image(systemName: showPicker ? "chevron.up" : "chevron.down")
                            }
                        }
                        .buttonStyle(.plain)

                        if showPicker {
                            Button {
                                if selectedCentrals.count < subscribedCentrals.count {
                                    selectedCentrals = subscribedCentrals
                                } else {
                                    selectedCentrals = []
                                }
                            } label: {
                                HStack {
                                    Image(
                                        systemName: selectedCentrals.count == subscribedCentrals.count
                                            ? "checkmark.square" : "square"
                                    )
                                    .resizable()
                                    .fontWeight(.bold)
                                    .frame(width: 12, height: 12)
                                    Text(Self.allCentrals)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Divider()

                            ForEach(0..<subscribedCentrals.count, id: \.self) { index in
                                let central: CBCentral = subscribedCentrals[index]
                                let id = central.identifier.uuidString
                                Button {
                                    if selectedCentrals.contains(central) {
                                        selectedCentrals.removeAll(where: { $0 == central })
                                    } else {
                                        selectedCentrals.append(central)
                                    }
                                } label: {
                                    HStack {
                                        Image(
                                            systemName: selectedCentrals.contains(where: { $0.identifier.uuidString == id })
                                                ? "checkmark.square" : "square"
                                        )
                                        .resizable()
                                        .fontWeight(.bold)
                                        .frame(width: 12, height: 12)
                                        Text(id)
                                            .multilineTextAlignment(.leading)

                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                }
                            }
                        }

                    }
                }

                let mtu =
                    subscribedCentrals.isEmpty ? 512 : subscribedCentrals.map({ $0.maximumUpdateValueLength }).min() ?? 512

                let currentBytes = text.data?.count ?? 0

                VStack {
                    Text("Max data length: \(mtu) bytes.")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.gray)

                    Text("Current: \(currentBytes) bytes.")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.gray)

                    TextField("", text: $text, axis: .vertical)
                        .lineLimit(5, reservesSpace: true)

                    if let entryError {
                        Text(entryError)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.red)
                    }

                }

            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(.all, 32)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents(.init([.fraction(0.5)]))
        .onAppear {
            entryError = ""
            text = ""
            selectedCentrals = subscribedCentrals
        }
    }
}