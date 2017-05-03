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
    public static let MessengerModelReceivedMessage = Notification.Name(rawValue: "MessengerModelReceivedNotification")
    public static let MessengerModelSentMessage = Notification.Name(rawValue: "MessengerModelSentNotification")
}

// TODO: is this data structure what we want?
struct Message {
    let content : String?
    let sender : User?
    let date: Date
    let recipient : [String]?
}


struct User : Hashable {
    let uuid : UUID
    let name : String
    
    // conform to Hashable protocol
    var hashValue: Int {
        return uuid.hashValue
    }
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.uuid == rhs.uuid
    }
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
            // Add peripheral to list of connected users.
            MessengerModel.shared.users?[peripheral.identifier] = User(uuid: peripheral.identifier, name: peripheral.name!, peripheral: peripheral, reachableUsers: [])
        }
        
        // TODO: keep scanning??
    }
    
    func ble(didConnectToPeripheral peripheral: CBPeripheral) {
        print("connecting to peripheral \(peripheral)...")
        let user = User(uuid: peripheral.identifier, name: peripheral.name!)
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
    
    func ble(centralDidReadOutbox central: UUID, outboxContents: Data?) {
        // Convert the JSON-formatted outbox data into an array of Messages.
        // For each message that was in the outbox when the central read it,
        // add the central's UUID to the list of centrals that have read the message.
        // Once all the subscribed centrals have read a message, 
        // or if a central that reads the message happens to be the message recipient,
        // we should remove that message from the outbox.
    }
    
    func ble(didReceiveMessage data: Data?, from: UUID) -> Data? {
        // Convert the message JSON-formatted data into a Message.
        // If the recipient UUID matches that of a connected peripheral,
        // update that peripheral's inbox specifically.
        // Otherwise, if we have not already added the message to our peripheral's outbox,
        // add the message to our outbox.
        let currentOutboxContents = ble?.outbox.value
        // unpack outbox data into messages, update outbox contents as necessary
        return nil // if outbox does not need to be updated
    }
    
    func ble(centralDidSubscribe central: UUID) {
        
    }
    
    func ble(centralDidUnsubscribe central: UUID) {
        
    }

    
    
}
