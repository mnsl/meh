//
//  MessengerModel.swift
//  meh
//
//  Created by Jane Maunsell on 4/28/17.
//  Copyright © 2017 6.S062 Group. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

protocol MessengerModelDelegate {
    func messengerModel(_ model: MessengerModel, didSendMessage msg : Message?)
    func messengerModel(_ model: MessengerModel, didReceiveMessage msg : Message?)
    func messengerModel(_ model: MessengerModel, didAddConnectedUser user : User?)
}

extension Notification.Name {
    public static let MessengerModelReceivedMessage = Notification.Name(rawValue: "SensorModelActiveHillChangedNotification")
    public static let MessengerModelSentMessage = Notification.Name(rawValue: "SensorModelHillReadingsChangedNotification")
}


struct Message {
    let content : String?
    let sender : User?
    let date: Date = Date()
    let recipient : [String]?
}

enum Status : Int {
    case Unknown = -1
    case Offline = 0
    case IndirectlyConnected = 1
    case DirectlyConnected = 2
    
}


struct User : Hashable {
    let uuid : UUID
    let name : String
    let peripheral : CBPeripheral?
    let status : Status
    let reachableUsers : [UUID]?
    
    // conform to Hashable protocol
    var hashValue: Int {
        return uuid.hashValue
    }
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
}

struct Chat {
    var messageHistory : [String]?
    var users : [User]?
}


class MessengerModel : BLEDelegate {
    
    static let kBLE_SCAN_TIMEOUT = 10000.0
    
    static let shared = MessengerModel()
    
    var delegate : MessengerModelDelegate?
    
    var chats : [User: [Message]]?
    var users : [UUID: User]?
    var ble: BLE?
    
    init() {
        ble = BLE()
        ble?.delegate = self
    }
    
    
    func ble(didUpdateState state: BLEState) {
        // Start scanning for devices
        if state == BLEState.poweredOn {
            if !(ble?.startScanning(timeout: MessengerModel.kBLE_SCAN_TIMEOUT))! {
                print("error scanning; central manager not powered on?")
            } else {
                print("started scanning")
            }
        }
    }
    
    func ble(didDiscoverPeripheral peripheral: CBPeripheral) {
        print("discovered peripheral: \(peripheral)")
        // Connect to first peripheral discovered
        if !(ble?.connectToPeripheral(peripheral))! {
            print("error connecting to peripheral")
        } else {
            print("connected to peripheral: \(peripheral)")
        }
        
        // TODO: keep scanning??
    }
    
    func ble(didConnectToPeripheral peripheral: CBPeripheral) {
        print("connecting to peripheral \(peripheral)...")
        let user = User(uuid: peripheral.identifier, name: peripheral.name!, peripheral: peripheral, status: .DirectlyConnected, reachableUsers: [])
        MessengerModel.shared.users?[peripheral.identifier] = user
        delegate?.messengerModel(.shared, didAddConnectedUser: user)
        // TODO: send usermap over to new 
    }
    
    func ble(didDisconnectFromPeripheral peripheral: CBPeripheral) {
        // broadcast "lostPeer" message
    }

    func ble(_ peripheral: CBPeripheral, didReceiveData data: Data?) {
        print("receiving data...")
        if data == nil {
            print("nil data received")
            return
        }
        
        // update map of incomplete messages: something like...
        // updateMessageData(uuid: peripheral.identifier, data: data)

    }    
}
