//
//  CentralManager.swift
//  PairMe
//
//  Created by Oleksii Kolomiiets on 1/13/26.
//

import CoreBluetooth
import Foundation
import OSLog

enum CentralManagerError: Error, LocalizedError, Equatable {
    static func == (lhs: CentralManagerError, rhs: CentralManagerError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }

    case unknownError(Error)
    case invalidManager
    case bluetoothNotAvailable
    case writeCharacteristicError(String)
    case disConnectError(String)
    case discoverServicesError(String)
    case discoverIncludedServicesError(String)
    case discoverCharacteristicsError(String)
    case discoverDescriptorError(String)
    case updateNotificationStateError(String)
    case updateCharacteristicValueError(String)
    case updateDescriptorValueError(String)

    init(error: Error) {
        if let centralManagerError = error as? CentralManagerError {
            self = centralManagerError
        } else {
            self = .unknownError(error)
        }
    }
}

struct ScanningOption: Equatable {
    var serviceUUID: [CBUUID]?
    var allowDuplicates: Bool
    var solicitedServiceUUIDs: [CBUUID] = []
}

@Observable
class CentralManager: NSObject {
    var error: CentralManagerError? = nil {
        didSet {
            if error != nil {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    self?.error = nil

                }
            }
        }
    }
    var discoveredPeripherals: [CBPeripheral] = []
    var receivedData: [CBCharacteristic: [Data]] = [:]
    var restoredScanningOptions: ScanningOption? = nil
    @ObservationIgnored var scanningOptions: ScanningOption = ScanningOption(allowDuplicates: false)

    private var centralManager: CBCentralManager?
    private let managerUID: NSString = "PairMeCentralManager"

    override init() {
        super.init()

        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionShowPowerAlertKey: true,
                CBCentralManagerOptionRestoreIdentifierKey: managerUID,
            ]
        )
    }
}

extension CentralManager {
    @MainActor
    public func startScanning(
        serverUUIDs: [CBUUID]?,
        allowDuplicateKey: Bool = false,
        solicitationUUIDs: [CBUUID] = []
    ) {
        do {
            try checkBluetooth()

            let centralManager = try strongCentralManager()

            for peripheral in self.discoveredPeripherals {
                cleanup(peripheral, centralManager: centralManager)
            }
            self.discoveredPeripherals.removeAll()
            self.scanningOptions = ScanningOption(
                serviceUUID: serverUUIDs,
                allowDuplicates: allowDuplicateKey,
                solicitedServiceUUIDs: solicitationUUIDs
            )

            centralManager.scanForPeripherals(
                withServices: serverUUIDs,
                options: [
                    CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicateKey,
                    CBCentralManagerScanOptionSolicitedServiceUUIDsKey: solicitationUUIDs,
                ]
            )
        } catch {
            setError(CentralManagerError(error: error))
        }
    }

    public func stopScanning() {
        do {
            try strongCentralManager().stopScan()
        } catch {
            setError(CentralManagerError(error: error))
        }
    }

    public func makeConnection(to peripheral: CBPeripheral) {
        do {
            try checkBluetooth()
            let centralManager = try strongCentralManager()

            os_log("Connecting to %@", "\(peripheral)")

            centralManager.connect(
                peripheral,
                options: [
                    CBConnectPeripheralOptionEnableAutoReconnect: true
                ]
            )
        } catch {
            setError(CentralManagerError(error: error))
        }
    }

    public func cancelConnection(of peripheral: CBPeripheral) {
        do {
            try checkBluetooth()
            let centralManager = try strongCentralManager()
            cleanup(peripheral, centralManager: centralManager)
            updatePeripheral(peripheral)
        } catch {
            setError(CentralManagerError(error: error))
        }
    }

    public func discoverServices(
        _ peripheral: CBPeripheral,
        serviceUUIDs: [CBUUID]? = nil
    ) {
        do {
            try checkBluetooth()
            peripheral.discoverServices(serviceUUIDs)
        } catch {
            setError(CentralManagerError(error: error))
        }
    }

    public func discoverServiceDetails(
        _ peripheral: CBPeripheral,
        for service: CBService,
        characteristicUUIDs: [CBUUID]? = nil,
        includedServiceUUIDs: [CBUUID]? = nil
    ) {
        do {
            try checkBluetooth()
            peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
            peripheral.discoverIncludedServices(includedServiceUUIDs, for: service)
        } catch {
            setError(CentralManagerError(error: error))
        }
    }

    public func discoverDescriptors(
        _ peripheral: CBPeripheral,
        for characteristic: CBCharacteristic
    ) {
        do {
            try checkBluetooth()
            peripheral.discoverDescriptors(for: characteristic)
        } catch {
            setError(CentralManagerError(error: error))
        }
    }

    public func setNotifying(
        _ peripheral: CBPeripheral,
        for characteristic: CBCharacteristic,
        flag: Bool
    ) {
        do {
            try checkBluetooth()
            guard characteristic.properties.contains(.notify) else {
                return
            }
            peripheral.setNotifyValue(flag, for: characteristic)
        } catch {
            setError(CentralManagerError(error: error))
        }
    }

    public func readCharacteristicValue(
        _ peripheral: CBPeripheral,
        for characteristic: CBCharacteristic
    ) {
        do {
            try checkBluetooth()
            peripheral.readValue(for: characteristic)
        } catch {
            setError(CentralManagerError(error: error))
        }
    }

    public func readDescriptorValue(
        _ peripheral: CBPeripheral,
        for descriptor: CBDescriptor
    ) {
        do {
            try checkBluetooth()
            peripheral.readValue(for: descriptor)
        } catch {
            setError(CentralManagerError(error: error))
        }
    }

    public func writeValue(
        _ peripheral: CBPeripheral,
        data: Data,
        for characteristic: CBCharacteristic,
        type: CBCharacteristicWriteType
    ) {
        do {
            try checkBluetooth()

            switch type {
            case .withResponse:
                if !characteristic.properties.contains(.write) {
                    setError(CentralManagerError.writeCharacteristicError("Invalid write type"))
                }
            case .withoutResponse:
                if !characteristic.properties.contains(.writeWithoutResponse) {
                    setError(CentralManagerError.writeCharacteristicError("Invalid write type"))
                }
            @unknown default:
                break
            }

            peripheral.writeValue(data, for: characteristic, type: type)

            if type == .withoutResponse, !characteristic.isNotifying {
                Task { [weak self] in
                    try await self?.checkWrite(peripheral, data: data, for: characteristic)
                }
            }
        } catch {
            setError(CentralManagerError(error: error))
        }
    }

    // MARK: - Private methods
    private func checkWrite(
        _ peripheral: CBPeripheral,
        data: Data,
        for characteristic: CBCharacteristic
    ) async throws {
        try checkBluetooth()

        let maxIterations = 10
        var current = 0

        while self.receivedData[characteristic]?.first != data && current < maxIterations {
            self.readCharacteristicValue(peripheral, for: characteristic)
            try? await Task.sleep(for: .seconds(1))
            current += 1
        }

        if current == maxIterations && self.receivedData[characteristic]?.first != data {
            setError(.writeCharacteristicError("Write without response may failed."))
            return
        }
    }

    private func updatePeripheral(_ peripheral: CBPeripheral) {
        Task { @MainActor [weak self] in
            if let index = self?.discoveredPeripherals.firstIndex(where: { $0.identifier == peripheral.identifier }) {
                self?.discoveredPeripherals.remove(at: index)
                self?.discoveredPeripherals.insert(peripheral, at: index)
            } else {
                self?.discoveredPeripherals.append(peripheral)
            }
        }
    }

    private func cleanup(_ peripheral: CBPeripheral, centralManager: CBCentralManager) {
        if peripheral.state == .connected, let peripheralServices = peripheral.services {
            for service in peripheralServices {
                if let characteristics = service.characteristics {
                    for characteristic in characteristics {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                }
            }
        }

        centralManager.cancelPeripheralConnection(peripheral)
    }

    private func strongCentralManager() throws -> CBCentralManager {
        guard let centralManager else {
            throw CentralManagerError.invalidManager
        }
        return centralManager
    }

    private func checkBluetooth(for state: CBManagerState? = nil) throws {
        if (state ?? centralManager?.state) != .poweredOn {
            throw CentralManagerError.bluetoothNotAvailable
        }
    }

    private func setError(_ error: CentralManagerError?) {
        Task { @MainActor [weak self] in
            self?.error = nil
        }
    }
}

// MARK: - Central Manager Delegate

extension CentralManager: CBCentralManagerDelegate {
    // MARK: centralManagerDidUpdateState
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        do {
            try checkBluetooth(for: central.state)
        } catch {
            setError(CentralManagerError(error: error))
        }
    }

    // MARK: willRestoreState
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        os_log("Central manager will restore: %@", "\(dict)")

        // previously connected peripherals
        let previousPeripheral = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        self.discoveredPeripherals = previousPeripheral
        os_log("previousPeripheral: %@", "\(previousPeripheral)")

        let previousScanningService: [CBUUID]? = dict[CBCentralManagerRestoredStateScanServicesKey] as? [CBUUID]
        let previousScanOptions = dict[CBCentralManagerRestoredStateScanOptionsKey] as? Dictionary ?? [:]
        let allowDuplicatesKey: Bool = previousScanOptions[CBCentralManagerScanOptionAllowDuplicatesKey] as? Bool ?? false
        let solicitedServiceUUIDs: [CBUUID] = previousScanOptions[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] as? [CBUUID] ?? []

        let scanningOptions = ScanningOption(
            serviceUUID: previousScanningService,
            allowDuplicates: allowDuplicatesKey,
            solicitedServiceUUIDs: solicitedServiceUUIDs
        )
        self.scanningOptions = scanningOptions

        Task { @MainActor [weak self] in
            self?.restoredScanningOptions = scanningOptions
        }
    }

    // MARK: didDiscover
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // if RSSI is tiny may ignore if needed
        os_log("Did discover peripheral: %@", "\(peripheral)")
        updatePeripheral(peripheral)
    }

    // MARK: didConnect
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("Did connect peripheral: %@", "\(peripheral)")
        peripheral.delegate = self
        discoverServices(peripheral, serviceUUIDs: self.scanningOptions.serviceUUID)
        updatePeripheral(peripheral)
    }

    // MARK: didFailToConnect
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        os_log("Failed to connect peripheral: %@", "\(peripheral)")

        cancelConnection(of: peripheral)

        if let error {
            setError(CentralManagerError(error: error))
        }
    }

    // MARK: didDisconnectPeripheral
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        timestamp: CFAbsoluteTime,
        isReconnecting: Bool,
        error: (any Error)?
    ) {
        os_log("Did disconnect peripheral: %@", "\(peripheral)")
        os_log("is reconnecting: %@", "\(isReconnecting)")

        cancelConnection(of: peripheral)

        if let error {
            os_log(.error, "Error: %@", "\(error)")
            setError(.disConnectError(error.localizedDescription))
            if !isReconnecting {
                makeConnection(to: peripheral)
            }
        }
    }
}

// MARK: - Central Manager Delegate

extension CentralManager: CBPeripheralDelegate {
    // MARK: didModifyServices
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        os_log("Did modify services: %@", "\(invalidatedServices)")
        discoverServices(peripheral, serviceUUIDs: invalidatedServices.map(\.uuid))
        self.updatePeripheral(peripheral)
    }

    // MARK: didDiscoverServices
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        os_log("Services discovered for peripheral: %@", "\(peripheral)")
        os_log("Services: %@", "\(peripheral.services ?? [])")
        os_log("%@", "\(self.discoveredPeripherals.first?.services ?? [])")

        do {
            try checkError(error)
            self.updatePeripheral(peripheral)
        } catch {
            setError(.discoverServicesError(error.localizedDescription))
        }
    }

    // MARK: didDiscoverIncludedServicesFor
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverIncludedServicesFor service: CBService,
        error: (any Error)?
    ) {
        os_log("Discover included services: %@", "\(service.includedServices ?? [])")

        do {
            try checkError(error)
            self.updatePeripheral(peripheral)
        } catch {
            setError(.discoverIncludedServicesError(error.localizedDescription))
        }
    }

    // MARK: didDiscoverCharacteristicsFor
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        os_log("Discover characteristics for services: %@", "\(service)")
        os_log("%@", "\(service.characteristics ?? [])")

        for characteristic in service.characteristics ?? [] {
            discoverDescriptors(peripheral, for: characteristic)
            readCharacteristicValue(peripheral, for: characteristic)
        }

        do {
            try checkError(error)
            self.updatePeripheral(peripheral)
        } catch {
            setError(.discoverCharacteristicsError(error.localizedDescription))
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverDescriptorsFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        os_log("descriptor found for characteristic: %@", "\(characteristic)")
        os_log("%@", "\(characteristic.descriptors as Any)")

        do {
            try checkError(error)
            if let userDescriptor = characteristic.descriptors?.first(where: {
                $0.uuid == CBUUID(string: CBUUIDCharacteristicUserDescriptionString)
            }) {
                self.readDescriptorValue(peripheral, for: userDescriptor)
            }
        } catch {
            setError(.discoverDescriptorError(error.localizedDescription))
        }
    }

    // MARK: didUpdateNotificationStateFor
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        os_log("Did update notification state for characteristic: %@", "\(characteristic)")

        do {
            try checkError(error)
            self.updatePeripheral(peripheral)
        } catch {
            setError(.updateNotificationStateError(error.localizedDescription))
        }
    }

    // MARK: didUpdateValueFor characteristic
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        os_log("Did update value for characteristic: %@", "\(characteristic)")

        do {
            try checkError(error)
            if let data = characteristic.value {
                if self.receivedData[characteristic] == nil {
                    self.receivedData[characteristic] = []
                }
                self.receivedData[characteristic]?.insert(data, at: 0)
            }
            self.updatePeripheral(peripheral)
        } catch {
            setError(.updateCharacteristicValueError(error.localizedDescription))
        }
    }

    //MARK: didUpdateValueFor descriptor
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor descriptor: CBDescriptor,
        error: (any Error)?
    ) {
        os_log("Did update value for descriptor: %@", "\(descriptor)")

        do {
            try checkError(error)
            self.updatePeripheral(peripheral)
        } catch {
            setError(.updateDescriptorValueError(error.localizedDescription))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        os_log("Did write value for characteristic: %@", "\(characteristic)")

        do {
            try checkError(error)
            self.updatePeripheral(peripheral)
        } catch {
            if !characteristic.isNotifying {
                self.readCharacteristicValue(peripheral, for: characteristic)
            } else {
                setError(.writeCharacteristicError(error.localizedDescription))
            }
        }
    }

    private func checkError(_ error: (any Error)?) throws {
        guard let error else { return }
        os_log(.error, "Error: %@", "\(error)")
        throw error
    }
}
