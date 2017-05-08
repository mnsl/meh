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
    
    // TODO(quacht): Preliminary character limit... will update after testing what is the maximum you can write to a characteristic.
    let message_character_limit = 10000;
   
    override func viewDidLoad() {
        super.viewDidLoad()
        var chatMembers = [String]()
        var selected = Array(UserListViewController.selectedUsers)
        if selected.count > 0 {
        for i in 0...(selected.count-1) {
            chatMembers.append(selected[i].name)
        }
        self.title =  chatMembers.joined(separator: ", ")
        }
        print("chat view loaded")
        // Load messages from the messenger model and display them.
        clearChatDisplay()
        
        // Determine who the user is chatting with.
        
//        let messagesToLoad = MessengerModel.shared.chats[currentMessager]
//        loadMessages(messages: messagesToLoad)
    }
    
    func clearChatDisplay() {
        chatTextField.text = "";
    }
    
    func addMessageToDisplay(message: String) {
        chatTextField.text = chatTextField.text + SettingsModel.username! + ": "
            message + "\n"
    }
    
    func loadMessages(messages: [Message]){
        for message in messages {
            let string_repr = messageToString(message: message)
            addMessageToDisplay(message: string_repr)
        }
        
    }
    func messageToString(message: Message) -> String {
        let sender = MessengerModel.shared.users?[message.sender]
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
        chatTextField.text = chatTextField.text +
            message!
        // Send message
        // TODO: figure out how to get the recipient UUID
        // MessengerModel.shared.sendMessage(message: message, uuid: recipientUUID)
    }
    
    func messengerModel(_ model: MessengerModel, didSendMessage msg : Message?) {
        print("messenger model did send message")
        // TODO
        return
    }
    func messengerModel(_ model: MessengerModel, didReceiveMessage msg : Message?){
        print("messenger model did recieve message")
        // TODO
        return
    }
    func messengerModel(_ model: MessengerModel, didAddConnectedUser user : UUID) {
        print("messenger model did add connected user")
        // TODO
        return
    }
    
    func messengerModel(_ model: MessengerModel, didDisconnectFromUser user : UUID) {
        // TODO
    }
}
