//
//  AddServiceView.swift
//  PairMe
//
//  Created by Oleksii Kolomiiets on 1/12/26.
//

import CoreBluetooth
import SwiftUI

struct AddServiceView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.peripheralManager) var peripheralManager
    @State private var isPrimary: Bool = false
    @State private var addedCharacteristics: [CBMutableCharacteristic] = []
    @State private var includedServices: [CBMutableService] = []
    @State private var showAddCharacteristicSheet: Bool = false
    @State private var showPicker: Bool = false
    private static let allServices = "(all)"

    var body: some View {
        List {
            VStack(spacing: 24) {
                HStack {
                    Text("New Service")
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
                            let service = CBMutableService(type: CBUUID(nsuuid: UUID()), primary: isPrimary)
                            service.characteristics = addedCharacteristics
                            let includedServices: [CBService] = self.includedServices.map({ $0 as CBService })

                            service.includedServices = includedServices

                            peripheralManager.addService(service)
                            dismiss()
                        } label: {
                            Text("Add")
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Button {
                    isPrimary.toggle()
                } label: {
                    HStack {
                        Text("Primary")
                        Image(systemName: isPrimary ? "checkmark.square" : "square")
                            .resizable()
                            .fontWeight(.bold)
                            .frame(width: 12, height: 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !peripheralManager.addedServices.isEmpty {
                    VStack(spacing: 12) {
                        Button {
                            showPicker.toggle()
                        } label: {
                            HStack {
                                Text(
                                    "Include: \(includedServices.count == peripheralManager.addedServices.count ? Self.allServices : "\(includedServices.count) services")"
                                )
                                .lineLimit(1)
                                Spacer()

                                Image(systemName: showPicker ? "chevron.up" : "chevron.down")
                            }

                        }
                        .buttonStyle(.plain)

                        if showPicker {
                            Button {
                                if includedServices.count < peripheralManager.addedServices.count {
                                    includedServices = peripheralManager.addedServices
                                } else {
                                    includedServices = []
                                }
                            } label: {
                                HStack {
                                    Image(
                                        systemName: includedServices.count == peripheralManager.addedServices.count
                                            ? "checkmark.square" : "square"
                                    )
                                    .resizable()
                                    .fontWeight(.bold)
                                    .frame(width: 12, height: 12)
                                    Text(Self.allServices)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Divider()

                            ForEach(0..<peripheralManager.addedServices.count, id: \.self) { index in
                                let central: CBMutableService = peripheralManager.addedServices[index]
                                let id = central.uuid.uuidString
                                Button(
                                    action: {
                                        if includedServices.contains(central) {
                                            includedServices.removeAll(where: { $0 == central })
                                        } else {
                                            includedServices.append(central)
                                        }
                                    },
                                    label: {
                                        HStack {
                                            Image(
                                                systemName: includedServices.contains(where: { $0.uuid.uuidString == id })
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
                                )

                            }
                        }
                    }
                }

                VStack(spacing: 12) {
                    HStack {
                        Text("Characteristics")
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            showAddCharacteristicSheet = true
                        } label: {
                            Text("Add")
                        }
                    }

                    if addedCharacteristics.isEmpty {
                        Text("No Characteristics added yet.")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.gray)

                    }

                    ForEach(addedCharacteristics, id: \.uuid) { characteristic in
                        HStack(spacing: 16) {
                            Button {
                                addedCharacteristics.removeAll(where: { $0.uuid == characteristic.uuid })
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }

                            VStack(spacing: 8) {
                                Text("ID: \(characteristic.uuid)")
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text("Allow: \(characteristic.properties.string)")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                let value = characteristic.value?.string ?? ""
                                Text("Value: \(value.isEmpty ? "(none)" : value)")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                        }

                    }
                }
            }
        }
        .listStyle(.inset)
        .scrollBounceBehavior(.basedOnSize)
        .textFieldStyle(.roundedBorder)
        .padding(.all, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        .interactiveDismissDisabled()
        .onAppear {
            includedServices = []
            addedCharacteristics = []
            isPrimary = true
        }
        .sheet(isPresented: $showAddCharacteristicSheet) {
            AddCharacteristic(addedCharacteristics: $addedCharacteristics)
        }
    }
}
