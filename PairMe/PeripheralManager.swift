//
//  PeripheralManager.swift
//  PairMe
//
//  Created by Oleksii Kolomiiets on 1/10/26.
//

import CoreBluetooth
import OSLog
import Observation
import SwiftUI

enum PeripheralManagerError: Error, LocalizedError {
    case invalidManager
    case bluetoothNotAvailable

    case addServiceError(String)
    case removeServiceError(String)
    case startAdvertisingError(String)

    case updateValueError(String)

    var errorDescription: String? {
        switch self {
        case .invalidManager:
            "Invalid manager"
        case .bluetoothNotAvailable:
            "Bluetooth not available"
        case .addServiceError(let string):
            "Add service error: \(string)"
        case .removeServiceError(let string):
            "Remove service error: \(string)"
        case .startAdvertisingError(let string):
            "Start advertising error: \(string)"
        case .updateValueError(let string):
            "Update value error: \(string)"
        }
    }
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

        let isReadPermissionAndPropertiesMismatch: Bool =
            characteristic.properties.contains(.read) && !characteristic.permissions.contains(.readable)
        let isWriteProperties: Bool =
            characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse)
        let isWritePermissionsAndPropertiesMismatch: Bool = isWriteProperties && !characteristic.permissions.contains(.writeable)
        guard !isReadPermissionAndPropertiesMismatch, !isWritePermissionsAndPropertiesMismatch else {
            self.error = .addServiceError("Permission and Properties mismatch.")
            return false
        }

        let isBroadcastAndExtendedPropertiesSupported: Bool =
            characteristic.properties.contains(.broadcast) || characteristic.properties.contains(.extendedProperties)
        guard !isBroadcastAndExtendedPropertiesSupported else {
            self.error = .addServiceError("Broadcast and extended properties are not supported for local peripheral service.")
            return false
        }

        return true
    }

    @MainActor
    func updateValueHelper(
        _ data: Data,
        for characteristic: CBCharacteristic,
        onSubscribedCentrals centrals: [CBCentral]?
    ) throws {
        let isNoCentral = centrals == nil || (centrals?.isEmpty == true)
        let mtu = isNoCentral ? 512 : centrals?.map { $0.maximumUpdateValueLength }.min() ?? 512

        guard data.count <= mtu else {
            throw PeripheralManagerError.updateValueError("Data is too long.")
        }

        guard let peripheralManager else {
            throw PeripheralManagerError.invalidManager
        }

        guard let mutable = characteristic as? CBMutableCharacteristic else {
            throw PeripheralManagerError.updateValueError("Characteristic is not mutable.")
        }

        let isValueUpdated = peripheralManager.updateValue(data, for: mutable, onSubscribedCentrals: centrals)

        if isValueUpdated {
            if self.characteristicData[characteristic] == nil {
                self.characteristicData[characteristic] = []
            }
            self.characteristicData[characteristic]?.insert(data, at: 0)
        } else {
            self.error = .updateValueError("Failed to update value.")
        }
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

    // MARK: didSubscribeTo
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        Task { @MainActor [weak self] in
            self?.subscribedCentrals[characteristic]?.removeAll(where: { $0 == central })
            if self?.subscribedCentrals[characteristic] == nil {
                self?.subscribedCentrals[characteristic] = []
            }
            self?.subscribedCentrals[characteristic]?.append(central)
        }
    }

    // MARK: didUnsubscribeFrom
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        Task { @MainActor [weak self] in
            self?.subscribedCentrals[characteristic]?.removeAll(where: { $0 == central })
        }
    }

    // MARK: didReceiveRead
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        let dataValue = self.characteristicData[request.characteristic]?.first as? Data
        request.value = dataValue ?? request.characteristic.value
        peripheral.respond(to: request, withResult: .success)
    }

    // MARK: didReceiveWrite
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        os_log("Peripheral receive write request")

        var data: Data = Data()

        for request in requests {
            guard var requestValue = request.value else {
                continue
            }
            requestValue = requestValue.dropFirst(request.offset)
            data.append(requestValue)
            os_log("Received write request of %@ bytes: %@", "\(requestValue.count)", requestValue.description)
        }

        if let firstRequest = requests.first {
            Task { @MainActor [weak self] in
                do {
                    try self?.updateValueHelper(data, for: firstRequest.characteristic, onSubscribedCentrals: nil)
                    peripheral.respond(to: firstRequest, withResult: .success)
                } catch {
                    if let peripheralManagerError = error as? PeripheralManagerError {
                        self?.error = peripheralManagerError
                    }
                    peripheral.respond(to: firstRequest, withResult: .invalidHandle)
                }
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        let previousServices = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] ?? []

        Task { @MainActor [weak self] in
            self?.addedServices = previousServices

            for previousService in previousServices {
                guard let characteristics = previousService.characteristics else { continue }

                for characteristic in characteristics {
                    guard let mutableCharacteristic = characteristic as? CBMutableCharacteristic else { continue }
                    self?.subscribedCentrals[characteristic] = mutableCharacteristic.subscribedCentrals
                }
            }
        }
    }

    // MARK: toUpdateSubscribers
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // to re-send or sending long amount of data(split into small chunks)
    }
}

extension CBCharacteristicProperties {
    var string: String {
        var results: [String] = []
        for option: CBCharacteristicProperties in [.read, .writeWithoutResponse, .write, .notify] {
            guard self.contains(option) else { continue }
            switch option {
            case .read: results.append("read")
            case .writeWithoutResponse, .write:
                if self.contains(.writeWithoutResponse) {
                    results.append("write(without response)")
                } else {
                    results.append("write")
                }
            case .notify: results.append("notify")
            default: fatalError()
            }
        }

        if results.isEmpty {
            return "(none)"
        }

        return results.joined(separator: ", ")
    }
}
