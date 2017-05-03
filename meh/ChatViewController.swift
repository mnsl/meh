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

    @IBOutlet weak var chatTextField: UITextView!
    @IBOutlet weak var messageInputField: UITextView!
    @IBOutlet weak var sendButton: UIButton!
   
    override func viewDidLoad() {
        super.viewDidLoad()
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
        chatTextField.text = chatTextField.text +
            message + "\n"
    }
    
    func loadMessages(messages: [Message]){
        for message in messages {
            let string_repr = messageToString(message: message)
            addMessageToDisplay(message: string_repr)
        }
        
    }
    func messageToString(message: Message) -> String {
        return message.sender!.name + ": " + message.content! + "\n" as String
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
        MessengerModel.shared.sendMessage(message: messsage)
    }
    
    func messengerModel(_ model: MessengerModel, didSendMessage msg : Message?) {
        print("messenger model did send message")
        return
    }
    func messengerModel(_ model: MessengerModel, didReceiveMessage msg : Message?){
        print("messenger model did recieve message")
        return
    }
    func messengerModel(_ model: MessengerModel, didAddConnectedUser user : User?) {
        print("messenger model did add connected user")
        return
    }
}
