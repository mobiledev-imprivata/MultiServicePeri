//
//  BluetoothManager.swift
//  MultiServicePeri
//
//  Created by Jay Tucker on 2/5/18.
//  Copyright © 2018 Imprivata. All rights reserved.
//

import UIKit
import CoreBluetooth

protocol BluetoothManagerDelegate {
    func servicesDidChange(_ indices: [Int])
}

final class BluetoothManager: NSObject {
    
    var delegate:BluetoothManagerDelegate?

    // the first UUID is service, the second UUID is characteristic
    private let uuidPairs = [
        (
            // service 0
            CBUUID(string: "A85E0941-9312-43E0-9DF1-AA553F8D1DCC"),
            CBUUID(string: "1C2218C7-C773-4DAC-B52B-DA6061614A56")
        ),
        (
            // service 1
            CBUUID(string: "F1DB91CA-E679-4B74-BB44-64F547E586B5"),
            CBUUID(string: "E96B5F2A-01C5-40B3-8A03-85529693C3DD")
        )
    ]

    var serviceCount: Int { return uuidPairs.count }

    // currently running services
    private var services = [CBMutableService]() {
        didSet {
            let serviceIndices = services.map { indexForServiceUUID($0.uuid) }
            log("services changed to \(serviceIndices)")
        }
    }
    
    private var peripheralManager: CBPeripheralManager?
    
    private let restoreIdentiferKey = "com.imprivata.MultiServicePeri.restoreIdentiferKey"
    
    private var uiBackgroundTaskIdentifier: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    override init() {
        super.init()
        
        startPeripheralManager()
    }
    
    private func startPeripheralManager() {
        log("startPeripheralManager")
        guard peripheralManager == nil else { return }
        let options = [CBPeripheralManagerOptionRestoreIdentifierKey: restoreIdentiferKey]
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: options)
    }
    
    private func stopPeripheralManager() {
        log("stopPeripheralManager")
        guard peripheralManager == peripheralManager else { return }
        peripheralManager?.stopAdvertising()
        peripheralManager = nil
    }
    
    func startService(index: Int) {
        log("startService \(index)")
        guard peripheralManager?.state == .poweredOn else {
            log("not powered on")
            return
        }
        guard 0 <= index && index < serviceCount else {
            log("index out of bounds")
            return
        }
        let serviceUUID = uuidPairs[index].0
        guard services.isEmpty || !(services.map { $0.uuid }).contains(serviceUUID) else {
            log("service is already running")
            return
        }
        let service = createService(serviceUUID: uuidPairs[index].0, characteristicUUID: uuidPairs[index].1)
        services.append(service)
        peripheralManager?.add(service)
    }
    
    func stopService(index: Int) {
        log("stopService \(index)")
        guard peripheralManager?.state == .poweredOn else {
            log("not powered on")
            return
        }
        guard 0 <= index && index < serviceCount else {
            log("index out of bounds")
            return
        }

        let serviceUUID = uuidPairs[index].0

        guard let serviceToRemove = (services.filter { $0.uuid == serviceUUID }).first else {
            log("service is not running")
            return
        }

        peripheralManager?.remove(serviceToRemove)
        services = services.filter { $0.uuid != serviceUUID }
        
        // Is this code necessary? It seems to be.
        peripheralManager?.stopAdvertising()
        if !services.isEmpty {
            let serviceUUIDs = services.map { $0.uuid }
            peripheralManager?.startAdvertising(([CBAdvertisementDataServiceUUIDsKey: serviceUUIDs]))
        }
    }
    
    // MARK: helper methods
    
    private func createService(serviceUUID: CBUUID, characteristicUUID: CBUUID) -> CBMutableService {
        log("createService")
        let service = CBMutableService(type: serviceUUID, primary: true)
        let characteristic = CBMutableCharacteristic(type: characteristicUUID, properties: .read, value: nil, permissions: .readable)
        service.characteristics = [characteristic]
        return service
    }
    
    private func indexForServiceUUID(_ serviceUUID: CBUUID) -> Int {
        for (index, uuidPair) in uuidPairs.enumerated() {
            if serviceUUID == uuidPair.0 {
                return index
            }
        }
        return -1
    }
    
}

extension BluetoothManager: CBPeripheralManagerDelegate {
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        log("peripheralManager willRestoreState")
        if let restoredServices = (dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService]) {
            log("found \(restoredServices.count) services")
            for service in restoredServices {
                let index = indexForServiceUUID(service.uuid)
                log("\(index) \(service.uuid.uuidString)")
            }
            services = restoredServices
            delegate?.servicesDidChange(services.map { indexForServiceUUID($0.uuid) })
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        var caseString: String!
        switch peripheral.state {
        case .unknown:
            caseString = "unknown"
        case .resetting:
            caseString = "resetting"
        case .unsupported:
            caseString = "unsupported"
        case .unauthorized:
            caseString = "unauthorized"
        case .poweredOff:
            caseString = "poweredOff"
        case .poweredOn:
            caseString = "poweredOn"
        }
        log("peripheralManagerDidUpdateState \(caseString!)")
        
        if peripheral.state == .poweredOn {
            log("service count \(services.count)")
            if !services.isEmpty {
                log("peripheral.isAdvertising \(peripheral.isAdvertising)")
                if !peripheral.isAdvertising {
                    let serviceUUIDs = services.map { $0.uuid }
                    peripheralManager?.startAdvertising(([CBAdvertisementDataServiceUUIDsKey: serviceUUIDs]))
                }
            }
            else {
                log("removeAllServices")
                peripheral.removeAllServices()
            }
        }
        else if peripheral.state == .poweredOff {
            stopPeripheralManager()
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        let index = indexForServiceUUID(service.uuid)
        let message = "peripheralManager didAddService " + (error == nil ? "\(index)" :  ("error " + error!.localizedDescription))
        log(message)
        guard error == nil else { return }
        // isServiceInitialized = true
        // peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [service.uuid]])
        peripheralManager?.stopAdvertising()
        let serviceUUIDs = services.map { $0.uuid }
        peripheralManager?.startAdvertising(([CBAdvertisementDataServiceUUIDsKey: serviceUUIDs]))
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        let message = "peripheralManagerDidStartAdvertising " + (error == nil ? "ok" :  ("error " + error!.localizedDescription))
        log(message)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        beginBackgroundTask()
        let index = indexForServiceUUID(request.characteristic.service.uuid)
        log("peripheralManager didReceiveRead request for service \(index)")
        request.value = "Hello from service \(index)!".data(using: .utf8, allowLossyConversion: false)
        peripheral.respond(to: request, withResult: .success)
        endBackgroundTask()
    }
    
}

// MARK: background task

extension BluetoothManager {
    
    private func beginBackgroundTask() {
        uiBackgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            [unowned self] in
            log("uiBackgroundTaskIdentifier \(self.uiBackgroundTaskIdentifier) expired")
            UIApplication.shared.endBackgroundTask(self.uiBackgroundTaskIdentifier)
            self.uiBackgroundTaskIdentifier = UIBackgroundTaskInvalid
        })
        log("beginBackgroundTask uiBackgroundTaskIdentifier \(uiBackgroundTaskIdentifier)")
    }
    
    private func endBackgroundTask() {
        log("endBackgroundTask uiBackgroundTaskIdentifier \(uiBackgroundTaskIdentifier)")
        UIApplication.shared.endBackgroundTask(uiBackgroundTaskIdentifier)
        uiBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    }
    
}
