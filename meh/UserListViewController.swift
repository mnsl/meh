//
//  UserListViewController.swift
//  meh
//
//  Created by Tina Quach on 4/30/17.
//  Copyright © 2017 6.S062 Group. All rights reserved.
//

import Foundation
import UIKit

// TODO: Set this view controller to be the delegate of some model that keeps track of who is on the network, and who you already know.
class UserListViewController: UIViewController, UITableViewDataSource, MessengerModelDelegate, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var startchat: UIButton!
    
    // var onlineUsers = MessengerModel.shared.users
    // TODO(quacht): pull onlineUsers from the messenger model
    var onlineUsers = ["keam", "mnsl", "quacht"];
    var selectedUsers: Set = Set<String>()
    
    // MARK: - UITableViewDataSource
    
    // TODO: could add this in order to section off the user list into available now, and known but unavailable.
    
    @IBAction func startChatButtonClick(_ sender: Any) {
        print("starting chat with ")
        print(selectedUsers)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        
        tableView.beginUpdates()
        
        if onlineUsers.count == 0 {
            print("no online users")
        } else {
            for i in 0...onlineUsers.count {
                addUsername(username: onlineUsers[i])
            }
        }
        
        tableView.endUpdates()
    }
    
    func addUsername(username:String) {
        let cell_to_fill = tableView.dequeueReusableCell(withIdentifier: "Username")
        cell_to_fill?.textLabel?.text = username
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return onlineUsers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        
        cell.accessoryType = cell.isSelected ? .checkmark : .none
        //        cell.selectionStyle = .none // to prevent cells from being "highlighted"
        print(onlineUsers[indexPath.row])
        cell.textLabel?.text = onlineUsers[indexPath.row]
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        let selectedUser = tableView.cellForRow(at: indexPath as IndexPath)?.textLabel?.text;
        selectedUsers.insert(selectedUser!);
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
        let deselectedUser = tableView.cellForRow(at: indexPath as IndexPath)?.textLabel?.text;
        selectedUsers.remove(deselectedUser!);
    }
    
    // MARK: MessengerModelDelegate functions
    func didSendMessage(_ model: MessengerModel, msg: Message?) {
        // TODO
    }
    
    func didReceiveMessage(_ model: MessengerModel, msg: Message?) {
        // TODO
    }
    
    func didAddConnectedUser(_ model: MessengerModel, user: UUID) {
        // TODO
    }
    
    func didDisconnectFromUser(_ model: MessengerModel, user: UUID) {
        // TODO
    }
    
}
