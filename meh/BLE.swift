/*
 Copyright (c) 2015 Fernando Reynoso
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 
    Borrowed and modified by J. Maunsell to support multiple active peripheral connections.
 */

import Foundation
import CoreBluetooth

public enum BLEState : Int, CustomStringConvertible {
    case unknown
    case resetting
    case unsupported
    case unauthorized
    case poweredOff
    case poweredOn
    
    public var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .resetting: return "Resetting"
        case .unsupported: return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff: return "Powered off"
        case .poweredOn: return "Powered on"
        }
    }
}

extension CBManagerState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .resetting: return "Resetting"
        case .unsupported: return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff: return "Powered off"
        case .poweredOn: return "Powered on"
        }
    }
}

protocol BLEDelegate {
    func ble(didUpdateState state: BLEState) // TODO: have this method handle periph-side stuff too
    func ble(didDiscoverPeripheral peripheral: CBPeripheral)
    func ble(didConnectToPeripheral peripheral: CBPeripheral)
    func ble(didDisconnectFromPeripheral peripheral: CBPeripheral)
    func ble(_ peripheral: CBPeripheral, didReceiveData data: Data?)
    
    // TODO: add methods that handle peripheral-side stuff
    // func ble(didUpdateCharacteristic ...)
    // func ble(didConnectToCentral ...)
    // func ble(didDisconnectFromCentral ...)
    
}


/**
 
 BLE as implemented in Anteater handles central -> peripheral(s) connections,
 only actively exchanging data with one peripheral at a time.
 
 What we want is a class that also handles peripheral -> central connections,
 which means adding in the CBPeripheralManagerDelegate protocol.
 Still OK for nodes to only actively exchange data one at a time.
 
 Both central -> peripheral connections and vice versa have the functionality 
 we need for message broadcasting, so peers only need to make one kind of connection.
 We want a generic API that handles the two different protocols behind-the-scenes.
 
 Each node should keep track the nodes it's connected to as a peripheral &
 the nodes it's connected to as a central.
 
 broadcast(message) {
    for node in nodes connected as peripherals: update message characteristic of node
    for node in nodes connected as centrals: send data to node
 }
 
 */
class BLE: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate , CBPeripheralManagerDelegate {
    
    let SERVICE_UUID = "713D0000-503E-4C75-BA94-3148F18D941E"
    let CHAR_INBOX_UUID = "713D0002-503E-4C75-BA94-3148F18D941E"
    let CHAR_OUTBOX_UUID = "713D0003-503E-4C75-BA94-3148F18D941E"
    
    var delegate: BLEDelegate?
    
    
    // Central Manager Delegate stuff
    private      var centralManager:   CBCentralManager!
    private      var activePeripheral: CBPeripheral?  // TODO: this may not be necessary ???
    //private      var characteristics = [String : CBCharacteristic]()
    
    private var outboxes = [UUID: CBCharacteristic]()
    
    private      var data:             NSMutableData? // <- not sure if this should be kept
    private(set) var connectedPeripherals: [CBPeripheral]?
    
    // Peripheral Manager Delegate stuff
    private      var peripheralManager: CBPeripheralManager!  // to handle connections made as a peripheral
    private(set) var subscribedCentrals: [CBCentral]?
    private var inbox : CBCharacteristic?

    
    private var peripheralData: [String: AnyObject]?
    var services: [CBMutableService]!
    
    
    // Map of known direct connections
    private(set) var connectionMap     = [UUID: [UUID]]()
    
    // UUIDs of all nodes connected (whether as central or peripheral)
    private(set) var directPeers: [UUID]?

    
    private      var RSSICompletionHandler: ((NSNumber?, Error?) -> ())?  // not sure if need to change RSSI stuff
    
    override init() {
        super.init()
        
        // TODO: do the two managers each need separate dispatch queues??
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        self.data = NSMutableData()
        
    }
    
    @objc private func scanTimeout() {
        
        print("[DEBUG] Scanning stopped")
        self.centralManager.stopScan()
    }
    
    // MARK: Public methods
    
    
    // scan for nodes to connect to as a central node
    // TODO: check that you're not already connected as a peripheral to a node you find
    func startScanning(timeout: Double) -> Bool {
        
        if centralManager.state != .poweredOn {
            print("[ERROR] Couldn´t start scanning")
            return false
        }
        
        print("[DEBUG] Scanning started")
        
        // CBCentralManagerScanOptionAllowDuplicatesKey
        
        Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(BLE.scanTimeout), userInfo: nil, repeats: false)
        
        let services:[CBUUID] = [CBUUID(string: SERVICE_UUID)]
        centralManager.scanForPeripherals(withServices: services, options: nil)
        
        return true
    }
    
    // stop scanning for nodes to connect to as a central node
    func stopScanning() {
        centralManager.stopScan()
    }
    
    // TODO: advertise for nodes to connect to as a central node
    // something like
    // func startAdvertising() {
    //  manager.startAdvertising(...)
    // }

    
    // TODO: announce to peers that new connection exists
    func connectToPeripheral(_ peripheral: CBPeripheral) -> Bool {
        
        if centralManager.state != .poweredOn {
            print("[ERROR] Couldn´t connect to peripheral")
            return false
        }
        
        print("[DEBUG] Connecting to peripheral: \(peripheral.identifier.uuidString)")
        
        centralManager.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(value: true)])
        
        return true
    }
    
    // TODO: announce to peers that connection is lost
    func disconnectFromPeripheral(_ peripheral: CBPeripheral) -> Bool {
        
        if centralManager.state != .poweredOn {
            
            print("[ERROR] Couldn´t disconnect from peripheral")
            return false
        }
        
        centralManager.cancelPeripheralConnection(peripheral)
        return true
    }
    
    // read data from peripheral you're actively connected to
    func read(uuid: UUID) {
        
        guard let char = characteristics[CHAR_OUTBOX_UUID] else { return }

        activePeripheral?.readValue(for: char)
        // characteristics =
        
    }
    
    // write data to inbox peripheral you're actively connected to
    func write(data: NSData, uuid: UUID) {
        
        guard let char = characteristics[CHAR_INBOX_UUID] else { return }
        activePeripheral?.writeValue(data as Data, for: char, type: .withoutResponse)
    }
    
    // enable notifications for updates to active peripheral's outbox characteristic
    func enableNotifications(enable: Bool) {
        
        guard let char = characteristics[CHAR_OUTBOX_UUID] else { return }
        
        activePeripheral?.setNotifyValue(enable, for: char)

        
    }
    
    // TODO: idk what we need to do about this lol
    func readRSSI(completion: @escaping (_ RSSI: NSNumber?, _ error: Error?) -> ()) {
        
        RSSICompletionHandler = completion
        activePeripheral?.readRSSI()
    }
    
    // MARK: CBCentralManager delegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        print("[DEBUG] Central manager state: \(central.state)")
        
        delegate?.ble(didUpdateState: BLEState(rawValue: central.state.rawValue)!)
    }
    
    // TODO: code from Anteater, need to fix
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("[DEBUG] Find peripheral: \(peripheral.identifier.uuidString) RSSI: \(RSSI)")
        /**
        
        let index = peripherals.index { ($0.identifier.uuidString) == (peripheral.identifier.uuidString) }
        
        if let index = index {
            peripherals[index] = peripheral
        } else {
            // ??
        }
 
         */
        
        delegate?.ble(didDiscoverPeripheral: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[ERROR] Could not connect to peripheral \(peripheral.identifier.uuidString) error: \(error!.localizedDescription)")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        print("[DEBUG] Connected to peripheral \(peripheral.identifier.uuidString)")
        
        
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID(SERVICE_UUID)])
        
        delegate?.ble(didConnectToPeripheral: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        var text = "[DEBUG] Disconnected from peripheral: \(peripheral.identifier.uuidString)"
        
        if error != nil {
            text += ". Error: \(error!.localizedDescription)"
        }
        
        print(text)
        
        activePeripheral?.delegate = nil
        activePeripheral = nil
        characteristics.removeAll(keepingCapacity: false)
        
        delegate?.ble(didDisconnectFromPeripheral: peripheral)
    }
    
    // MARK: CBPeripheral delegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if error != nil {
            print("[ERROR] Error discovering services. \(error!.localizedDescription)")
            return
        }
        
        print("[DEBUG] Found services for peripheral: \(peripheral.identifier.uuidString)")
        
        
        for service in peripheral.services! {
            let theCharacteristics = [CBUUID(redBearType: .charRx), CBUUID(redBearType: .charTx)]
            
            peripheral.discoverCharacteristics(theCharacteristics, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if error != nil {
            print("[ERROR] Error discovering characteristics. \(error!.localizedDescription)")
            return
        }
        
        print("[DEBUG] Found characteristics for peripheral: \(peripheral.identifier.uuidString)")
        
        for characteristic in service.characteristics! {
            characteristics[characteristic.uuid.uuidString] = characteristic
        }
        
        enableNotifications(enable: true)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        if error != nil {
            
            print("[ERROR] Error updating value. \(error!.localizedDescription)")
            return
        }
        
        if characteristic.uuid.uuidString == RBL_CHAR_TX_UUID {
            delegate?.ble(peripheral, didReceiveData: characteristic.value as Data?)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        RSSICompletionHandler?(RSSI, error)
        RSSICompletionHandler = nil
    }
    
    // TODO: required for PeripheralManagerDelegate protocol
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            peripheralManager.startAdvertising(peripheralData)
        } else if peripheral.state == .poweredOff {
            peripheralManager.stopAdvertising()
        }
    }
    
    /**
        based on sample code in http://stackoverflow.com/questions/39679737/cbperipheral-service-seems-to-be-invisible
    */
    func setupService() {
        let serviceUUID = CBUUID(string: RBL_SERVICE_UUID) // idk this was in some sample code
        let characteristicUUID = CBUUID(string: RBL_CHAR_RX_UUID) // or RBL_CHAR_TX_UUID ???
        
        let characteristic = CBMutableCharacteristic(type: characteristicUUID,
                                                     properties: .read,
                                                     value: "".data(using: .utf8),
                                                     permissions: .readable)
        
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        service.characteristics = [characteristic]
        
        services = [service]
        peripheralManager.add(service)
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [services[0].uuid]])
        
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        // if characteristic is outbox, add new subscriber to list of central nodes
        // who are reading our outbox, subscribedCentrals
        
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        // if characteristic is outbox,
        // remove central from subscribedCentrals
        // (and announce connection lost??)
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // if the queue was too full for updateValue previously,
        // we should have saved the message we wanted to add to the queue somewhere.
        // now that the queue has space, we should resend the message
        
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        // CBATTRequest sent by connected central wants to update Inbox characteristic of this peripheral
        // so call peripheralManager.respond(to:withResult:) to respond to the write request
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        // central wants to read from this peripheral's outbox, 
        // so call peripheralManager.respond(to:withResult:) to respond to the read request
    }

}
