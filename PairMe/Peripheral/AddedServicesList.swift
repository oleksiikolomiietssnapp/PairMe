//
//  AddedServicesList.swift
//  PairMe
//
//  Created by Oleksii Kolomiiets on 1/12/26.
//

import CoreBluetooth
import SwiftUI

struct AddedServicesList: View {
    @Environment(\.peripheralManager) var peripheralManager
    private var isEditing: Bool
    @Binding private var isAdvertising: Bool

    init(isAdvertising: Binding<Bool>, isEditing: Bool) {
        self._isAdvertising = isAdvertising
        self.isEditing = isEditing
    }

    var body: some View {
        List {
            Section {
                if peripheralManager.addedServices.isEmpty {
                    Text("Add a service to begin advertising.")
                } else {
                    ForEach(peripheralManager.addedServices, id: \.uuid) { service in
                        if isEditing {
                            Button {
                                isAdvertising = false
                                peripheralManager.removeService(service)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }

                        NavigationLink(value: service) {
                            VStack {
                                Text("ID: \(service.uuid)")
                                Group {
                                    Text("Primary: \(service.isPrimary ? "Yes" : "No")")
                                    Text("Characteristics: \(service.characteristics?.count ?? 0)")
                                    Text("Included services: \(service.includedServices?.count ?? 0)")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(isEditing)
                    }
                }
            } header: {
                Text("Added services")
            }
        }
        .listStyle(.inset)
        .scrollBounceBehavior(.basedOnSize)
    }
}


extension CBCharacteristic {
    var userDescription: String {
        if self.descriptors == nil || self.descriptors!.isEmpty {
            return ""
        }
        let descriptors = self.descriptors!
        for descriptor in descriptors {
            if descriptor.uuid == CBUUID(string: CBUUIDCharacteristicUserDescriptionString) {
                return descriptor.value as? String ?? ""
            }
        }
        return ""
    }
}
