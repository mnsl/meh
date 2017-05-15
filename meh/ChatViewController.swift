//
//  ChatViewController.swift
//  meh
//
//  Created by Tina Quach on 5/3/17.
//  Copyright © 2017 6.S062 Group. All rights reserved.
//

import Foundation
import UIKit

class ChatViewController: UIViewController, MessengerModelDelegate {

    @IBOutlet weak var chatHeader: UINavigationBar!
    @IBOutlet weak var chatTextField: UITextView!
    @IBOutlet weak var messageInputField: UITextView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var chatMembers: UINavigationItem!
    
    var chatMemberList = [String]()
    var selected = Array(UserListViewController.selectedUsers)
    
    // TODO(quacht): Preliminary character limit... will update after testing what is the maximum you can write to a characteristic.
    let message_character_limit = 10000;
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Determine who the user is chatting with.
        if selected.count > 0 {
            for i in 0...(selected.count-1) {
                chatMemberList.append(selected[i].name!)
            }
        //chatMemberList.title =  chatMemberList.joined(separator: ", ")
        chatMembers.title =  "HIEEEEEE"
        }
        print("chat view loaded")
        // Load messages from the messenger model and display them.
        clearChatDisplay()
        
        
        // Load old messages (currently assumes 1:1 messaging) 
        // TODO(quacht): change this when we move towards group messaging.
        if let old_messages = MessengerModel.shared.chats?[selected[0]] {
            loadMessages(messages: old_messages)
        }
        
        
        // Set this view controller to be the delegate of MessengerModel that keeps track of the messages being sent between you and others on the network.
        MessengerModel.shared.delegates.append(self)

    }
    
    func clearChatDisplay() {
        chatTextField.text = "";
    }
    
    func addMessageToDisplay(message: UserMessage) {
        let string_repr = messageToString(message: message)
        chatTextField.text = chatTextField.text + string_repr
    }
    
    func loadMessages(messages: [UserMessage]){
        for message in messages {
            addMessageToDisplay(message: message)
        }
    }
    
    
    func messageToString(message: UserMessage) -> String {
        // Given a message object, return string representation to be printed to the chat.
        let sender = MessengerModel.shared.users[message.sender]
        return (sender?.name)! + ": " + message.content + "\n" as String
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func sendMessage(_ sender: Any) {
        // Get message from the message input field
        let message = messageInputField.text;
        print("sending \"", message as Any, "\"")
        
        MessengerModel.shared.sendMessage(message: message!, recipient: selected[0].name!)
    }
    
    // MARK: MessengerModelDelegate functions
    func didSendMessage(_ model: MessengerModel, msg: UserMessage?) {
        // Once we recieve confirmation from the Messenger model that a message has been sent, we display the message we sent.
        if msg != nil {
        addMessageToDisplay(message: msg!)
        } else {
            print("Sent message is nil! --> not going to display in chat.")
        }
    }
    
    func didReceiveMessage(_ model: MessengerModel, msg: UserMessage?) {
        if msg != nil {
            addMessageToDisplay(message: msg!)
        } else {
            print("Sent message is nil! --> not going to display in chat.")
        }
    }
    
    func didAddConnectedUser(_ model: MessengerModel, user: String) {
        // Do nothing
        return
    }
    
    func didDisconnectFromUser(_ model: MessengerModel, user: String) {
        // Do nothing
        return
    }}
