//
//  BluetoothManager.swift
//  PairMe
//
//  Created by Oleksii Kolomiiets on 1/10/26.
//

import CoreBluetooth
import Observation
import SwiftUI

enum PeripheralManagerError: Error {
    case invalidManager
    case bluetoothNotAvailable

    case addServiceError(String)
    case removeServiceError(String)
    case startAdvertisingError(String)

    case updateValueError(String)
}

@Observable
class PeripheralManager: NSObject {
    var error: PeripheralManagerError? = nil

    var subscribedCentrals: [CBCharacteristic: [CBCentral]] = [:]
    var addedServices: [CBMutableService] = []
    var characteristicData: [CBCharacteristic: [Data]] = [:]

    private var peripheralManager: CBPeripheralManager?
    private let managerUID: NSString = "PairMePeripheralManager"

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: nil,
            options: [
                CBPeripheralManagerOptionShowPowerAlertKey: true,
                CBPeripheralManagerOptionRestoreIdentifierKey: managerUID,
            ]
        )
    }

    @MainActor
    public func addService(_ service: CBMutableService) {
        guard checkBluetooth() else { return }

        guard let peripheralManager else {
            self.error = .invalidManager
            return
        }

        guard !self.addedServices.contains(where: { $0.uuid == service.uuid }) else {
            self.error = .addServiceError("Service exists.")
            return
        }

        service.characteristics?.forEach { characteristic in
            if !validateCharacteristic(characteristic as? CBMutableCharacteristic) {
                return
            }
        }

        service.includedServices?.forEach { service in
            if !validateIncludedServices(service) {
                return
            }
        }

        peripheralManager.add(service)
        self.addedServices.append(service)
    }

    @MainActor
    public func removeService(_ service: CBMutableService) {
        checkBluetooth()

        guard let peripheralManager else {
            error = .invalidManager
            return
        }

        for addedService in addedServices {
            guard let includedServices = addedService.includedServices,
                  includedServices.contains(where: { $0.uuid == service.uuid })
            else { continue }

            error = .removeServiceError("Service `\(service.uuid)` is included in another service")
        }

        addedServices.removeAll(where: { $0.uuid == service.uuid })
        peripheralManager.remove(service)
    }

    @MainActor
    public func startAdvertising() {
        checkBluetooth()

        guard !addedServices.isEmpty else {
            error = .startAdvertisingError("No added services")
            return
        }

        guard let peripheralManager else {
            error = .invalidManager
            return
        }

        guard peripheralManager.state != .poweredOn else {
            stopAdvertising()
            error = .bluetoothNotAvailable
            return
        }

        let serviceUUIDs: [CBUUID] = addedServices.map { $0.uuid }
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: serviceUUIDs
        ])
    }

    @MainActor
    public func stopAdvertising() {
        peripheralManager?.stopAdvertising()
    }

    private func validateIncludedServices(_ service: CBService) -> Bool {
        let isPublished = addedServices.contains(where: { $0.uuid == service.uuid })
        if !isPublished {
            error = .addServiceError("Included service is not published.")
        }
        return isPublished
    }

    private func validateCharacteristic(_ characteristic: CBMutableCharacteristic?) -> Bool {
        guard let characteristic else {
            return true
        }

        let isCharacteristicReadOnly: Bool = characteristic.properties == .read || characteristic.permissions == .readable
        guard characteristic.value == nil, isCharacteristicReadOnly else {
            self.error = .addServiceError("Characteristic with cached value should be read-only.")
            return false
        }

        let isReadPermissionAndPropertiesMismatch: Bool = characteristic.properties.contains(.read) && !characteristic.permissions.contains(.readable)
        let isWriteProperties: Bool = characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse)
        let isWritePermissionsAndPropertiesMismatch: Bool = isWriteProperties && !characteristic.permissions.contains(.writeable)
        guard !isReadPermissionAndPropertiesMismatch, !isWritePermissionsAndPropertiesMismatch else {
            self.error = .addServiceError("Permission and Properties mismatch.")
            return false
        }

        let isBroadcastAndExtendedPropertiesSupported: Bool = characteristic.properties.contains(.broadcast) || characteristic.properties.contains(.extendedProperties)
        guard !isBroadcastAndExtendedPropertiesSupported else {
            self.error = .addServiceError("Broadcast and extended properties are not supported for local peripheral service.")
            return false
        }

        return true
    }

    @discardableResult
    private func checkBluetooth(fro state: CBManagerState? = nil) -> Bool {
        if (state ?? peripheralManager?.state) != .poweredOn {
            self.error = .bluetoothNotAvailable
            return false
        }
        return true
    }
}

extension PeripheralManager: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        checkBluetooth(fro: peripheral.state)
    }
}
