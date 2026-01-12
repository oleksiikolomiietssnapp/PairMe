//
//  CharacteristicCellView.swift
//  PairMe
//
//  Created by Oleksii Kolomiiets on 1/13/26.
//

import CoreBluetooth
import SwiftUI

struct CharacteristicCellView: View {
    @Environment(\.peripheralManager) var peripheralManager
    @State private var showAdvertisementDetail: Bool = false
    var updateValueAction: () -> Void
    var characteristic: CBCharacteristic

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ID: \(characteristic.uuid)")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(
                    action: {
                        updateValueAction()
                    },
                    label: {
                        Text("Update Value")
                    }
                )
                .font(.subheadline)
                .foregroundStyle(.blue)
            }

            if !characteristic.userDescription.isEmpty {
                Text("Description: \(characteristic.userDescription)")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Allow: \(characteristic.properties.string)")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            let value = characteristic.value?.string ?? ""
            let advertisementData: [Data] = peripheralManager.characteristicData[characteristic] ?? []

            if advertisementData.isEmpty {
                Text("Value: \(value.isEmpty ? "(none)" : value)")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)

            } else {
                Button(
                    action: {
                        showAdvertisementDetail.toggle()
                    },
                    label: {
                        HStack {
                            Text("Value: \(advertisementData.first!.string.isEmpty ? "(none)" : advertisementData.first!.string)")
                            if advertisementData.count > 1 {
                                Image(systemName: showAdvertisementDetail ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                )
                .font(.subheadline)
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

                if showAdvertisementDetail && advertisementData.count > 1 {
                    ForEach(1..<advertisementData.count, id: \.self) { index in
                        let data = advertisementData[index]
                        Text("- \(data.string.isEmpty ? "(none)" : data.string)")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)

                    }
                }
            }

            let centralIds =
                peripheralManager.subscribedCentrals[characteristic]?.map({ $0.identifier.uuidString }).joined(separator: ", ") ?? ""

            Text("Subscribed channels: \(centralIds.isEmpty ? "(none)" : centralIds)")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

        }
    }
}
