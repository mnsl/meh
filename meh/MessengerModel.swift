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

struct User : Hashable {
    let name : String
    let peripheral : CBPeripheral?
    
    // conform to Hashable protocol
    var hashValue: Int {
        return name.hashValue ^ peripheral!.hashValue
    }
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.name == rhs.name
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
    var messages : [User: [Message]]?
    
    var chats : [Chat]?
    var activeUsers : [User]?
    var allUsers : [User]?
    var ble: BLE?
    
    init() {
        ble = BLE()
        ble?.delegate = self
    }
    
    
    func ble(didUpdateState state: BLEState) {
        if state == BLEState.poweredOn {
            if !(ble?.startScanning(timeout: MessengerModel.kBLE_SCAN_TIMEOUT))! {
                print("error scanning; central manager not powered on?")
            } else {
                print("started scanning")
            }
        }
    }
    
    func ble(didDiscoverPeripheral peripheral: CBPeripheral) {
    }
    
    func ble(didConnectToPeripheral peripheral: CBPeripheral) {
    }
    
    func ble(didDisconnectFromPeripheral peripheral: CBPeripheral) {
    }
    
    func ble(_ peripheral: CBPeripheral, didReceiveData data: Data?) {
    }
    
}
