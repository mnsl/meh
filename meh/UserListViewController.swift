//
//  UserListViewController.swift
//  meh
//
//  Created by Tina Quach on 4/30/17.
//  Copyright © 2017 6.S062 Group. All rights reserved.
//

import Foundation
import UIKit

class UserListViewController: UIViewController, UITableViewDataSource, MessengerModelDelegate, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var startchat: UIButton!
    
    var onlineUsers = MessengerModel.shared.users
    public static var onlineUsersArray: Array<User> = []
    public static var selectedUsers: Set = Set<User>()
    
    // MARK: - UITableViewDataSource
    
    // TODO: could add this in order to section off the user list into available now, and known but unavailable.
    
    @IBAction func startChatButtonClick(_ sender: Any) {
        print("starting chat with ")
        print(UserListViewController.selectedUsers)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        tableView.beginUpdates()
        
        // Set this view controller to be the delegate of some model that keeps track of who is on the network, and who you already know.
        MessengerModel.shared.delegates.append(self)

        // NOTE: in the beginning, onlineUsers is nil, because we have not been able to identify any users nearby.
        if UserListViewController.onlineUsersArray.count == 0 {
        print("no online users")
        } else {
        for i in 0...(UserListViewController.onlineUsersArray.count-1) {
            var name = UserListViewController.onlineUsersArray[i].name
            if name == nil {
                name = UserListViewController.onlineUsersArray[i].uuid.uuidString
            }
            //addUsername(username: name!)
        }

        }
        tableView.endUpdates()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UserListViewController.onlineUsersArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)
        
        cell.accessoryType = cell.isSelected ? .checkmark : .none
        //        cell.selectionStyle = .none // to prevent cells from being "highlighted"
        print(UserListViewController.onlineUsersArray[indexPath.row].name)
        cell.textLabel?.text = UserListViewController.onlineUsersArray[indexPath.row].name
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        // let selectedUser = tableView.cellForRow(at: indexPath as IndexPath)?.textLabel?.text;
        let selectedUser = UserListViewController.onlineUsersArray[indexPath.row]
        UserListViewController.selectedUsers.insert(selectedUser);
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.accessoryType = .none
//        let deselectedUser = tableView.cellForRow(at: indexPath as IndexPath)?.textLabel?.text;
        let deselectedUser = UserListViewController.onlineUsersArray[indexPath.row];
        UserListViewController.selectedUsers.remove(deselectedUser);
    }
    
    // TODO(quacht): if didRecieveMessage goes provides visual indication of a message being received, also turn off that
    // indication once a message has been checked.
    
    // MARK: MessengerModelDelegate functions
    func didSendMessage(_ model: MessengerModel, msg: UserMessage?) {
        // Nothing
        return
    }
    
    func didReceiveMessage(_ model: MessengerModel, msg: UserMessage?) {
        // TODO: bold the text of the user in the userlist
        // Maintain state of what messages have been unread?
        return
    }

    func didAddConnectedUser(_ model: MessengerModel, user: String) {
        print("[UserListViewController] added connected user with username \(user)")
        UserListViewController.onlineUsersArray = Array(MessengerModel.shared.users.values)
        tableView.reloadData()
    }
    
    func didDisconnectFromUser(_ model: MessengerModel, user: String) {
        print("[UserListViewController]  disconnected form user with username \(user)")
        // Update onlineUsersArray
        UserListViewController.onlineUsersArray = Array(MessengerModel.shared.users.values)
        tableView.reloadData()

        /*
        for i in 0...(UserListViewController.onlineUsersArray.count) {
            if (UserListViewController.onlineUsersArray[i].uuid == user) {
                print("Found disconnected user to remove from the user list.")
                // Update table view.
                tableView.deleteRows(at: [IndexPath(row: i, section: 0)], with: UITableViewRowAnimation.automatic)

            }
        }
        */
        
    }
    
    
}
