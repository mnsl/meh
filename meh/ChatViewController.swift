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
    @IBOutlet weak var messageInputField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var chatMembers: UINavigationItem!
    
    // This constraint ties an element at zero points from the bottom layout guide
    @IBOutlet var keyboardHeightLayoutConstraint: NSLayoutConstraint?
    
    var chatMemberList = [String]()
    
    var displayMessages = [UserMessage]()
    
    // TODO(quacht): Preliminary character limit... will update after testing what is the maximum you can write to a characteristic.
    let message_character_limit = 10000;
   
    override func viewDidLoad() {
        super.viewDidLoad()
        clearChatDisplay()
        if (UserListViewController.selectedUser != nil) {
            chatMembers.title =  UserListViewController.selectedUser?.name
        }
        
        print("chat view loaded")
        
        // Load old messages (currently assumes 1:1 messaging)
        if UserListViewController.selectedUser != nil {
            if let old_messages = MessengerModel.shared.chats[UserListViewController.selectedUser!] {
                loadMessages(messages: old_messages)
            }
        }
        
        
        // Set this view controller to be the delegate of MessengerModel that keeps track of the messages being sent between you and others on the network.
        MessengerModel.shared.delegates.append(self)

        
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardNotification(notification:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    
    func clearChatDisplay() {
        chatTextField.text = "";
    }
    
    func addMessageToDisplay(message: UserMessage) {
        let string_repr = messageToString(message: message)
        chatTextField.text = chatTextField.text + string_repr
    }
    
    func loadMessages(messages: [UserMessage]){
        chatTextField.text = ""
        for message in messages {
            addMessageToDisplay(message: message)
        }
    }
    
    func messageToString(message: UserMessage) -> String {
        // Given a message object, return string representation to be printed to the chat.
        
        return message.origin + ": " + message.content + "\n"
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func sendMessage(_ sender: Any) {
        // Get message from the message input field
        let message = messageInputField.text;
        print("sending \"", message as Any, "\"")
        
        MessengerModel.shared.sendMessage(message: message!, recipient: (UserListViewController.selectedUser?.name)!)
        // clear message input field
        messageInputField.text = ""
    }
    
    // MARK: MessengerModelDelegate functions
    func didSendMessage(msg: UserMessage?) {
        print("[ChatViewController] didSendMessage(msg: \(msg)")
        // Once we receive confirmation from the Messenger model that a message has been sent, we display the message we sent.
        
        let user = MessengerModel.shared.users[msg!.recipient]
        if user == nil { return }
        if MessengerModel.shared.chats[user!] == nil { return }
        loadMessages(messages: MessengerModel.shared.chats[user!]!)

        
        /*
        if MessengerModel.shared.chats[user!] != nil {
            if MessengerModel.shared.chats[user!]?.last == msg {
                // already loaded message
                return
            }
            MessengerModel.shared.chats[user!]!.append(msg!)
        } else {
            MessengerModel.shared.chats[user!] = [msg!]
        }
         */
        loadMessages(messages: MessengerModel.shared.chats[user!]!)
    }
    
    func didReceiveMessage(msg: UserMessage?) {
        print("[ChatViewController] didReceiveMessage(msg: \(msg)")
        if msg == nil {
            print("Received message is nil! --> not going to display in chat.")
            return
        }
        
        let user = MessengerModel.shared.users[msg!.origin]
        if user == nil { return }
        if MessengerModel.shared.chats[user!] == nil { return }
        loadMessages(messages: MessengerModel.shared.chats[user!]!)
        
        /*
        let user = MessengerModel.shared.users[msg!.origin]
        if user == nil { return }
        
        if MessengerModel.shared.chats[user!] != nil {
            if MessengerModel.shared.chats[user!]?.last == msg {
                // already loaded message
                return
            }
            MessengerModel.shared.chats[user!]!.append(msg!)
        } else {
            MessengerModel.shared.chats[user!] = [msg!]
        }
        loadMessages(messages: MessengerModel.shared.chats[user!]!)
        */
    }
    
    func didUpdateUsers() {
        // Do nothing
        return
    }
    
    func keyboardNotification(notification: NSNotification) {
        if let userInfo = notification.userInfo {
            let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
            let duration:TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            let animationCurveRawNSN = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber
            let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIViewAnimationOptions.curveEaseInOut.rawValue
            let animationCurve:UIViewAnimationOptions = UIViewAnimationOptions(rawValue: animationCurveRaw)
            if (endFrame?.origin.y)! >= UIScreen.main.bounds.size.height {
                self.keyboardHeightLayoutConstraint?.constant = 35.0
            } else {
                if endFrame?.size.height != nil {
                    self.keyboardHeightLayoutConstraint?.constant = (endFrame?.size.height)! + 10.0
                } else {
                    self.keyboardHeightLayoutConstraint?.constant = 35.0
                }
            }
            UIView.animate(withDuration: duration,
                           delay: TimeInterval(0),
                           options: animationCurve,
                           animations: { self.view.layoutIfNeeded() },
                           completion: nil)
            
        }
    }

    func didReceiveAck(for msg: UserMessage, latency: TimeInterval) {
        print("[ChatViewController] didReceiveAck(for: \(msg)")
            let acknowledgedMessage = UserMessage(content: msg.content + " [received ACK \(latency) sec later]", origin: msg.origin, date: msg.date, recipient: msg.recipient)
            //self.displayMessages[index] = acknowledgedMessage
            //print("self.displayMessages = \(self.displayMessages)")
            
            let user = MessengerModel.shared.users[msg.recipient]
            if user == nil {
                print("received ACK for unknown user...")
                return
            }
            if MessengerModel.shared.chats[user!] == nil {
                print("received ACK for a message not in the chat field...")
                return
            }
        
            if let index = MessengerModel.shared.chats[user!]!.index(of: msg) {
                let acknowledgedMessage = UserMessage(content: msg.content + " [received ACK \(latency) sec later]", origin: msg.origin, date: msg.date, recipient: msg.recipient)
                //self.displayMessages[index] = acknowledgedMessage
                //print("self.displayMessages = \(self.displayMessages)")
                
                print("MessengerModel.shared.chats[UserListViewController.selectedUser!]! was:\n\t \(MessengerModel.shared.chats[user!]!)")
                
                MessengerModel.shared.chats[user!]![index] = acknowledgedMessage
                    
                print("MessengerModel.shared.chats[UserListViewController.selectedUser!]! is now:\n\t \(MessengerModel.shared.chats[user!]!)")
                
                loadMessages(messages: MessengerModel.shared.chats[user!]!)
            } else {
                print("received ACK for a message not in the chat field...")
            }
        
    }
}
