/*
 Copyright (c) 2015 Fernando Reynoso
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 
    Borrowed and modified by 6.S062 ME$H group to support multiple active peripheral connections.
 */

import Foundation
import CoreBluetooth
import UIKit


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

public extension LazyMapCollection  {
    
    func toArray() -> [Element]{
        return Array(self)
    }
}

protocol BLEDelegate {
    func didUpdateState(state: BLEState)
    func didDiscoverPeripheral(peripheral: CBPeripheral)
    func didConnectToPeripheral(peripheral: CBPeripheral)
    func didDisconnectFromPeripheral(peripheral: CBPeripheral)
    func didReadPeerOutbox(_ peripheral: CBPeripheral, data: Data?)
    func didGetPeripheralUsername(peer: User)
    
    
    // TODO: add methods that handle peripheral-side stuff
    func centralDidReadOutbox(central: UUID, outboxContents: Data?)
    func didReceiveMessage(data: Data?, sender: String)
    func centralDidSubscribe(central: CBCentral)
    func centralDidUnsubscribe(central: CBCentral)
    
    func sendMessage(message: String, recipient: String)
    func writeToInbox(data: Data, username: String) -> Bool
    func addMessageToOutbox(message: UserMessage) -> Bool
    func overwriteOutbox(data: Data?)
    
    func jsonDataToMessage(data: Data) -> Message?
    func metadataToJSONData() -> Data?

    
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
    let CHAR_METADATA_UUID = "713D0004-503E-4C75-BA94-3148F18D941E"

    var delegate: BLEDelegate?
    
    
    // Central Manager Delegate stuff
    public      var bleCentralManager:   CBCentralManager!
    //private      var activePeripheral: CBPeripheral?  // TODO: this may not be necessary ???
    
    public var peerInboxes = [UUID: CBCharacteristic]()
    public var peerOutboxes = [UUID: CBCharacteristic]()
    public var peerMetadatas = [UUID: CBCharacteristic]()
    
    private      var data:             NSMutableData? // <- not sure if this should be kept
    public var connectedPeripherals = [UUID: CBPeripheral]()
    
    // Peripheral Manager Delegate stuff
    public      var blePeripheralManager: CBPeripheralManager!  // to handle connections made as a peripheral
    
    public var subscribedCentrals = [UUID: CBCentral]()
    public var inbox : CBMutableCharacteristic!
    public var outbox : CBMutableCharacteristic!
    public var metadata : CBMutableCharacteristic!
    
    private var peripheralData: [String: AnyObject]?
    var services: [CBMutableService]!

    
    private      var RSSICompletionHandler: ((NSNumber?, Error?) -> ())?  // not sure if need to change RSSI stuff
    
    override init() {
        super.init()
        
        // TODO: do the two managers each need separate dispatch queues??
        self.bleCentralManager = CBCentralManager(delegate: self, queue: nil)
        self.blePeripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        //setupService()
    }
    
    @objc private func scanTimeout() {
        
        print("[DEBUG] Scanning stopped")
        self.bleCentralManager.stopScan()
    }
    
    // MARK: Public methods
    
    
    // scan for nodes to connect to as a central node
    // TODO: check that you're not already connected as a peripheral to a node you find
    func startScanning(timeout: Double) -> Bool {
        
        if bleCentralManager.state != .poweredOn {
            print("[ERROR] Couldn´t start scanning")
            return false
        }
        
        print("[DEBUG] Scanning started")
        
        // CBCentralManagerScanOptionAllowDuplicatesKey
        
        Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(BLE.scanTimeout), userInfo: nil, repeats: false)
        
        bleCentralManager.scanForPeripherals(withServices: nil, options: nil)
        //let services:[CBUUID] = [CBUUID(string: SERVICE_UUID)]
        //bleCentralManager.scanForPeripherals(withServices: services, options: nil)
        
        return true
    }
    
    // stop scanning for nodes to connect to as a central node
    func stopScanning() {
        bleCentralManager.stopScan()
        print("ble central manager stopped scanning")
    }
    
    // TODO: announce to peers that new connection exists
    func connectToPeripheral(_ peripheral: CBPeripheral) -> Bool {
        
        if bleCentralManager.state != .poweredOn {
            print("[ERROR] Couldn´t connect to peripheral \(peripheral)")
            return false
        }
        
        print("[DEBUG] Connecting to peripheral: \(peripheral)")
        
        bleCentralManager.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(value: true)])
        
        // TODO: add peripheral to map connectedPeripherals
        self.connectedPeripherals[peripheral.identifier] = peripheral

        return true
    }
    
    // TODO: announce to peers that connection is lost
    func disconnectFromPeripheral(_ peripheral: CBPeripheral) -> Bool {
        
        if bleCentralManager.state != .poweredOn {
            
            print("[ERROR] Couldn´t disconnect from peripheral \(peripheral)")
            return false
        }
        
        bleCentralManager.cancelPeripheralConnection(peripheral)
        return true
    }


    // enable notifications for updates to given peripheral(as specified by the UUID)'s outbox characteristic
    func enableNotifications(enable: Bool, uuid: UUID) {
        
        print("enabling notifications for peer with uuid \(uuid)")
        
        guard let char = self.peerOutboxes[uuid] else { return }
        guard let peer = self.connectedPeripherals[uuid] else { return }
        
        peer.setNotifyValue(enable, for: char)
        
        print("this central has subscribed to the outbox characteristic \(char) of peripheral \(peer) ")
        
    }
    
    // TODO: idk what we need to do about this lol
    func readRSSI(uuid: UUID, completion: @escaping (_ RSSI: NSNumber?, _ error: Error?) -> ()) {
        
        RSSICompletionHandler = completion
     
        guard let peer = connectedPeripherals[uuid] else { return }
        peer.readRSSI()
    }
    
    // MARK: CBCentralManager delegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        print("[DEBUG] Central manager state: \(central.state)")
        
        delegate?.didUpdateState(state: BLEState(rawValue: central.state.rawValue)!)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        
        if let _ = self.connectedPeripherals[peripheral.identifier] {
            return // already discovered...
        }

        //print("[DEBUG] Find peripheral: \(peripheral.identifier.uuidString) RSSI: \(RSSI)")
        
        // TODO: check if peripheral UUID matches UUID in subscribedCentrals,
        // since each peer only needs to be subscribed as a central -or- connected as a peripheral
        
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            if serviceUUIDs.contains(CBUUID(string: SERVICE_UUID)) {
                print("advertisement for peripheral \(peripheral) contains our service :)")
                delegate?.didDiscoverPeripheral(peripheral: peripheral)
            }
        }

    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[ERROR] Could not connect to peripheral \(peripheral) error: \(error!.localizedDescription)")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        print("[DEBUG] Connected to peripheral \(peripheral)")
        
        
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID(string: SERVICE_UUID)])
        
        
        delegate?.didConnectToPeripheral(peripheral: peripheral)
        
        print("current connectedPeripherals count: \(self.connectedPeripherals.count)")
        print("current connectedPeripherals: \(self.connectedPeripherals)")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        var text = "[DEBUG] Disconnected from peripheral: \(peripheral)"
        
        self.connectedPeripherals[peripheral.identifier] = nil
        
        if error != nil {
            text += ". Error: \(error!.localizedDescription)"
        }
        
        print(text)
        delegate?.didDisconnectFromPeripheral(peripheral: peripheral)
    }
    
    // MARK: CBPeripheral delegate
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("peripheral \(peripheral) did modify services: services are now \(peripheral.services)")
        print("invalidated services (if any): \(invalidatedServices)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if error != nil {
            print("[ERROR] Error discovering services. \(error!.localizedDescription)")
            return
        }
        
        print("[DEBUG] Found services \(peripheral.services!) for peripheral: \(peripheral)")
        
        // Check to see if services are what we want.
        var found_service = false
        let services = peripheral.services
        if services != nil {
            for service in services! {
                print("service:")
                print(service)
                if service.uuid == CBUUID(string: SERVICE_UUID) {
                    found_service = true
                } else {
                    // If the service UUID does not match the desired UUID, then compare what it is to what want.
                    print("compare!")
                    print(service.uuid.uuidString)
                    print(SERVICE_UUID)
                }
            }
        }
        
        if !(found_service) {
        print("peripheral \(peripheral) was discovered but did not have the correct service: services were \(peripheral.services) instead")
        } else {
            // Desired service has been found! Now start discovering characteristics.
            for service in peripheral.services! {
                let theCharacteristics = [CBUUID(string: CHAR_INBOX_UUID), CBUUID(string: CHAR_OUTBOX_UUID), CBUUID(string: CHAR_METADATA_UUID)]
                self.delegate?.didConnectToPeripheral(peripheral: peripheral)
                //            print("current MessengerModel.shared.users: \(MessengerModel.shared.users)")
                peripheral.discoverCharacteristics(theCharacteristics, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if error != nil {
            print("[ERROR] Error discovering characteristics. \(error!.localizedDescription)")
            return
        }

        print("[DEBUG] Found characteristics for peripheral: \(peripheral)")
        
        var peerInbox: CBCharacteristic?
        var peerOutbox: CBCharacteristic?
        var peerMetadataChar: CBCharacteristic?
        
        for characteristic in service.characteristics! {
            let charUUID = characteristic.uuid.uuidString
            if charUUID == CHAR_INBOX_UUID {
                print("discovered inbox characteristic \(characteristic) for peripheral \(peripheral)")
                peerInbox = characteristic
            } else if charUUID == CHAR_OUTBOX_UUID {
                print("discovered outbox characteristic \(characteristic) for peripheral \(peripheral)")
                //peripheral.readValue(for: characteristic) TODO
                peerOutbox = characteristic
            } else if charUUID == CHAR_METADATA_UUID {
                print("discovered metadata characteristic \(characteristic) for peripheral \(peripheral)")
                peripheral.readValue(for: characteristic)
                peerMetadataChar = characteristic
                print("read metadata characteristic \(characteristic) for peripheral \(peripheral)")
            } else {
                print("charUUID \(charUUID) did not match relevant char UUID for peripheral \(peripheral)")
            }
        }
        
        if peerMetadataChar?.value != nil {
            let peerMetadata = self.delegate?.jsonDataToMessage(data: (peerMetadataChar?.value!)!) as! Metadata
            let peerUser = User(uuid: peripheral.identifier, name: peerMetadata.username)
            delegate?.didGetPeripheralUsername(peer: peerUser)
            print("peerMetadata: \(peerMetadata)")
        }
        
        
        if peerInbox != nil {
            peerInboxes[peripheral.identifier] = peerInbox
        }
        if peerOutbox != nil {
            peerOutboxes[peripheral.identifier] = peerOutbox
        }
        peerMetadatas[peripheral.identifier] = peerMetadataChar
        
        enableNotifications(enable: true, uuid: peripheral.identifier)
    }
    
    
    
    /**
     Automatically triggered when a peer connected as a peripheral notifies this node's central
     that their outbox characteristic has changed. 
     Read in the updated outbox characteristic's value (a JSON-formatted Data list of messages)
     and send this data to the BLEDelegate (MessengerModel) to parse.
     The MessengerModel will deliver messages whose recipient is this node 
     and forward the other messages.
    */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("[BLE] peripheral \(peripheral) didUpdateValueFor \(characteristic)")
        if error != nil {
            
            print("[ERROR] Error updating value. \(error!.localizedDescription)")
            return
        }
        
        // if we've just read from the peripheral's outbox, 
        // then let the MessengerModel know
        if characteristic.uuid.uuidString == CHAR_OUTBOX_UUID {
            delegate?.didReadPeerOutbox(peripheral, data: characteristic.value as Data?)
        }
        
        switch (characteristic.uuid.uuidString) {
        case CHAR_OUTBOX_UUID:
            delegate?.didReadPeerOutbox(peripheral, data: characteristic.value as Data?)
            break
        case CHAR_METADATA_UUID:
            // TODO
            print("peer \(peripheral) updated metadata characteristic")
            if characteristic.value != nil {
                let msg = self.delegate?.jsonDataToMessage(data: characteristic.value!)
                print("msg: \(msg)")
                let peerMetadata = msg as! Metadata
                print("peerMetadata: \(peerMetadata)")
                let peerUser = User(uuid: peripheral.identifier, name: peerMetadata.username)
                delegate?.didGetPeripheralUsername(peer: peerUser)
            } else {
                print("metadata characteristic value was nil...")
            }
            break
        default:
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        RSSICompletionHandler?(RSSI, error)
        RSSICompletionHandler = nil
    }
    
    // TODO: required for PeripheralManagerDelegate protocol
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            print("[DEBUG] peripheral is powered on!")
            setupService() // for now, peripheralData is empty (in future, maybe should be a list of reachable peers)
            print("[DEBUG] started advertising")
        } else if peripheral.state == .poweredOff {
            print("[DEBUG] peripheral is powered OFF!")
            blePeripheralManager.stopAdvertising()
            print("[DEBUG] peripheral stopped advertising!")
        }
    }
    
    /**
        based on sample code in http://stackoverflow.com/questions/39679737/cbperipheral-service-seems-to-be-invisible
    */
    func setupService() {
        print("[BLE] setupService()")
        let serviceUUID = CBUUID(string: SERVICE_UUID)
        
        
        self.inbox = CBMutableCharacteristic(type: CBUUID(string: CHAR_INBOX_UUID),
                                             properties: .write, // inbox writable by peers
                                             value: nil,
                                             permissions: .writeable)

        
        self.outbox = CBMutableCharacteristic(type: CBUUID(string: CHAR_OUTBOX_UUID),
                                              properties: .read, // outbox readable by peers
                                              value: nil,
                                              permissions: .readable)
        
        
        let metadataValue = self.delegate?.metadataToJSONData()
        print("self.delegate?.metadataToJSONData() = \(metadataValue)")
        
        self.metadata = CBMutableCharacteristic(type: CBUUID(string: CHAR_METADATA_UUID),
                                                properties: .read, // outbox readable by peers
                                                value: metadataValue,
                                                permissions: .readable)
        
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [self.inbox, self.outbox, self.metadata]
        
        blePeripheralManager.add(service)
        
        let advertisementData = [CBAdvertisementDataLocalNameKey: SettingsModel.username! as Any, CBAdvertisementDataServiceUUIDsKey: [service.uuid]] as [String : Any]
        
        print("about to start advertising with data \(advertisementData), service \(service)")

        blePeripheralManager.startAdvertising(advertisementData)
        
    }
    
    func updateSelfMetadata() {
        let metadata = self.delegate?.metadataToJSONData()
        
        if metadata != nil {
            print("[BLE] updateSelfMetadata() for metadata \(metadata!)")
            blePeripheralManager.updateValue(metadata!, for: self.metadata, onSubscribedCentrals: self.subscribedCentrals.values.toArray())
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("peripheral manager did start advertising")
        print("this device's username: \(SettingsModel.username!)")
        updateSelfMetadata()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        // if characteristic is outbox, add new subscriber to list of central nodes
        // who are reading our outbox, subscribedCentrals
        
        // TODO: check if central UUID matches UUID in connectedPeripherals,
        // since each peer only needs to be subscribed as a central -or- connected as a peripheral
        print("\(central) just subscribed to characteristic \(characteristic)")
        self.delegate?.centralDidSubscribe(central: central)
        subscribedCentrals[central.identifier] = central
        
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        // if characteristic is outbox,
        // remove central from subscribedCentrals
        // (and announce connection lost??)
        print("\(central) just unsubscribed from characteristic \(characteristic)")
        self.delegate?.centralDidUnsubscribe(central: central)
        subscribedCentrals[central.identifier] = nil

    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // if the queue was too full for updateValue previously,
        // we should have saved the message we wanted to add to the queue somewhere.
        // now that the queue has space, we should resend the message
        
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        // CBATTRequest sent by connected central wants to update Inbox characteristic of this peripheral
        // so call peripheralManager.respond(to:withResult:) to respond to the write request
        
        for request in requests {
            if request.characteristic.uuid.uuidString == CHAR_INBOX_UUID {
                // CBATTRequest sent by connected central wants to update Inbox characteristic of this peripheral

                // TODO: add message in request.value to list of received messages for MessengerModel to handle
                //       give delegate (MessengerModel) the data in request.value
                print("about to call didReceiveMessage")
                delegate?.didReceiveMessage(data: request.value, sender: request.central.identifier.uuidString)
                blePeripheralManager.respond(to: request, withResult: CBATTError.Code.success) // respond to the write request positively
            } else {
                blePeripheralManager.respond(to: request, withResult: CBATTError.Code.writeNotPermitted)
            }
        }
        
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid.uuidString == CHAR_OUTBOX_UUID {
            // central wants to read from this peripheral's outbox
            blePeripheralManager.respond(to: request, withResult: CBATTError.Code.success)
            print("central \(request.central.identifier) just read outbox characteristic")
            // TODO: for each message in outbox, add central to list of centrals that have read that message
            delegate?.centralDidReadOutbox(central: request.central.identifier, outboxContents: outbox.value)
        } else if request.characteristic.uuid.uuidString == CHAR_METADATA_UUID {
            blePeripheralManager.respond(to: request, withResult: CBATTError.Code.success)
            print("central \(request.central.identifier) just read metadata characteristic")
        } else {
            blePeripheralManager.respond(to: request, withResult: CBATTError.Code.readNotPermitted)
        }
    }

}
