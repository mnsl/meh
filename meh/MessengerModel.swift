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
    func didSendMessage(msg: UserMessage?)
    func didReceiveMessage(msg: UserMessage?)
    func didUpdateUsers()
    func didReceiveAck(for: UserMessage, latency: TimeInterval)
}

extension Notification.Name {
    public static let MessengerModelReceivedMessage = Notification.Name(rawValue: "MessengerModelReceivedNotification")
    public static let MessengerModelSentMessage = Notification.Name(rawValue: "MessengerModelSentNotification")
}

// TODO: is this data structure what we want?

protocol Message : JSONSerializable {
    var type: String { get }
}

struct Outbox : JSONSerializable {
    var messages = [Message]()
}

struct ACK : Message, Hashable {
    let type = "ACK"
    let originalMessageOrigin : String
    let originalMessageRecipient : String
    let originalMessageHash : Int
    
    // conform to Hashable protocol
    var hashValue: Int {
        return "\(type),\(originalMessageOrigin),\(originalMessageRecipient),\(originalMessageHash)".hashValue
    }
    
    static func == (lhs: ACK, rhs: ACK) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}


struct UserMessage : Message, Hashable {
    let type = "UserMessage"
    let content : String
    let origin : String
    let date: Date
    let recipient : String
    
    // conform to Hashable protocol
    var hashValue: Int {
        return "\(type),\(content),\(origin),\(date),\(recipient)".hashValue
    }
    
    static func == (lhs: UserMessage, rhs: UserMessage) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

struct Metadata : Message {
    let type = "Metadata"
    
    let username : String
    var peerMap : [String: [String]]
}

struct User : Hashable {
    let uuid : UUID?
    let name : String
    
    // conform to Hashable protocol
    var hashValue: Int {
        return name.hashValue
    }
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}


class MessengerModel : BLEDelegate {
    
    static let kBLE_SCAN_TIMEOUT = 10000.0
    
    static let shared = MessengerModel()
    
    var delegates = [MessengerModelDelegate]()
    
    var chats = [User: [UserMessage]]()
    var users = [String: User]() // uuid -> username map for all known users
    var ble: BLE?
    var metadata = Metadata(username: SettingsModel.username!, peerMap: [String : [String]]())
    
    var messagesAwaitingACK = Set<UserMessage>()
    var doNotForward = Set<UserMessage>()
    var doNotForwardACK = Set<ACK>()
    
    init() {
        ble = BLE()
        ble?.delegate = self
    }
    
    /*!
     * @method getHopCounts:
     *
     * @return  dictionary mapping each of the other users in the network to the hopCount
     *
     */
    public static func getHopCounts(metadata : Metadata) -> Dictionary<String, Int> {
        let peerMap = metadata.peerMap
        var queue = [[metadata.username]]
        var visited = Set<String>()
        var hopCounts = Dictionary<String, Int>()
        hopCounts[metadata.username] = 0
        visited.insert(metadata.username)
        while queue.count != 0 {
            let currentPath = queue.first
            if currentPath == nil || currentPath!.count == 0 { continue }
            queue.remove(at: 0)
            let currentNode = currentPath?.last
            if currentNode == nil { continue }
            let neighbors = peerMap[currentNode!]
            if neighbors == nil { continue }
            
            for neighbor in neighbors! {
                if !visited.contains(neighbor) {
                    var newPath = Array(currentPath!)
                    newPath.append(neighbor)
                    visited.insert(currentNode!)
                    queue.append(newPath)
                    let pathLength = newPath.count
                    hopCounts[neighbor] = pathLength - 1
                }
            }
        
        }
    return hopCounts
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
        print("[MessengerModel] introduceSelf to \(recipient)")
        //print("metadata username is \(String(describing: self.metadata.username))")
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
    func writeToAllInboxes(data: Data, exclude: String?) {
        print("[MessengerModel] writeToAllInboxes(data: \(data), exclude: \(exclude)")
        // for every peripheral this node's central is subscribed to,
        // write the message data to their inbox.
        for (username, _) in self.users {
            if username == exclude {
                continue
            }
            writeToInbox(data: data, username: username)
        }
    }
    
    func updateSelfMetadata() {
        self.ble?.updateSelfMetadata()
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
        updateSelfMetadata()
        
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
        if recipient == SettingsModel.username! {
            return // don't need to send messages to ourselves
        }
        
        let message = UserMessage(content: message, origin: SettingsModel.username!, date: Date(), recipient: recipient)
        messagesAwaitingACK.update(with: message)
    
        sendMessage(message: message, exclude: SettingsModel.username!)
    }
    
    func sendMessage(message: UserMessage, exclude: String?) {
        let messageData = messageToJSONData(message: message)
        
        // do not reforward this message
        self.doNotForward.update(with: message)
        
        // add this message to the chat history
        let recipientUser = self.users[message.recipient]
        if recipientUser == nil {
            print("tried to send a message to an unknown user :(")
            return
        }
        if self.chats[recipientUser!] != nil {
            self.chats[recipientUser!]!.append(message)
        } else {
            self.chats[recipientUser!] = [message]
        }
        
        // tell ChatViewController to update view of messages.
        for delegate in self.delegates {
            delegate.didSendMessage(msg: message)
        }

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
    
    func sendACK(ack: ACK, exclude: String?) {
        let ackData = messageToJSONData(message: ack)
        
        let recipientUUID = self.users[ack.originalMessageOrigin]?.uuid
        
        // Check to see if the recipient is connected a central or peripheral node
        if (recipientUUID != nil && ble?.connectedPeripherals[recipientUUID!] != nil) {
            // Write to the peripheral's inbox characteristic
            let success = writeToInbox(data: ackData!, username: ack.originalMessageOrigin)
            if success {
                print("successfully wrote ACK to inbox of message recipient \(ack.originalMessageOrigin), who happened to be directly connected as a peripheral")
                
                // do not reforward this ack
                self.doNotForwardACK.update(with: ack)
                
            } else {
                print("failed to write to inbox of message recipient, even though they were directly connected as a peripheral")
            }
        } else {
            if (recipientUUID != nil && ble?.subscribedCentrals[recipientUUID!] != nil) {
                // Update this node's outbox so that the connected central can read.
                print("message recipient is a subscribed central and should read message from this node's outbox")
            } else {
                // The UUID is of a recipient that is not currently connected.
                print("ack recipient is not a direct peer, so writing to all connected peripherals' inboxes")
                writeToAllInboxes(data: ackData!, exclude: exclude)
            }

        }

    }
    
    func didUpdateState(state: BLEState) {
        // Start scanning for devices
        if state == BLEState.poweredOn {
            if !(ble?.startScanning(timeout: MessengerModel.kBLE_SCAN_TIMEOUT))! {
                print("error scanning; central manager not powered on?")
            } else {
                print("this central started scanning")
            }
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
    }
    
    func didGetPeripheralMetadata(peripheral: CBPeripheral, metadata: Metadata) {
        print("[MessengerModel] didGetPeripheralMetadata(metadata: \(metadata)")
        
        // update
        let peer = User(uuid: peripheral.identifier, name: metadata.username)
        self.users[peer.name] = peer
        if self.metadata.peerMap[SettingsModel.username!] == nil {
           self.metadata.peerMap[SettingsModel.username!] = [metadata.username]
        } else {
            // Add peer to this node's peermap if it's not in there already
            if !self.metadata.peerMap[SettingsModel.username!]!.contains(metadata.username) {
                self.metadata.peerMap[SettingsModel.username!]!.append(metadata.username)
            }
        }
        
        // If this is the first peer we're connecting to, 
        // use their metadata to fill in our peerMap
        if ble?.connectedPeripherals.count == 1 {
            for (username, peers) in metadata.peerMap {
                if username == self.metadata.username { continue }
                self.metadata.peerMap[username] = peers
            }
        }

        for delegate in delegates {
            delegate.didUpdateUsers()
        }
        // Introduce self to the peripheral.
        introduceSelf(recipient: peer.name)
        
        // Write our updated metadata to our metadata characteristic
        // for connected centrals to read
        updateSelfMetadata()
    }
    
    func didConnectToPeripheral(peripheral: CBPeripheral) {
        print("[MessengerModel] didConnectToPeripheral(peripheral \(peripheral))")
        updateSelfMetadata() // update metadata so peripheral can read from it
    }
    
    
    func didDisconnectFromPeripheral(peripheral: CBPeripheral) {
        print("[MessengerModel] didDisconnectFromPeripheral(peripheral: \(peripheral))")
        
        for (_, peer) in MessengerModel.shared.users {
            if (peer.uuid == peripheral.identifier) {
                // Remove self from list of peripheral's direct peers
                var selfIndex : Int? = nil
                if let peers = self.metadata.peerMap[peer.name] {
                    for i in 0 ..< peers.count {
                        if peers[i] == self.metadata.username {
                            selfIndex = i
                            break
                        }
                    }
                    if selfIndex != nil {
                        self.metadata.peerMap[peer.name]!.remove(at: selfIndex!)
                        print("removed self from the list of the disconnected peripheral's direct peers in this node's peerMap")
                        print("disconnected peripheral's direct peers are now \(self.metadata.peerMap[peer.name]!)")
                        print("disconnected peripheral's direct peers were \(peers)")

                    } else {
                        print("peer \(peer.name) just disconnected but this node was not listed as its direct peer in this node's peerMap??")
                    }
                }
                
                // Remove peripheral from list of direct peers in this node's peerMap
                var peerIndex : Int? = nil
                if let peers = self.metadata.peerMap[self.metadata.username] {
                    for i in 0 ..< peers.count {
                        if peers[i] == peer.name {
                            peerIndex = i
                            break
                        }
                    }
                    if peerIndex != nil {
                        self.metadata.peerMap[self.metadata.username]!.remove(at: peerIndex!)
                        print("removed \(peer.name) from the list of direct peers in this node's peerMap")
                        print("this node's direct peers are now \(self.metadata.peerMap[self.metadata.username]!)")
                    } else {
                        print("peer \(peer.name) just disconnected but was not listed as a direct peer in this node's peerMap??")
                    }
                }
                
                // view controller delegate should update list of connected users
                for delegate in delegates {
                    delegate.didUpdateUsers()
                }
                // hopefully only one user associated with this identifier??
                break
            }
        }
        
        // Write our updated metadata to our metadata characteristic
        // for connected centrals to read
        updateSelfMetadata()
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
    
    // sender arg = direct peer who either generated or forwarded this message
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
            
            if self.users[userMessage.origin] == nil {
                self.users[userMessage.origin] = User(uuid: nil, name: userMessage.origin)
            }
            
            if self.users[userMessage.recipient] == nil {
                self.users[userMessage.recipient] = User(uuid: nil, name: userMessage.recipient)
            }
            
            
            if userMessage.recipient == self.metadata.username {
                print("message received was intended for this user")

                // Send an ACK back to the origin node
                let ack = ACK(originalMessageOrigin: userMessage.origin, originalMessageRecipient: userMessage.recipient, originalMessageHash: userMessage.hashValue)
                sendACK(ack: ack, exclude: nil)
                
                // Add the message to the chat history for the user who sent it to us
                var originUser : User? = self.users[userMessage.origin]
                if originUser == nil {
                    print("received message from unknown user; adding them to users list")
                    originUser = User(uuid: nil, name: userMessage.origin)
                    self.users[userMessage.origin] = originUser
                }
                if self.chats[originUser!] != nil {
                    self.chats[originUser!]!.append(userMessage)
                } else {
                    self.chats[originUser!] = [userMessage]
                }
                
                // Tell the delegates the chat history for this user has been updated
                for delegate in delegates {
                    delegate.didReceiveMessage(msg: userMessage)
                }
                
            } else {
                if self.doNotForward.contains(userMessage) {
                    print("message \(userMessage) has already been forwarded / sent from this node")
                } else {
                    print("forwarding message \(userMessage)")
                    self.doNotForward.update(with: userMessage)
                    sendMessage(message: userMessage, exclude: sender)
                }
            }
        } else if message?.type == "ACK" {
            
            let ack = message as! ACK
            
            
            if self.users[ack.originalMessageOrigin] == nil {
                self.users[ack.originalMessageOrigin] = User(uuid: nil, name: ack.originalMessageOrigin)
            }
            
            if self.users[ack.originalMessageRecipient] == nil {
                self.users[ack.originalMessageRecipient] = User(uuid: nil, name: ack.originalMessageRecipient )
            }
            
            if ack.originalMessageOrigin == self.metadata.username {
                var acknowledgedMessage : UserMessage? = nil
                for msg in self.messagesAwaitingACK {
                    if msg.hashValue == ack.originalMessageHash {
                        acknowledgedMessage = msg
                        break
                    }
                }
                
                if let msg : UserMessage = acknowledgedMessage {
                    let latency = Date().timeIntervalSince(msg.date)
                    print("received ACK for message \(msg) with latency \(latency)")
                    self.messagesAwaitingACK.remove(msg)
                    
                    let user = self.users[msg.recipient]
                    if user == nil {
                        print("received ACK for message from unknown user...")
                        return
                    }
                    if self.chats[user!] == nil {
                        print("received ACK for an empty chat history...")
                        return
                    }
                    
                    if let index = MessengerModel.shared.chats[user!]!.index(of: msg) {
                        print("chats[UserListViewController.selectedUser!]! was:\n\t \(self.chats[user!]!)")

                        self.chats[user!]![index] = UserMessage(content: msg.content + " ☑︎", origin: msg.origin, date: msg.date, recipient: msg.recipient)
                        
                        print("chats[UserListViewController.selectedUser!]! is now:\n\t \(self.chats[user!]!)")
                        
                        for delegate in self.delegates {
                            delegate.didReceiveAck(for: msg, latency: latency)
                        }
                        
                    } else {
                        print("received ACK for a message not in the chat history...")
                    }
                } else {
                    print("received ACK for a message this node sent, but ACK hash didn't match any message awaiting ACK")
                    return
                }
                
            } else {
                if self.doNotForwardACK.contains(ack) {
                    print("ACK \(ack) has already been forwarded / sent from this node")
                } else {
                    print("forwarding message \(ack)")
                    self.doNotForwardACK.update(with: ack)
                    sendACK(ack: ack, exclude: sender)
                }
            }
        } else {
            let metadata = message as! Metadata
            print("didReceiveMessage() received metadata from \(sender): \(metadata)")
    
            // If it's metadata, 'sender' is a UUID string corresponding to the central who sent it
            let newUser = User(uuid: UUID(uuidString: sender), name: metadata.username)
            self.users[metadata.username] = newUser
            
            // update the peripheral's list of neighbors in our peerMap
            // this works for two hops.
            // TODO: in general, if we are N degrees separated from a user
            // and the peripheral is less than N degrees away, 
            // update our peerMap entry for that user with the corresponding
            // entry in this peer's metadata
            
            let selfHopCounts = MessengerModel.getHopCounts(metadata: self.metadata)
            let peerHopCounts = MessengerModel.getHopCounts(metadata: metadata)
            
            print("selfHopCounts: \(selfHopCounts)")
            print("peerHopCounts: \(peerHopCounts)")
            
            for (username, hopCount) in peerHopCounts {
                if self.users[username] == nil {
                    let newUser = User(uuid: nil, name: username)
                    self.users[username] = newUser
                }
                if selfHopCounts[username] == nil || selfHopCounts[username]! > hopCount {
                    print("updating peerMap entry for \(username) from \(self.metadata.peerMap[username]) to \(metadata.peerMap[username]), the value in the peerMap for user \(metadata.username)")
                    self.metadata.peerMap[username] = metadata.peerMap[username]
                }
            }
            
            for (username, peers) in metadata.peerMap {
                if peers.count == 0 {
                    self.metadata.peerMap[username] = [String]()
                }
            }
            
            // Let the delegates know the list of users has probably been updated
            for delegate in delegates {
                delegate.didUpdateUsers()
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
                delegate.didReceiveMessage(msg: message)
            }
        }
    }
    
    func centralDidSubscribe(central: CBCentral) {
        print("central \(central) just subscribed")
        // TODO: update UUID -> username map when central introduces itself (not in this method)
        updateSelfMetadata()
    }
    
    func centralDidUnsubscribe(central: CBCentral) {
        print("central \(central) just unsubscribed")
        // TODO: remove central from direct peers in peerMap?
        // still not sure if central -> peripheral messaging even works :(
    }
    
    /**
     Converts a Message to JSON-formatted Data to be loaded into a CBCharacteristic's "value" attribute.
     If the Message can't be converted, returns nil.
    */
    func messageToJSONData(message: Message) -> Data? {
        if let json = message.toJSON() {
            print("message \(message) -> JSON \(json)")
            return json.data(using: .utf8)
        }
        print("could not convert '\(message)' to JSON")
        return nil
    }
    
    func outboxToJSONData(outbox: [UserMessage]) -> Data? {
        if let json = Outbox(messages: outbox).toJSON() {
            return json.data(using: .utf8)
        } else {
            print("could not convert '\(outbox)' to JSON")
            return nil
        }
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
        print("[MessengerModel] jsonDataToMessage(data: \( String(data: data, encoding: .utf8) ?? "[couldn't convert to string]"))")

        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        
        if let dict = json as? [String: Any] {
            print("dict: \(dict)")
            
            let type = dict["type"] as! String
            if type == "UserMessage" {
                print("jsonDataToMessage called for message: ")
                let content = dict["content"] as! String
                let sender = dict["origin"] as! String
                let recipient = dict["recipient"] as! String
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                let date = dateFormatter.date(from: dict["date"] as! String)
                
                let msg = UserMessage(content: content, origin: sender, date: date!, recipient: recipient)
                print("UserMessage: \(msg)")
                return msg
            } else if type == "ACK" {
                print("jsonDataToMessage called for ACK...")
                let origin = dict["originalMessageOrigin"] as! String
                let recipient = dict["originalMessageRecipient"] as! String
                let hash = dict["originalMessageHash"] as! Int
                
                let ack = ACK(originalMessageOrigin: origin, originalMessageRecipient: recipient, originalMessageHash: hash)
                return ack
            } else {
                print("jsonDataToMessage called for metadata... ")
                let username = dict["username"] as! String
                let peerMap =  dict["peerMap"] as! [String: [String]]
                
                let metadata = Metadata(username: username, peerMap: peerMap)
                return metadata
            }
        }
        return nil
    }

    func jsonDataToOutbox(data: Data?) -> [UserMessage]? {
        //print("data: \( String(data: data!, encoding: .utf8) ?? "[couldn't convert to string]") ")
        
        if let outboxData = data {
            var messages = [UserMessage]()
            let json = try? JSONSerialization.jsonObject(with: outboxData, options: [])
            if let outboxJSON = json as? [ [String: String] ] {
                for messageDict in outboxJSON {
                    let content = messageDict["content"]
                    let sender = messageDict["origin"]
                    let recipient = messageDict["recipient"]
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                    let date = dateFormatter.date(from: messageDict["date"]!)
                    
                    let message = UserMessage(content: content!, origin: sender!, date: date!, recipient: recipient!)
                    messages.append(message)
                }
                return messages
            }
        }
        return nil
    }
    
    func metadataToJSONData() -> Data? {
        print("[MessengerModel] metadataToJSONData()")
        if let json = self.metadata.toJSON() {
            //print("metadata \(self.metadata) -> JSON \(json)")
            return json.data(using: .utf8)
        }
        print("could not convert metadata '\(self.metadata)' to JSON")
        return nil
    }

}
