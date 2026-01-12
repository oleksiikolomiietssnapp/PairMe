//
//  AddCharacteristic.swift
//  PairMe
//
//  Created by Oleksii Kolomiiets on 1/12/26.
//

import CoreBluetooth
import SwiftUI

struct AddCharacteristic: View {
    @Environment(\.dismiss) var dismiss
    @State private var cachedValueString: String = ""
    @State private var characteristicDescription: String = ""
    @State private var allowedProperties: CBCharacteristicProperties = []

    @Binding private var addedCharacteristics: [CBMutableCharacteristic]

    init(
        addedCharacteristics: Binding<[CBMutableCharacteristic]>
    ) {
        self._addedCharacteristics = addedCharacteristics
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("New Characteristic")
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .foregroundStyle(.red)
                    }

                    Button {
                        var permissions: CBAttributePermissions = []
                        if allowedProperties.contains(.read) {
                            permissions.insert(.readable)
                        }
                        if allowedProperties.contains(.write) || allowedProperties.contains(.writeWithoutResponse) {
                            permissions.insert(.writeable)
                        }
                        let data = cachedValueString.isEmpty ? cachedValueString.data : cachedValueString.data
                        let newCharacteristic: CBMutableCharacteristic = CBMutableCharacteristic(
                            type: CBUUID(nsuuid: UUID()),
                            properties: allowedProperties,
                            value: data,
                            permissions: permissions
                        )

                        if !characteristicDescription.isEmpty {
                            let descriptor = CBMutableDescriptor(
                                type: CBUUID(string: CBUUIDCharacteristicUserDescriptionString),
                                value: characteristicDescription
                            )
                            newCharacteristic.descriptors = [descriptor]
                        }

                        self.addedCharacteristics.append(newCharacteristic)
                        dismiss()
                    } label: {
                        Text("Add")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

            }

            VStack {
                Text("Allow")
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 24) {
                    Button(
                        action: {
                            if allowedProperties.contains(.read) {
                                allowedProperties.remove(.read)
                            } else {
                                allowedProperties.insert(.read)
                            }
                        },
                        label: {
                            HStack {
                                Text("Read")
                                Image(systemName: allowedProperties.contains(.read) ? "checkmark.square" : "square")
                                    .resizable()
                                    .fontWeight(.bold)
                                    .frame(width: 12, height: 12)
                            }

                        }
                    )

                    Button(
                        action: {
                            if allowedProperties.contains(.notify) {
                                allowedProperties.remove(.notify)
                            } else {
                                allowedProperties.insert(.notify)
                            }
                        },
                        label: {
                            HStack {
                                Text("Notify")
                                Image(systemName: allowedProperties.contains(.notify) ? "checkmark.square" : "square")
                                    .resizable()
                                    .fontWeight(.bold)
                                    .frame(width: 12, height: 12)
                            }

                        }
                    )

                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 24) {
                    Button {
                        if allowedProperties.contains(.write) {
                            allowedProperties.remove(.write)
                        } else {
                            allowedProperties.insert(.write)
                        }
                    } label: {
                        HStack {
                            Text("Write")
                            Image(systemName: allowedProperties.contains(.write) ? "checkmark.square" : "square")
                                .resizable()
                                .fontWeight(.bold)
                                .frame(width: 12, height: 12)
                        }
                    }

                    Button {
                        if allowedProperties.contains(.writeWithoutResponse) {
                            allowedProperties.remove(.writeWithoutResponse)
                        } else {
                            allowedProperties.insert(.writeWithoutResponse)
                        }
                    } label: {
                        HStack {
                            Text("Write without response")
                            Image(systemName: allowedProperties.contains(.writeWithoutResponse) ? "checkmark.square" : "square")
                                .resizable()
                                .fontWeight(.bold)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack {
                Text("Cached Value")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Leave it empty to use dynamic value.")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.gray)

                TextField("", text: $cachedValueString, axis: .vertical)
                    .lineLimit(2, reservesSpace: true)
            }

            VStack {
                Text("Description")
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("", text: $characteristicDescription, axis: .vertical)
                    .lineLimit(2, reservesSpace: true)

            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(.all, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.fraction(0.6)])
        .interactiveDismissDisabled()
        .onAppear {
            allowedProperties = []
            cachedValueString = ""
        }

    }
}
