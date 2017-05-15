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
    func didSendMessage(_ model: MessengerModel, msg: UserMessage?)
    func didReceiveMessage(_ model: MessengerModel, msg: UserMessage?)
    func didAddConnectedUser(_ model: MessengerModel, user: String)
    func didDisconnectFromUser(_ model: MessengerModel, user: String)
}

extension Notification.Name {
    public static let MessengerModelReceivedMessage = Notification.Name(rawValue: "MessengerModelReceivedNotification")
    public static let MessengerModelSentMessage = Notification.Name(rawValue: "MessengerModelSentNotification")
}

// TODO: is this data structure what we want?

protocol Message : JSONSerializable {
    var type: String { get }
}


struct UserMessage : Message, Hashable {
    let type = "UserMessage"
    let content : String
    let sender : String
    let date: Date
    let recipient : String
    
    // conform to Hashable protocol
    var hashValue: Int {
        return content.hashValue*2 + sender.hashValue*3 + date.hashValue*5 + recipient.hashValue*7
    }
    
    static func == (lhs: UserMessage, rhs: UserMessage) -> Bool {
        return lhs.content == rhs.content && lhs.sender == rhs.sender && lhs.recipient == rhs.recipient && lhs.date == rhs.date
    }
}

struct Metadata : Message {
    
    let type = "Metadata"
    
    let username : String?
    let peerMap : [String: [String]]
}

struct User : Hashable {
    let uuid : UUID
    let name : String?
    
    
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
    
    var delegates = [MessengerModelDelegate]()
    
    var chats : [User: [UserMessage]]?
    var users = [String: User]() // uuid -> username map for all known users
    var ble: BLE?
    var metadata = Metadata(username: SettingsModel.username, peerMap: [String : [String]]())
    
    init() {
        ble = BLE()
        ble?.delegate = self
    }
    
 
    // introduce self as a central node that can be identified by the username provided at the login screen. To be called upon each connect to a peripheral.
    /*!
     * @method introduceSelf:
     *
     * @param recipient  username of peripheral to receive introduction
     *
     * @discussion  Write own metadata to inbox of a specific peripheral
     *
     */
    func introduceSelf(recipient: String) {
        print("[MessengerModel] introduceSelf")
        print("metadata username is \(String(describing: self.metadata.username))")
        let metadata = metadataToJSONData()
        if metadata == nil {
            print("METADATA IS NIL-- could not introduce self with nil metadata")
        }
        let success = writeToInbox(data: metadata!, username: recipient)
        if !(success) {
            print("tried to write metadata to peripheral \(recipient), but failed. Perhaps given username doesn't correspond to any of our connected peripherals.")
        }
        
    }
    
    // write data to inbox of a specific peripheral,
    // probably because they're the recipient of this UserMessage
    // (later, we will also use this to do smarter routing --
    // only write to inboxes of peripherals who can reach
    // the recipient
    /*!
     * @method writeToInbox:
     *
     * @param data  JSON-formatted data to be written
     * @param username  username of peripheral whose inbox the data will be written to
     *
     * @return true iff given username corresponds to a connected peripheral
     *
     * @discussion  Write data to inbox of a specific peripheral
     *
     */
    func writeToInbox(data: Data, username: String) -> Bool {
        
        guard let uuid = self.users[username]?.uuid else {
            print("peer \(username) is not a known user; can't write to their inbox")
            return false
        }
        
        guard let inboxCharacteristic = ble?.peerInboxes[uuid] else {
            print("could not find inbox of user \(username); are they connected as a peripheral?")
            return false
        }
        guard let peer = ble?.connectedPeripherals[uuid] else {
            print("peer \(username) is not connected as a peripheral; can't write to their inbox")
            return false
        }
        peer.writeValue(data, for: inboxCharacteristic, type: .withResponse)
        return true
    }
    
    // write message to the inboxes of all peripherals this
    // node's central is subscribed to, except "exclude" 
    // (the peer who sent you the message)
    func writeToAllInboxes(data: Data, exclude: String) {
        print("[MessengerModel] writeToAllInboxes(data: \(data), exclude: \(exclude)")
        // for every peripheral this node's central is subscribed to,
        // write the message data to their inbox.
        for (username, user) in self.users {
            if username == exclude {
                continue
            }
            writeToInbox(data: data, username: username)
        }
    }
    
    /**
     Add message to outbox if the message has not been added before.
     * @param data  JSON-formatted message data
     * @return true iff message was successfully added (TODO)
     */
    func addMessageToOutbox(message: UserMessage) -> Bool {

        var outbox = [UserMessage]()

        print("self.ble?.outbox: \(self.ble?.outbox)")
        
        var outboxEmpty = false
        if self.ble?.outbox.value == nil {
            print("outbox empty")
            outboxEmpty = true
        }
        if !outboxEmpty {
            let oldOutboxData = self.ble?.outbox.value
            if let oldMessages = jsonDataToOutbox(data: oldOutboxData) {
                outbox += oldMessages
            }
        }
        outbox.append(message)
        let newOutboxData = outboxToJSONData(outbox: outbox)
        
        overwriteOutbox(data: newOutboxData)

        return true
    }
    
    // overwrite outbox contents
    func overwriteOutbox(data: Data?) {
        print("[MessengerModel] overwriteOutbox(data: \(data)")
        if data == nil {
            return
        }
        
        if (self.ble?.blePeripheralManager.updateValue(data!, for: (self.ble?.outbox)!, onSubscribedCentrals: self.ble?.subscribedCentrals.values.toArray()))! {
            print("successfully updated outbox characteristic")
        } else {
            print("[ERROR] could not update outbox characteristic")
        }
    }
    
    /**
     * @method sendMessage:
     *
     * @param message         The user input text to be sent as a message.
     * @param recipientUUID   The UUID of the message's intended recipient.
     *
     * @discussion    The message is not guaranteed to reach the recipient.
     *                We don't currently have a way of notifying the sender
     *                if the message has gone through or failed.
     *
     */
    func sendMessage(message: String, recipient: String){
        // TODO: only count the message as sent if we receive an ACK
        // Convert the string to a Message struct
        
        
        // if recipientUUID in connectedPeripherals, send directly to that peripheral's inbox.
        
        // else stick the message in this node's peripheral's outbox.
        
        let message = UserMessage(content: message, sender: SettingsModel.username!, date: Date(), recipient: recipient)
        // TODO(quacht): update the chat dictionary (so that chat history can show up accordingly on chat view controller)
        sendMessage(message: message, exclude: SettingsModel.username!)
    }
    
    func sendMessage(message: UserMessage, exclude: String) {
        let messageData = messageToJSONData(message: message)
        
        let recipientUUID = self.users[message.recipient]?.uuid

        // Check to see if the recipient is connected a central or peripheral node
        if (recipientUUID != nil && ble?.connectedPeripherals[recipientUUID!] != nil) {
            // Write to the peripheral's inbox characteristic
            let success = writeToInbox(data: messageData!, username: message.recipient)
            if success {
                print("successfully wrote to inbox of message recipient \(message.recipient), who happened to be directly connected as a peripheral")
            } else {
                print("failed to write to inbox of message recipient, even though they were directly connected as a peripheral")
            }
        } else {
            if (recipientUUID != nil && ble?.subscribedCentrals[recipientUUID!] != nil) {
                // Update this node's outbox so that the connected central can read.
                print("message recipient is a subscribed central and should read message from this node's outbox")
            } else {
                // The UUID is of a recipient that is not currently connected.
                print("message recipient is not a direct peer, so writing to all connected peripherals' inboxes and to this node's outbox for subscribed centrals to read")
                writeToAllInboxes(data: messageData!, exclude: exclude)
            }
            
            let success = addMessageToOutbox(message: message)
            if success {
                print("successfully added message to outbox")
            } else {
                print("failed to add message to outbox :(")
            }
            
        }
    }
    
    func didUpdateState(state: BLEState) {
        // Start scanning for devices
        if state == BLEState.poweredOn {
            if !(ble?.startScanning(timeout: MessengerModel.kBLE_SCAN_TIMEOUT))! {
                print("error scanning; central manager not powered on?")
            } else {
                print("started scanning")
            }
            
            // TODO: start advertising node's peripheral
        }
    }
    
    func didDiscoverPeripheral(peripheral: CBPeripheral) {
        print("discovered peripheral: \(peripheral)")
        // Connect to first peripheral discovered
        if !(ble?.connectToPeripheral(peripheral))! {
            print("error connecting to peripheral")
        } else {
            print("connected to peripheral: \(peripheral)")
        }
        
        // TODO: keep scanning??
    }
    
    func didGetPeripheralUsername(peer: User) {
        print("[MessengerModel] didGetPeripheralUsername(peer: \(peer)")
        
        MessengerModel.shared.users[peer.name!] = peer
        for delegate in delegates {
            delegate.didAddConnectedUser(.shared, user: peer.name!)
        }
    }
    
    func didConnectToPeripheral(peripheral: CBPeripheral) {
        print("connecting to peripheral \(peripheral)...")
        
        // Create a user object from peripheral.
        let newUser = User(uuid: peripheral.identifier, name: peripheral.name)
        
        // Add peripheral to list of connected users.
        MessengerModel.shared.users[peripheral.name!] = newUser
        for delegate in delegates {
            delegate.didAddConnectedUser(.shared, user: peripheral.name!)
        }
        
        // Introduce self to the peripheral.
        introduceSelf(recipient: peripheral.name!)
        
    }
    
    func didDisconnectFromPeripheral(peripheral: CBPeripheral) {
        // TODO: broadcast "lostPeer" message
        // Remove peripheral for Messenger Model's user list.
        print("disconnected from peripheral \(peripheral)...")
        MessengerModel.shared.users.removeValue(forKey: peripheral.name!)
        // Tell view controller delegate to update list of connected users
        
        // view controller delegate should update list of connected users
        for delegate in delegates {
            delegate.didDisconnectFromUser(.shared, user: peripheral.name!)
        }
    }
    
    func centralDidReadOutbox(central: UUID, outboxContents: Data?) {
        // Convert the JSON-formatted outbox data into an array of Messages.
        // For each message that was in the outbox when the central read it,
        // add the central's UUID to the list of centrals that have read the message.
        // Once all the subscribed centrals have read a message, 
        // or if a central that reads the message happens to be the message recipient,
        // we should remove that message from the outbox.
        print("[MessengerModel] centralDidReadOutbox(central: \(central), outboxContents: \(outboxContents))")
        print("^not yet implemented")
    }
    
    func didReceiveMessage(data: Data?, sender: String) {
        // Convert the message JSON-formatted data into a Message.
        // If the recipient UUID matches that of a connected peripheral,
        // update that peripheral's inbox specifically.
        // Otherwise, if we have not already added the message to our peripheral's outbox,
        // add the message to our outbox.
        // unpack outbox data into messages, update outbox contents as necessary
        print("[MessengerModel] didReceiveMessage(data: \(String(data: data!, encoding: .utf8) ?? "[could not convert to string]"), sender: \(sender))")
        let message = jsonDataToMessage(data: data!)

        if message?.type == "UserMessage" {
            let userMessage = message as! UserMessage
            if userMessage.recipient == SettingsModel.username {
                print("message received was intended for this user")
                for delegate in delegates {
                    delegate.didReceiveMessage(.shared, msg: userMessage)
                }
            } else {
                if userMessage != nil {
                    sendMessage(message: userMessage, exclude: sender)
                } else {
                    print("userMessage was nil...")
                }
                
            }
        } else {
            let metadata = message as! Metadata
            print("didReceiveMessage() received metadata from \(sender): \(metadata)")
    
            if metadata.username != sender {
                print("sender \(sender) did not match metadata name \(metadata.username)")
            }
            
        }
        
    }
    
    func didReadPeerOutbox(_ peripheral: CBPeripheral, data: Data?) {
        // parse data as list of messages.. if a message is new, update the delegate
        print("[MessengerModel] didReadPeerOutbox(peripheral: \(peripheral), data: \(data))")
        let messages = jsonDataToOutbox(data: data!)
        
        // for msg in messages parsed from data: call messengerModel(_ model: shared, didReceiveMessage: msg)

        for message in messages! {
            for delegate in delegates {
                delegate.didReceiveMessage(.shared, msg: message)
            }
        }
    }
    
    func centralDidSubscribe(central: CBCentral) {
        print("central \(central) just subscribed")
        // TODO: update UUID -> username map somehow... central doesn't have a "name"
        // TODO: implement this stuff
        /*
        let newUser = User(uuid: central.identifier, name: )
        MessengerModel.shared.users[central] = newUser
        for delegate in delegates {
            delegate.didAddConnectedUser(.shared, user: central)
        }
         */
    }
    
    func centralDidUnsubscribe(central: CBCentral) {
        print("central \(central) just unsubscribed")
        //TODO: implement this stuff
        /**
        MessengerModel.shared.users.removeValue(forKey: central.name!)
        for delegate in delegates {
            delegate.didDisconnectFromUser(.shared, user: central)
        }
        */
    }
    
    /**
     Converts a Message to JSON-formatted Data to be loaded into a CBCharacteristic's "value" attribute.
     If the Message can't be converted, returns nil.
    */
    func messageToJSONData(message: UserMessage) -> Data? {
        if let json = message.toJSON() {
            print("message \(message) -> JSON \(json)")
            return json.data(using: .utf8)
        }
        print("could not convert '\(message)' to JSON")
        return nil
    }
    
    func outboxToJSONData(outbox: [UserMessage]) -> Data? {
        print("outboxToJSONData not implemented")
        return nil // TODO
    }
    
    
    /**
     Remove message from outbox if it was in the outbox.
     Returns true if the message was in the outbox, else false.
    */
    func removeMessageFromOutbox(message: UserMessage) -> Bool {
        return true // TODO
    }
    
    
    /**
     Converts JSON-formatted Data into the corresponding Message.
    */
    func jsonDataToMessage(data: Data) -> Message? {
        print("data: \( String(data: data, encoding: .utf8) ?? "[couldn't convert to string]") ")

        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        print("json: \(json)")

        if let dict = json as? [String: String] {
            print("dict: \(dict)")
            
            let type = dict["type"]
            if type == "UserMessage" {
                print("jsonDataToMessage called for message: ")
                let content = dict["content"]
                let sender = dict["sender"]
                let recipient = dict["recipient"]
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                let date = dateFormatter.date(from: dict["date"]!)
                
                let msg = UserMessage(content: content!, sender: sender!, date: date!, recipient: recipient!)
                print("UserMessage: \(msg)")
                return msg
            } else {
                print("jsonDataToMessage called for metadata... ")
                let username = dict["username"]
                
                print("peerMap: \(dict["peerMap"])") // TODO
                let metadata = Metadata(username: username, peerMap: [String : [String]]())
                return metadata
            }
            
            
        }
   
        return nil
    }

    func jsonDataToOutbox(data: Data?) -> [UserMessage]? {
        //let json = try? JSONSerialization.jsonObject(with: data, options: [])
        print("data: \( String(data: data!, encoding: .utf8) ?? "[couldn't convert to string]") ")
        
        if let outboxData = data {
            var messages = [UserMessage]()
            let json = try? JSONSerialization.jsonObject(with: outboxData, options: [])
            print("json: \(json)")
            if let outboxJSON = json as? [ [String: String] ] {
                for messageDict in outboxJSON {
                    let content = messageDict["content"]
                    let sender = messageDict["sender"]
                    let recipient = messageDict["recipient"]
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                    let date = dateFormatter.date(from: messageDict["date"]!)
                    
                    let message = UserMessage(content: content!, sender: sender!, date: date!, recipient: recipient!)
                    messages.append(message)
                }
                return messages
            }
        }
        return nil
    }
    
    func metadataToJSONData() -> Data? {
        print("[MessengerModel] metadataToJSONData()")
        print("metadata: \(self.metadata)")
        if let json = self.metadata.toJSON() {
            print("metadata \(self.metadata) -> JSON \(json)")
            return json.data(using: .utf8)
        }
        print("could not convert metadata '\(self.metadata)' to JSON")
        return nil
    }

}
